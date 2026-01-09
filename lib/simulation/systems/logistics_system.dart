import '../engine.dart';
import '../models/truck.dart';
import '../models/machine.dart';
import '../models/product.dart';
import '../models/research.dart';
import '../models/zone.dart';
import '../../config.dart';
import '../../state/game_log_entry.dart';
import 'simulation_system.dart';
import 'dart:math' as math;

class LogisticsSystem implements SimulationSystem {
  // Cache for road graph
  Set<({double x, double y})> _roadTiles = {};
  Map<({double x, double y}), List<({double x, double y})>>? _cachedBaseGraph;

  void setMapLayout(List<({double x, double y})> roadTiles) {
    _roadTiles = roadTiles.toSet();
    _cachedBaseGraph = null;
  }

  @override
  SimulationState update(SimulationState state, GameTime time) {
    var updatedTrucks = _processTruckMovement(state.trucks, state.machines, state.unlockedResearch, state.warehouseRoadX, state.warehouseRoadY);

    final restockResult = _processTruckRestocking(updatedTrucks, state.machines, state.warehouseRoadX, state.warehouseRoadY, time);
    updatedTrucks = restockResult.trucks;
    var updatedMachines = restockResult.machines;

    var updatedCash = state.cash;
    updatedCash = _processFuelCosts(updatedTrucks, state.trucks, updatedCash);

    final currentMessages = List<GameLogEntry>.from(state.pendingMessages);
    currentMessages.addAll(restockResult.messages);

    return state.copyWith(
      trucks: updatedTrucks,
      machines: updatedMachines,
      cash: updatedCash,
      pendingMessages: currentMessages,
    );
  }

  /// Process truck movement
  List<Truck> _processTruckMovement(
    List<Truck> trucks,
    List<Machine> machines,
    Set<ResearchType> unlockedResearch,
    double? warehouseRoadX,
    double? warehouseRoadY,
  ) {
    double movementSpeed = AppConfig.movementSpeed;

    if (unlockedResearch.contains(ResearchType.turboTrucks)) {
      movementSpeed *= 1.25;
    }

    return trucks.map((truck) {
      if (truck.status == TruckStatus.idle) return truck;

      double targetX, targetY;
      TruckStatus nextStatus = truck.status;
      bool isRoutingToMachine = false;

      if (truck.isRouteComplete) {
        targetX = warehouseRoadX ?? 4.0;
        targetY = warehouseRoadY ?? 4.0;
        if (truck.status == TruckStatus.restocking) nextStatus = TruckStatus.traveling;
      } else {
        final destId = truck.currentDestination!;
        final machine = machines.firstWhere((m) => m.id == destId, orElse: () => machines.first);
        final roadPt = _getNearestRoadPoint(machine.zone.x, machine.zone.y);
        targetX = roadPt.x;
        targetY = roadPt.y;
        isRoutingToMachine = true;
      }

      final distToDest = (targetX - truck.currentX).abs() + (targetY - truck.currentY).abs();
      if (distToDest < SimulationConstants.roadSnapThreshold) {
         final shouldApplyPendingRoute = !isRoutingToMachine && truck.pendingRoute.isNotEmpty;
         final routeToUse = shouldApplyPendingRoute ? truck.pendingRoute : truck.route;
         final routeIndexToUse = isRoutingToMachine ? truck.currentRouteIndex : routeToUse.length;

         return truck.copyWith(
           status: isRoutingToMachine ? TruckStatus.restocking : TruckStatus.idle,
           currentX: targetX,
           currentY: targetY,
           targetX: targetX,
           targetY: targetY,
           path: [],
           pathIndex: 0,
           route: shouldApplyPendingRoute ? routeToUse : truck.route,
           pendingRoute: shouldApplyPendingRoute ? [] : truck.pendingRoute,
           currentRouteIndex: routeIndexToUse,
         );
      }

      List<({double x, double y})> path = truck.path;
      int pathIndex = truck.pathIndex;

      if (path.isEmpty ||
          (path.isNotEmpty && (path.last.x != targetX || path.last.y != targetY)) ||
          pathIndex >= path.length) {
        path = findPath(truck.currentX, truck.currentY, targetX, targetY);
        pathIndex = 0;
      }

      while (pathIndex < path.length) {
        final currentTarget = path[pathIndex];

        final distToNode = (currentTarget.x - truck.currentX).abs() + (currentTarget.y - truck.currentY).abs();
        if (distToNode < 0.15) {
          pathIndex++;
          continue;
        }

        if (path.length > pathIndex + 1) {
          final nextTarget = path[pathIndex + 1];
          final dx1 = currentTarget.x - truck.currentX;
          final dy1 = currentTarget.y - truck.currentY;
          final dx2 = nextTarget.x - currentTarget.x;
          final dy2 = nextTarget.y - currentTarget.y;

          final distToNext = (nextTarget.x - truck.currentX).abs() + (nextTarget.y - truck.currentY).abs();
          if ((dx1 * dx2 + dy1 * dy2) < -0.01 || distToNext < distToNode) {
            pathIndex++;
            continue;
          }
        }
        break;
      }

      var simX = truck.currentX;
      var simY = truck.currentY;
      var currentPathIndex = pathIndex;
      double remainingDist = movementSpeed;

      while (currentPathIndex < path.length && remainingDist > 0.001) {
        final wp = path[currentPathIndex];
        final dx = wp.x - simX;
        final dy = wp.y - simY;
        final dist = math.sqrt(dx * dx + dy * dy);

        if (dist < SimulationConstants.roadSnapThreshold) {
          simX = wp.x;
          simY = wp.y;
          currentPathIndex++;
        } else {
          final move = remainingDist.clamp(0.0, dist);
          simX += (dx / dist) * move;
          simY += (dy / dist) * move;
          remainingDist -= move;
        }
      }

      if (currentPathIndex >= path.length) {
         if (isRoutingToMachine) {
             nextStatus = TruckStatus.restocking;
         } else {
             nextStatus = TruckStatus.idle;
         }
         simX = targetX;
         simY = targetY;
      } else if (nextStatus == TruckStatus.idle) {
         nextStatus = TruckStatus.traveling;
      }

      return truck.copyWith(
        status: nextStatus,
        currentX: simX,
        currentY: simY,
        targetX: targetX,
        targetY: targetY,
        path: path,
        pathIndex: currentPathIndex,
      );
    }).toList();
  }

  /// Process truck restocking
  ({List<Machine> machines, List<Truck> trucks, List<GameLogEntry> messages}) _processTruckRestocking(
    List<Truck> trucks,
    List<Machine> machines,
    double? warehouseRoadX,
    double? warehouseRoadY,
    GameTime time,
  ) {
    var updatedMachines = List<Machine>.from(machines);
    var updatedTrucks = List<Truck>.from(trucks);
    var messages = <GameLogEntry>[];
    final currentDay = time.day;

    for (int i = 0; i < updatedTrucks.length; i++) {
      final truck = updatedTrucks[i];

      if (truck.status != TruckStatus.restocking) continue;

      final destinationId = truck.currentDestination;
      if (destinationId == null) continue;

      final machineIndex = updatedMachines.indexWhere((m) => m.id == destinationId);
      if (machineIndex == -1) continue;

      final machine = updatedMachines[machineIndex];
      final machineX = machine.zone.x;
      final machineY = machine.zone.y;
      final targetRoadPoint = _getNearestRoadPoint(machineX, machineY);
      final targetRoadX = targetRoadPoint.x;
      final targetRoadY = targetRoadPoint.y;

      final dxToTarget = (truck.currentX - targetRoadX).abs();
      final dyToTarget = (truck.currentY - targetRoadY).abs();
      final isCloseEnough = dxToTarget < SimulationConstants.roadSnapThreshold &&
                             dyToTarget < SimulationConstants.roadSnapThreshold;

      final roadX = isCloseEnough ? targetRoadX : truck.currentX;
      final roadY = isCloseEnough ? targetRoadY : truck.currentY;
      var machineInventory = Map<Product, InventoryItem>.from(machine.inventory);
      var truckInventory = Map<Product, int>.from(truck.inventory);
      var itemsToTransfer = <Product, int>{};

      if (truckInventory.isNotEmpty) {
        for (final entry in truckInventory.entries) {
          final product = entry.key;
          final truckQuantity = entry.value;
          if (truckQuantity <= 0) continue;

          final allowedProducts = Zone.getAllowedProducts(machine.zone.type);
          if (!allowedProducts.contains(product)) {
            itemsToTransfer[product] = truckQuantity;
            continue;
          }

          final existingItem = machineInventory[product];
          final currentProductStock = existingItem?.quantity ?? 0;
          final allocationTarget = existingItem?.allocation ?? 20;

          final neededToReachAllocation = allocationTarget - currentProductStock;

          if (neededToReachAllocation <= 0) {
            itemsToTransfer[product] = truckQuantity;
            continue;
          }

          final transferAmount = ((truckQuantity < neededToReachAllocation)
              ? truckQuantity
              : neededToReachAllocation).toInt();

          if (existingItem != null) {
            machineInventory[product] = existingItem.copyWith(
              quantity: existingItem.quantity + transferAmount,
              dayAdded: currentDay,
            );
          } else {
             machineInventory[product] = InventoryItem(
              product: product,
              quantity: transferAmount,
              dayAdded: currentDay,
              allocation: 20,
            );
          }

          final remainingTruckQuantity = truckQuantity - transferAmount;
          if (remainingTruckQuantity > 0) {
            itemsToTransfer[product] = remainingTruckQuantity;
          }
        }
      }

      final updatedTruckInventory = itemsToTransfer;
      final isTruckEmpty = updatedTruckInventory.isEmpty;
      final hasMoreDestinations = truck.currentRouteIndex + 1 < truck.route.length;

      bool remainingDestinationsNeedItems = false;
      if (!isTruckEmpty && hasMoreDestinations) {
        for (int routeIdx = truck.currentRouteIndex + 1; routeIdx < truck.route.length; routeIdx++) {
          final remainingMachineId = truck.route[routeIdx];
          final remainingMachine = updatedMachines.firstWhere(
            (m) => m.id == remainingMachineId,
            orElse: () => updatedMachines.first,
          );

          for (final entry in updatedTruckInventory.entries) {
            final product = entry.key;
            final truckQuantity = entry.value;
            if (truckQuantity <= 0) continue;

            final existingItem = remainingMachine.inventory[product];
            final currentProductStock = existingItem?.quantity ?? 0;
            final allocationTarget = existingItem?.allocation ?? 20;
            if (currentProductStock < allocationTarget) {
              remainingDestinationsNeedItems = true;
              break;
            }
          }
          if (remainingDestinationsNeedItems) break;
        }
      }

      final whRoadX = warehouseRoadX ?? 4.0;
      final whRoadY = warehouseRoadY ?? 4.0;

      if (isTruckEmpty || !hasMoreDestinations || !remainingDestinationsNeedItems) {
        updatedTrucks[i] = truck.copyWith(
          inventory: updatedTruckInventory,
          status: TruckStatus.traveling,
          currentRouteIndex: truck.route.length,
          targetX: whRoadX,
          targetY: whRoadY,
          path: [],
          pathIndex: 0,
          currentX: roadX,
          currentY: roadY,
        );
      } else {
        updatedTrucks[i] = truck.copyWith(
          inventory: updatedTruckInventory,
          status: TruckStatus.traveling,
          currentRouteIndex: truck.currentRouteIndex + 1,
          currentX: roadX,
          currentY: roadY,
        );
      }

      final updatedMachineInventory = Map<Product, InventoryItem>.from(machineInventory);
      final updatedMachine = machine.copyWith(
        inventory: updatedMachineInventory,
        hoursSinceRestock: 0.0,
      );

      updatedMachines[machineIndex] = updatedMachine;

      // Log transfer
      if (truckInventory.isNotEmpty) {
        final itemsTransferred = <String>[];
        for (final entry in truckInventory.entries) {
          final originalQty = entry.value;
          final remainingQty = itemsToTransfer[entry.key] ?? 0;
          final transferredQty = originalQty - remainingQty;
          if (transferredQty > 0) {
            itemsTransferred.add('${entry.key.name}: $transferredQty');
          }
        }
        if (itemsTransferred.isNotEmpty) {
          messages.add(GameLogEntry(
            type: LogType.truckRestock,
            timestamp: time,
            data: {
              'details': itemsTransferred.join(", "),
              'machineName': machine.name,
              'truckName': truck.name,
            }
          ));
        }
      }
    }

    return (machines: updatedMachines, trucks: updatedTrucks, messages: messages);
  }

  /// Process fuel costs
  double _processFuelCosts(List<Truck> updatedTrucks, List<Truck> oldTrucks, double currentCash) {
    double totalFuelCost = 0.0;
    const double movementSpeed = AppConfig.movementSpeed;

    for (final truck in updatedTrucks) {
      final oldTruck = oldTrucks.firstWhere(
        (t) => t.id == truck.id,
        orElse: () => truck,
      );

      final hasMoved = (truck.currentX - oldTruck.currentX).abs() > 0.001 ||
                       (truck.currentY - oldTruck.currentY).abs() > 0.001;

      if (hasMoved) {
        final fuelCost = movementSpeed * SimulationConstants.gasPrice;
        totalFuelCost += fuelCost;
      }
    }

    return currentCash - totalFuelCost;
  }

  // --- Pathfinding & Graph Logic ---

  Map<({double x, double y}), List<({double x, double y})>> _getBaseGraph() {
    if (_cachedBaseGraph != null) return _cachedBaseGraph!;

    final graph = <({double x, double y}), List<({double x, double y})>>{};

    for (final tile in _roadTiles) {
      graph[tile] = [];
    }

    for (final tile in _roadTiles) {
      final neighbors = [
        (x: tile.x + 1.0, y: tile.y),
        (x: tile.x - 1.0, y: tile.y),
        (x: tile.x, y: tile.y + 1.0),
        (x: tile.x, y: tile.y - 1.0),
      ];

      for (final neighbor in neighbors) {
        if (_roadTiles.contains(neighbor)) {
          graph[tile]!.add(neighbor);
        }
      }
    }

    _cachedBaseGraph = graph;
    return graph;
  }

  ({double x, double y}) _getNearestRoadPoint(double x, double y) {
    if (_roadTiles.isEmpty) return (x: x, y: y);

    double minDistance = double.infinity;
    var nearest = _roadTiles.first;

    for (final tile in _roadTiles) {
      final dx = tile.x - x;
      final dy = tile.y - y;
      final dist = dx * dx + dy * dy;
      if (dist < minDistance) {
        minDistance = dist;
        nearest = tile;
      }
    }
    return nearest;
  }

  List<({double x, double y})> findPath(
    double startX, double startY,
    double endX, double endY,
  ) {
      final start = (x: startX, y: startY);
      final end = (x: endX, y: endY);

      if ((start.x - end.x).abs() < SimulationConstants.roadSnapThreshold &&
          (start.y - end.y).abs() < SimulationConstants.roadSnapThreshold) {
        return [end];
      }

      final baseGraph = _getBaseGraph();
      final startEntry = _getNearestRoadPoint(startX, startY);
      final endExit = _getNearestRoadPoint(endX, endY);

      final openSet = <({double x, double y})>{start};
      final cameFrom = <({double x, double y}), ({double x, double y})>{};
      final gScore = <({double x, double y}), double>{start: 0.0};
      final fScore = <({double x, double y}), double>{start: (end.x - start.x).abs() + (end.y - start.y).abs()};

      Iterable<({double x, double y})> getNeighbors(({double x, double y}) node) {
        final neighbors = <({double x, double y})>[];

        if (baseGraph.containsKey(node)) {
          neighbors.addAll(baseGraph[node]!);
        }

        if (node == start) {
           if (startEntry != start) neighbors.add(startEntry);
        }
        if (node == startEntry) {
           if (startEntry != start) neighbors.add(start);
        }

        if (node == endExit) {
           if (endExit != end) neighbors.add(end);
        }

        return neighbors;
      }

      while (openSet.isNotEmpty) {
        ({double x, double y})? current;
        double lowestF = double.infinity;
        for (final node in openSet) {
          final f = fScore[node] ?? double.infinity;
          if (f < lowestF) {
            lowestF = f;
            current = node;
          }
        }

        if (current == null) break;

        if ((current.x - end.x).abs() < SimulationConstants.roadSnapThreshold &&
            (current.y - end.y).abs() < SimulationConstants.roadSnapThreshold) {
          final path = <({double x, double y})>[end];
          var node = current;
          while (cameFrom.containsKey(node)) {
            node = cameFrom[node]!;
            if (node == start) break;
            path.insert(0, node);
          }
          if (path.isEmpty || path.last != end) path.add(end);
          return path;
        }

        openSet.remove(current);

        for (final neighbor in getNeighbors(current)) {
          double edgeCost = (neighbor.x - current.x).abs() + (neighbor.y - current.y).abs();
          final tentativeG = (gScore[current] ?? double.infinity) + edgeCost;
          if (tentativeG < (gScore[neighbor] ?? double.infinity)) {
            cameFrom[neighbor] = current;
            gScore[neighbor] = tentativeG;
            fScore[neighbor] = tentativeG + ((end.x - neighbor.x).abs() + (end.y - neighbor.y).abs());
            if (!openSet.contains(neighbor)) openSet.add(neighbor);
          }
        }
      }
      return [end];
  }
}
