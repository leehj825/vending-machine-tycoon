import 'dart:async';
import 'dart:math' as math;
import 'package:state_notifier/state_notifier.dart';
import 'models/product.dart';
import 'models/machine.dart';
import 'models/truck.dart';

/// Simulation constants
class SimulationConstants {
  static const double gasPrice = 0.05; // Cost per unit distance
  static const int hoursPerDay = 24;
  static const int ticksPerHour = 6; // 1 tick = 10 minutes, so 6 ticks per hour
  static const int ticksPerDay = hoursPerDay * ticksPerHour; // 144 ticks per day
  static const int emptyMachinePenaltyHours = 4; // Hours before reputation penalty
  static const int reputationPenaltyPerEmptyHour = 5;
  static const double disposalCostPerExpiredItem = 0.50;
}

/// Game time state
class GameTime {
  final int day; // Current game day (starts at 1)
  final int hour; // Current hour (0-23)
  final int minute; // Current minute (0-59, in 10-minute increments)
  final int tick; // Current tick within the day (0-143)

  const GameTime({
    required this.day,
    required this.hour,
    required this.minute,
    required this.tick,
  });

  /// Create from tick count (absolute ticks since game start)
  factory GameTime.fromTicks(int totalTicks) {
    final day = (totalTicks ~/ SimulationConstants.ticksPerDay) + 1;
    final tickInDay = totalTicks % SimulationConstants.ticksPerDay;
    final hour = tickInDay ~/ SimulationConstants.ticksPerHour;
    final minute = (tickInDay % SimulationConstants.ticksPerHour) * 10;
    
    return GameTime(
      day: day,
      hour: hour,
      minute: minute,
      tick: tickInDay,
    );
  }

  /// Get next time after one tick
  GameTime nextTick() {
    return GameTime.fromTicks(
      (day - 1) * SimulationConstants.ticksPerDay + tick + 1,
    );
  }

  /// Format time as string
  String get timeString {
    final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final amPm = hour < 12 ? 'AM' : 'PM';
    return 'Day $day, $hour12:${minute.toString().padLeft(2, '0')} $amPm';
  }
}

/// Simulation engine state
class SimulationState {
  final GameTime time;
  final List<Machine> machines;
  final List<Truck> trucks;
  final double cash;
  final int reputation;
  final math.Random random;
  final double? warehouseRoadX; // Road tile X coordinate next to warehouse
  final double? warehouseRoadY; // Road tile Y coordinate next to warehouse

  const SimulationState({
    required this.time,
    required this.machines,
    required this.trucks,
    required this.cash,
    required this.reputation,
    required this.random,
    this.warehouseRoadX,
    this.warehouseRoadY,
  });

  SimulationState copyWith({
    GameTime? time,
    List<Machine>? machines,
    List<Truck>? trucks,
    double? cash,
    int? reputation,
    math.Random? random,
    double? warehouseRoadX,
    double? warehouseRoadY,
  }) {
    return SimulationState(
      time: time ?? this.time,
      machines: machines ?? this.machines,
      trucks: trucks ?? this.trucks,
      cash: cash ?? this.cash,
      reputation: reputation ?? this.reputation,
      random: random ?? this.random,
      warehouseRoadX: warehouseRoadX ?? this.warehouseRoadX,
      warehouseRoadY: warehouseRoadY ?? this.warehouseRoadY,
    );
  }
}

/// The Simulation Engine - The Heartbeat of the Game
class SimulationEngine extends StateNotifier<SimulationState> {
  Timer? _tickTimer;
  final math.Random _random = math.Random();
  final StreamController<SimulationState> _streamController = StreamController<SimulationState>.broadcast();

  SimulationEngine({
    required List<Machine> initialMachines,
    required List<Truck> initialTrucks,
    double initialCash = 2000.0,
    int initialReputation = 100,
  }) : super(
          SimulationState(
            time: const GameTime(day: 1, hour: 8, minute: 0, tick: 48), // 8:00 AM = 8 hours * 6 ticks/hour = 48 ticks
            machines: initialMachines,
            trucks: initialTrucks,
            cash: initialCash,
            reputation: initialReputation,
            random: math.Random(),
          ),
        );

  /// Stream of simulation state changes
  Stream<SimulationState> get stream => _streamController.stream;

  /// Add a machine to the simulation
  void addMachine(Machine machine) {
    print('🔴 ENGINE: Adding machine ${machine.name}');
    state = state.copyWith(machines: [...state.machines, machine]);
    _streamController.add(state);
  }

  /// Update cash in the simulation
  void updateCash(double amount) {
    print('🔴 ENGINE: Updating cash to \$${amount.toStringAsFixed(2)}');
    state = state.copyWith(cash: amount);
    _streamController.add(state);
  }

  /// Update trucks in the simulation
  void updateTrucks(List<Truck> trucks) {
    print('🔴 ENGINE: Updating trucks list');
    state = state.copyWith(trucks: trucks);
    _streamController.add(state);
  }

  /// Update machines in the simulation
  ///
  /// This is used by the UI/controller to sync changes (e.g. buying a machine)
  /// so that the next engine tick doesn't overwrite local state.
  void updateMachines(List<Machine> machines) {
    print('🔴 ENGINE: Updating machines list');
    state = state.copyWith(machines: machines);
    _streamController.add(state);
  }

  /// Update warehouse road position in the simulation
  void updateWarehouseRoadPosition(double roadX, double roadY) {
    print('🔴 ENGINE: Updating warehouse road position to ($roadX, $roadY)');
    state = state.copyWith(warehouseRoadX: roadX, warehouseRoadY: roadY);
    _streamController.add(state);
  }

  /// Start the simulation (ticks every 1 second)
  void start() {
    print('🔴 ENGINE: Start requested');
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        // Safe check to ensure we don't tick if disposed
        if (!mounted) {
          timer.cancel();
          return;
        }
        _tick();
      },
    );
  }

  /// Stop the simulation
  void stop() {
    _tickTimer?.cancel();
    _tickTimer = null;
  }

  /// Pause the simulation
  void pause() {
    stop();
  }

  /// Resume the simulation
  void resume() {
    start();
  }

  @override
  void dispose() {
    stop();
    if (!_streamController.isClosed) {
      _streamController.close();
    }
    // SimulationEngine is a StateNotifier, so we must call super.dispose()
    // However, if we are manually managing it inside another notifier, we need to be careful.
    super.dispose();
  }

  /// Main tick function - called every 1 second (10 minutes in-game)
  void _tick() {
    final currentState = state;
    
    // DEBUG PRINT
    print('🔴 ENGINE TICK: Day ${currentState.time.day} ${currentState.time.hour}:00 | Machines: ${currentState.machines.length} | Cash: \$${currentState.cash.toStringAsFixed(2)}');

    final nextTime = currentState.time.nextTick();

    // 1. Process Sales
    var updatedMachines = _processMachineSales(currentState.machines, nextTime);
    
    // 2. Process Spoilage
    updatedMachines = _processSpoilage(updatedMachines, nextTime);
    
    // 3. Process Trucks (Movement)
    var updatedTrucks = _processTruckMovement(currentState.trucks, updatedMachines);
    
    // 4. Process Restocking (Truck arrived at machine)
    final restockResult = _processTruckRestocking(updatedTrucks, updatedMachines);
    updatedTrucks = restockResult.trucks;
    updatedMachines = restockResult.machines;

    // 5. Reputation & Cash
    final reputationPenalty = _calculateReputationPenalty(updatedMachines);
    var updatedReputation = (currentState.reputation - reputationPenalty).clamp(0, 1000);
    var updatedCash = currentState.cash;
    updatedCash = _processFuelCosts(updatedTrucks, currentState.trucks, updatedCash);

    // Update State
    final newState = currentState.copyWith(
      time: nextTime,
      machines: updatedMachines,
      trucks: updatedTrucks,
      cash: updatedCash,
      reputation: updatedReputation,
    );
    state = newState;
    
    // Notify listeners of state change via stream
    _streamController.add(newState);
  }

  /// Process machine sales based on demand math
  /// Implements: SaleChance = BaseDemand * ZoneMultiplier * HourMultiplier * Traffic
  List<Machine> _processMachineSales(List<Machine> machines, GameTime time) {
    return machines.map((machine) {
      if (machine.isBroken || machine.isEmpty) {
        // Increment hours since restock if empty
        return machine.copyWith(
          hoursSinceRestock: machine.hoursSinceRestock + (10 / 60), // 10 minutes
        );
      }

      var updatedInventory = Map<Product, InventoryItem>.from(machine.inventory);
      var updatedCash = machine.currentCash;
      var salesCount = machine.totalSales;
      var hoursSinceRestock = machine.hoursSinceRestock;

      // Process each product type
      for (final product in Product.values) {
        final stock = machine.getStock(product);
        if (stock == 0) continue;

        // Calculate sale chance using the demand formula
        final baseDemand = product.baseDemand;
        final zoneMultiplier = machine.zone.getDemandMultiplier(time.hour);
        final trafficMultiplier = machine.zone.trafficMultiplier;
        
        // Example: Coffee at Office at 8 AM
        // baseDemand = 0.10 (coffee)
        // zoneMultiplier = 2.0 (office at 8 AM)
        // trafficMultiplier = 1.2 (office traffic)
        // SaleChance = 0.10 * 2.0 * 1.2 = 0.24 (24% chance per tick)
        final saleChance = baseDemand * zoneMultiplier * trafficMultiplier;
        
        // Clamp to reasonable range (0.0 to 1.0)
        final clampedChance = saleChance.clamp(0.0, 1.0);

        // Roll for sale
        if (_random.nextDouble() < clampedChance) {
          // Sale occurred!
          final item = updatedInventory[product]!;
          final newQuantity = item.quantity - 1;
          
          if (newQuantity > 0) {
            updatedInventory[product] = item.copyWith(quantity: newQuantity);
          } else {
            updatedInventory.remove(product);
          }

          updatedCash += product.basePrice;
          salesCount++;
        }
      }

      // Update hours since restock (increment by 10 minutes = 1/6 hour)
      hoursSinceRestock += (10 / 60);

      return machine.copyWith(
        inventory: updatedInventory,
        currentCash: updatedCash,
        totalSales: salesCount,
        hoursSinceRestock: hoursSinceRestock,
      );
    }).toList();
  }

  /// Process spoilage - remove expired items and charge disposal cost
  List<Machine> _processSpoilage(List<Machine> machines, GameTime time) {
    return machines.map((machine) {
      var updatedInventory = Map<Product, InventoryItem>.from(machine.inventory);
      var disposalCost = 0.0;

      // Check each inventory item for expiration
      final itemsToRemove = <Product>[];
      for (final entry in updatedInventory.entries) {
        final item = entry.value;
        if (item.isExpired(time.day)) {
          // Item expired - remove and charge disposal
          disposalCost += SimulationConstants.disposalCostPerExpiredItem * item.quantity;
          itemsToRemove.add(entry.key);
        }
      }

      // Remove expired items
      for (final product in itemsToRemove) {
        updatedInventory.remove(product);
      }

      // Deduct disposal cost from machine cash
      final updatedCash = machine.currentCash - disposalCost;

      return machine.copyWith(
        inventory: updatedInventory,
        currentCash: updatedCash,
      );
    }).toList();
  }


  /// Calculate reputation penalty based on empty machines
  int _calculateReputationPenalty(List<Machine> machines) {
    int totalPenalty = 0;
    
    for (final machine in machines) {
      if (machine.isEmpty && machine.hoursEmpty >= SimulationConstants.emptyMachinePenaltyHours) {
        final hoursOverLimit = machine.hoursEmpty - SimulationConstants.emptyMachinePenaltyHours;
        totalPenalty += (SimulationConstants.reputationPenaltyPerEmptyHour * hoursOverLimit).round();
      }
    }
    
    return totalPenalty;
  }

  /// Process truck movement and route logic
  List<Truck> _processTruckMovement(
    List<Truck> trucks,
    List<Machine> machines,
  ) {
    // Valid road coordinates (roads are at grid positions 3, 6, 9 = zone 4.0, 7.0, 10.0, plus edge at 1.0)
    const validRoads = [1.0, 4.0, 7.0, 10.0];
    // Outward roads (edges - avoid unless necessary, prefer inward roads 4.0, 7.0)
    const outwardRoads = [1.0, 10.0];
    
    // Movement speed: 1.0 units per tick = 1 tick per road tile (5x faster)
    const double movementSpeed = 1.0;
    
    // Helper function to snap to nearest valid road coordinate
    double snapToNearestRoad(double coord) {
      final rounded = coord.round().toDouble();
      double nearest = validRoads[0];
      double minDist = (rounded - nearest).abs();
      for (final road in validRoads) {
        final dist = (rounded - road).abs();
        if (dist < minDist) {
          minDist = dist;
          nearest = road;
        }
      }
      return nearest;
    }
    
    
    // A* pathfinding to find shortest path through road network
    List<({double x, double y})> findPath(
      double startX, double startY,
      double endX, double endY,
    ) {
      // Don't snap start position immediately - treat it as a potential point on a road line
      final start = (x: startX, y: startY);
      // Snap end position (destinations are always on valid roads or intersections)
      final end = (x: snapToNearestRoad(endX), y: snapToNearestRoad(endY));
      
      // If close to destination, return simple path
      if ((start.x - end.x).abs() < 0.1 && (start.y - end.y).abs() < 0.1) {
        return [end];
      }
      
      final graph = <({double x, double y}), List<({double x, double y})>>{};
      
      // Helper to check if a coordinate is on an outward road
      bool isOutwardRoad(double coord) => outwardRoads.contains(coord);
      
      // 1. Build basic grid graph (intersections)
      for (final roadX in validRoads) {
        for (final roadY in validRoads) {
          final node = (x: roadX, y: roadY);
          graph[node] = [];
          
          // Connect horizontally
          for (final otherRoadX in validRoads) {
            if (otherRoadX != roadX) {
              final targetNode = (x: otherRoadX, y: roadY);
              final isCurrentOutward = isOutwardRoad(roadX);
              final isTargetOutward = isOutwardRoad(otherRoadX);
              // Avoid outward roads unless already on one or target is there
              if (!isTargetOutward || isCurrentOutward || 
                  (targetNode.x == end.x && targetNode.y == end.y)) {
                graph[node]!.add(targetNode);
              }
            }
          }
          
          // Connect vertically
          for (final otherRoadY in validRoads) {
            if (otherRoadY != roadY) {
              final targetNode = (x: roadX, y: otherRoadY);
              final isCurrentOutward = isOutwardRoad(roadY);
              final isTargetOutward = isOutwardRoad(otherRoadY);
              if (!isTargetOutward || isCurrentOutward ||
                  (targetNode.x == end.x && targetNode.y == end.y)) {
                graph[node]!.add(targetNode);
              }
            }
          }
        }
      }

      // 2. Add Start Node to Graph
      // Find neighbors for start node based on its position
      graph[start] = [];
      
      // Snap start to nearest road lines to find valid neighbors
      final snappedStartX = snapToNearestRoad(startX);
      final snappedStartY = snapToNearestRoad(startY);
      
      // Check if start is close to a horizontal road (y is fixed)
      if ((startY - snappedStartY).abs() < 0.1) {
        // We are on horizontal road y=snappedStartY. Connect to road nodes on this line.
        for (final roadX in validRoads) {
           final neighbor = (x: roadX, y: snappedStartY);
           if (graph.containsKey(neighbor)) {
             graph[start]!.add(neighbor);
             // Also add reverse connection for A* to work
             graph[neighbor]!.add(start); 
           }
        }
      }
      
      // Check if start is close to a vertical road (x is fixed)
      if ((startX - snappedStartX).abs() < 0.1) {
        // We are on vertical road x=snappedStartX. Connect to road nodes on this line.
         for (final roadY in validRoads) {
           final neighbor = (x: snappedStartX, y: roadY);
           if (graph.containsKey(neighbor)) {
             graph[start]!.add(neighbor);
             graph[neighbor]!.add(start);
           }
        }
      }
      
      // 3. Add End Node to Graph (if not already an intersection)
      if (!graph.containsKey(end)) {
        graph[end] = [];
        // Connect end node to neighbors similarly
        // (Though usually end node IS an intersection or snapped to one)
         for (final roadX in validRoads) {
            if ((end.y - roadX).abs() < 0.1) continue; // Skip if same
             // ... Logic for end node connecting to grid ...
             // Simplified: End is usually a road intersection or snapped to one by caller
             // But if it's not, we should connect it.
             // Given snapToNearestRoad used for end, it IS an intersection or close enough.
        }
      }
      
      // A* algorithm
      final openSet = <({double x, double y})>{start};
      final cameFrom = <({double x, double y}), ({double x, double y})>{};
      final gScore = <({double x, double y}), double>{start: 0.0};
      final fScore = <({double x, double y}), double>{start: (end.x - start.x).abs() + (end.y - start.y).abs()};
      
      while (openSet.isNotEmpty) {
        // Find node with lowest fScore
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
        
        if ((current.x - end.x).abs() < 0.1 && (current.y - end.y).abs() < 0.1) {
          // Reconstruct path
          final path = <({double x, double y})>[end];
          var node = current!; // Use current as it matches end
          while (cameFrom.containsKey(node)) {
            node = cameFrom[node]!;
            if (node == start) break; // Don't include start in path
            path.insert(0, node);
          }
           // Ensure end is in path
          if (path.isEmpty || path.last != end) path.add(end);
          return path;
        }
        
        openSet.remove(current);
        final neighbors = graph[current] ?? [];
        
        for (final neighbor in neighbors) {
          // Manhattan distance as edge cost
          double edgeCost = (neighbor.x - current.x).abs() + (neighbor.y - current.y).abs();
          
          // Add penalty for using outward roads (encourages using inward roads)
          // Don't penalize moving FROM start or TO end
          if (current != start && neighbor != end) {
             if (isOutwardRoad(neighbor.x) || isOutwardRoad(neighbor.y)) {
               edgeCost += 10.0; 
             }
          }
          
          final tentativeG = (gScore[current] ?? double.infinity) + edgeCost;
          
          if (tentativeG < (gScore[neighbor] ?? double.infinity)) {
            cameFrom[neighbor] = current;
            gScore[neighbor] = tentativeG;
            // Heuristic: Manhattan distance to goal
            fScore[neighbor] = tentativeG + ((end.x - neighbor.x).abs() + (end.y - neighbor.y).abs());
            if (!openSet.contains(neighbor)) {
              openSet.add(neighbor);
            }
          }
        }
      }
      
      // Fallback
      return [end];
    }
    
    return trucks.map((truck) {
      // ---------------------------------------------------------
      // CASE 1: ROUTE COMPLETE - RETURN TO WAREHOUSE
      // ---------------------------------------------------------
      if (truck.isRouteComplete) {
        // Get warehouse position from simulation state
        final warehouseRoadX = state.warehouseRoadX ?? 4.0; // Fallback if not set
        final warehouseRoadY = state.warehouseRoadY ?? 4.0; // Fallback if not set
        
        // If truck was restocking but is now complete, ensure it's traveling
        var currentStatus = truck.status;
        if (currentStatus == TruckStatus.restocking) {
            currentStatus = TruckStatus.traveling;
        }

        final currentX = truck.currentX;
        final currentY = truck.currentY;
        
        // Calculate distance to warehouse
        final dxToWarehouse = warehouseRoadX - currentX;
        final dyToWarehouse = warehouseRoadY - currentY;
        final distanceToWarehouse = math.sqrt(dxToWarehouse * dxToWarehouse + dyToWarehouse * dyToWarehouse);
        
        // If already very close to warehouse, mark as Idle and snap
        if (distanceToWarehouse < 0.1) {
          return truck.copyWith(
            status: TruckStatus.idle,
            currentX: warehouseRoadX,
            currentY: warehouseRoadY,
            targetX: warehouseRoadX,
            targetY: warehouseRoadY,
            path: [],
            pathIndex: 0,
            // Ensure route index stays complete (redundant but safe)
            currentRouteIndex: truck.route.length, 
          );
        }
        
        // Not at warehouse yet - calculate movement
        
        // Get or calculate path to warehouse
        List<({double x, double y})> path = truck.path;
        int pathIndex = truck.pathIndex;
        
        // Recalculate path if needed:
        // 1. Path is empty
        // 2. Path end point is not warehouse
        // 3. Path index is invalid
        if (path.isEmpty || 
            (path.isNotEmpty && (path.last.x != warehouseRoadX || path.last.y != warehouseRoadY)) ||
            pathIndex >= path.length) {
          path = findPath(currentX, currentY, warehouseRoadX, warehouseRoadY);
          pathIndex = 0;
        }
        
        // Move along the path
        var currentPathIndex = pathIndex;
        var simX = currentX;
        var simY = currentY;
        var newStatus = currentStatus == TruckStatus.idle ? TruckStatus.traveling : currentStatus;

        // Process movement (support multiple waypoints per tick)
        while (currentPathIndex < path.length) {
          final targetWaypoint = path[currentPathIndex];
          final dx = targetWaypoint.x - simX;
          final dy = targetWaypoint.y - simY;
          final distance = math.sqrt(dx * dx + dy * dy);
          
          if (distance < 0.1) {
            // Reached waypoint, snap and move to next
            simX = targetWaypoint.x;
            simY = targetWaypoint.y;
            currentPathIndex++;
          } else {
            // Move towards waypoint
            final moveDistance = movementSpeed.clamp(0.0, distance);
            final ratio = moveDistance / distance;
            simX += dx * ratio;
            simY += dy * ratio;
            break; // Moved max distance for this tick
          }
        }
        
        // Check if we reached the final destination (Warehouse)
        if (currentPathIndex >= path.length) {
           newStatus = TruckStatus.idle;
           simX = warehouseRoadX;
           simY = warehouseRoadY;
        }

        return truck.copyWith(
          status: newStatus,
          currentX: simX,
          currentY: simY,
          targetX: warehouseRoadX,
          targetY: warehouseRoadY,
          path: path,
          pathIndex: currentPathIndex,
        );
      }
      
      // ---------------------------------------------------------
      // CASE 2: ROUTE INCOMPLETE - TRAVEL TO NEXT MACHINE
      // ---------------------------------------------------------
      
      // Get current destination
      final destinationId = truck.currentDestination;
      
      if (destinationId == null) {
        // Should catch this in Case 1, but as fallback:
        return truck.copyWith(status: TruckStatus.idle);
      }

      // Find destination machine
      final destination = machines.firstWhere(
        (m) => m.id == destinationId,
        orElse: () => machines.first, // Fallback
      );

      // Get machine position and snap to nearest road
      final machineX = destination.zone.x;
      final machineY = destination.zone.y;
      
      // Find the closest valid road to the machine
      double destRoadX = validRoads[0];
      double destRoadY = validRoads[0];
      double minDist = double.infinity;
      
      // Check all valid road positions
      for (final roadX in validRoads) {
        for (final roadY in validRoads) {
          final dist = (machineX - roadX).abs() + (machineY - roadY).abs();
          if (dist < minDist) {
            minDist = dist;
            destRoadX = roadX;
            destRoadY = roadY;
          }
        }
      }
      
      // Also check if we can use a road line closer to machine
      for (final roadY in validRoads) {
        final closestRoadX = snapToNearestRoad(machineX);
        final dist = (machineX - closestRoadX).abs() + (machineY - roadY).abs();
        if (dist < minDist) {
          minDist = dist;
          destRoadX = closestRoadX;
          destRoadY = roadY;
        }
      }
      for (final roadX in validRoads) {
        final closestRoadY = snapToNearestRoad(machineY);
        final dist = (machineX - roadX).abs() + (machineY - closestRoadY).abs();
        if (dist < minDist) {
          minDist = dist;
          destRoadX = roadX;
          destRoadY = closestRoadY;
        }
      }
      
      // Calculate distance to destination road
      final currentX = truck.currentX;
      final currentY = truck.currentY;
      final dxToRoad = destRoadX - currentX;
      final dyToRoad = destRoadY - currentY;
      final manhattanDistance = dxToRoad.abs() + dyToRoad.abs();

      // If truck is at the road adjacent to the machine, mark as arrived for restocking
      if (manhattanDistance < 0.1) {
        return truck.copyWith(
          status: TruckStatus.restocking,
          currentX: destRoadX,
          currentY: destRoadY,
          targetX: destRoadX,
          targetY: destRoadY,
          path: [],
          pathIndex: 0,
        );
      }

      // Get or calculate path to destination
      List<({double x, double y})> path = truck.path;
      int pathIndex = truck.pathIndex;
      
      // Recalculate path if:
      // 1. Path is empty
      // 2. Path end point is not current destination
      // 3. Path index is invalid
      if (path.isEmpty || 
          (path.isNotEmpty && (path.last.x != destRoadX || path.last.y != destRoadY)) ||
          pathIndex >= path.length) {
        path = findPath(currentX, currentY, destRoadX, destRoadY);
        pathIndex = 0;
      }
      
      // Move along the path
      var currentPathIndex = pathIndex;
      var simX = currentX;
      var simY = currentY;
      
      // Process movement
      while (currentPathIndex < path.length) {
        final targetWaypoint = path[currentPathIndex];
        final dx = targetWaypoint.x - simX;
        final dy = targetWaypoint.y - simY;
        final distance = math.sqrt(dx * dx + dy * dy);
        
        if (distance < 0.1) {
          // Reached waypoint
          simX = targetWaypoint.x;
          simY = targetWaypoint.y;
          currentPathIndex++;
        } else {
          // Move
          final moveDistance = movementSpeed.clamp(0.0, distance);
          final ratio = moveDistance / distance;
          simX += dx * ratio;
          simY += dy * ratio;
          break;
        }
      }
      
      // Check if reached destination
      var newStatus = TruckStatus.traveling;
      if (currentPathIndex >= path.length) {
         // Arrived at machine road location
         newStatus = TruckStatus.restocking;
         simX = destRoadX;
         simY = destRoadY;
      }

      return truck.copyWith(
        status: newStatus,
        currentX: simX,
        currentY: simY,
        targetX: destRoadX,
        targetY: destRoadY,
        path: path,
        pathIndex: currentPathIndex,
      );
    }).toList();
  }

  /// Process fuel costs for trucks
  double _processFuelCosts(List<Truck> updatedTrucks, List<Truck> oldTrucks, double currentCash) {
    double totalFuelCost = 0.0;
    
    // Movement speed: 1.0 units per tick = 1 tick per road tile (matches truck movement speed)
    const double movementSpeed = 1.0;

    for (final truck in updatedTrucks) {
      // Find the previous state of this truck
      final oldTruck = oldTrucks.firstWhere(
        (t) => t.id == truck.id,
        orElse: () => truck, // Fallback if new truck
      );

      // Check if truck has actually moved
      final hasMoved = (truck.currentX - oldTruck.currentX).abs() > 0.001 || 
                       (truck.currentY - oldTruck.currentY).abs() > 0.001;

      // Only charge fuel when truck is actually moving
      if (hasMoved) {
        // Charge based on actual distance moved per tick (movement speed)
        final fuelCost = movementSpeed * SimulationConstants.gasPrice;
        totalFuelCost += fuelCost;
      }
    }

    return currentCash - totalFuelCost;
  }

  /// Calculate total distance for a truck route
  double calculateRouteDistance(
    List<String> machineIds,
    List<Machine> machines,
  ) {
    if (machineIds.length < 2) return 0.0;

    double totalDistance = 0.0;
    
    for (int i = 0; i < machineIds.length - 1; i++) {
      final machine1 = machines.firstWhere(
        (m) => m.id == machineIds[i],
      );
      final machine2 = machines.firstWhere(
        (m) => m.id == machineIds[i + 1],
      );

      final dx = machine2.zone.x - machine1.zone.x;
      final dy = machine2.zone.y - machine1.zone.y;
      totalDistance += (dx * dx + dy * dy) * 0.5; // Euclidean distance
    }

    return totalDistance;
  }

  /// Manually trigger a tick (for testing or manual control)
  void manualTick() {
    _tick();
  }

  /// Process a single tick with provided machines and trucks, returning updated lists
  /// This method is used by GameController to sync state
  ({List<Machine> machines, List<Truck> trucks}) tick(
    List<Machine> machines,
    List<Truck> trucks,
  ) {
    final currentTime = state.time;
    final nextTime = currentTime.nextTick();

    // Process all simulation systems
    var updatedMachines = _processMachineSales(machines, nextTime);
    updatedMachines = _processSpoilage(updatedMachines, nextTime);
    
    // Process truck movement and restocking
    var updatedTrucks = _processTruckMovement(trucks, updatedMachines);
    
    // Handle automatic restocking when trucks arrive at machines
    final restockResult = _processTruckRestocking(updatedTrucks, updatedMachines);
    updatedTrucks = restockResult.trucks;
    updatedMachines = restockResult.machines;

    return (machines: updatedMachines, trucks: updatedTrucks);
  }

  /// Process truck restocking when trucks arrive at machines
  ({List<Machine> machines, List<Truck> trucks}) _processTruckRestocking(
    List<Truck> trucks,
    List<Machine> machines,
  ) {
    var updatedMachines = List<Machine>.from(machines);
    var updatedTrucks = List<Truck>.from(trucks);
    final currentDay = state.time.day;

    for (int i = 0; i < updatedTrucks.length; i++) {
      final truck = updatedTrucks[i];
      
      // Only process trucks that are restocking
      if (truck.status != TruckStatus.restocking) continue;
      
      // Ensure truck stays on road (snap to nearest road coordinate)
      final roadX = truck.currentX.round().toDouble();
      final roadY = truck.currentY.round().toDouble();
      
      final destinationId = truck.currentDestination;
      if (destinationId == null) continue;

      // Find the machine being restocked
      final machineIndex = updatedMachines.indexWhere((m) => m.id == destinationId);
      if (machineIndex == -1) continue;

      final machine = updatedMachines[machineIndex];
      var machineInventory = Map<Product, InventoryItem>.from(machine.inventory);
      var truckInventory = Map<Product, int>.from(truck.inventory);

      // Transfer items from truck to machine (up to machine capacity)
      // Each product type has a limit of 20 items per machine
      const maxItemsPerProduct = 20;

      if (truckInventory.isNotEmpty) {
        var itemsToTransfer = <Product, int>{};

        // Transfer items from truck to machine
        for (final entry in truckInventory.entries) {
          final product = entry.key;
          final truckQuantity = entry.value;
          if (truckQuantity <= 0) continue;

          // Check current stock of this product in machine
          final currentProductStock = machineInventory[product]?.quantity ?? 0;
          final availableSpaceForProduct = maxItemsPerProduct - currentProductStock;
          
          if (availableSpaceForProduct <= 0) continue; // This product is already at limit

          // Transfer up to the limit for this product
          final transferAmount = (truckQuantity < availableSpaceForProduct)
              ? truckQuantity
              : availableSpaceForProduct;

          // Update machine inventory
          final existingItem = machineInventory[product];
          if (existingItem != null) {
            machineInventory[product] = existingItem.copyWith(
              quantity: existingItem.quantity + transferAmount,
            );
          } else {
            machineInventory[product] = InventoryItem(
              product: product,
              quantity: transferAmount,
              dayAdded: currentDay,
            );
          }

          // Update truck inventory
          final remainingTruckQuantity = truckQuantity - transferAmount;
          if (remainingTruckQuantity > 0) {
            itemsToTransfer[product] = remainingTruckQuantity;
          }
        }

        // Update truck inventory
        final updatedTruckInventory = itemsToTransfer;
        
        // Check if truck is empty or if there are more destinations
        final isTruckEmpty = updatedTruckInventory.isEmpty;
        final hasMoreDestinations = truck.currentRouteIndex + 1 < truck.route.length;
        
        // Check if any remaining destinations need items from the truck
        bool remainingDestinationsNeedItems = false;
        if (!isTruckEmpty && hasMoreDestinations) {
          // Check remaining machines in route
          for (int routeIdx = truck.currentRouteIndex + 1; routeIdx < truck.route.length; routeIdx++) {
            final remainingMachineId = truck.route[routeIdx];
            final remainingMachine = updatedMachines.firstWhere(
              (m) => m.id == remainingMachineId,
              orElse: () => updatedMachines.first, // Fallback (shouldn't happen)
            );
            
            // Check if this machine needs any of the products the truck is carrying
            for (final entry in updatedTruckInventory.entries) {
              final product = entry.key;
              final truckQuantity = entry.value;
              if (truckQuantity <= 0) continue;
              
              final currentProductStock = remainingMachine.inventory[product]?.quantity ?? 0;
              if (currentProductStock < maxItemsPerProduct) {
                remainingDestinationsNeedItems = true;
                break;
              }
            }
            
            if (remainingDestinationsNeedItems) break;
          }
        }
        
        // Get warehouse position for returning
        final warehouseRoadX = state.warehouseRoadX ?? 4.0; // Fallback if not set
        final warehouseRoadY = state.warehouseRoadY ?? 4.0; // Fallback if not set
        
        if (isTruckEmpty || !hasMoreDestinations || !remainingDestinationsNeedItems) {
          // Truck is empty OR last destination completed OR no remaining destinations need items - return to warehouse
          updatedTrucks[i] = truck.copyWith(
            inventory: updatedTruckInventory,
            status: TruckStatus.traveling,
            currentRouteIndex: truck.route.length, // Mark route as complete
            targetX: warehouseRoadX,
            targetY: warehouseRoadY,
            path: [], // Clear path so it recalculates to warehouse
            pathIndex: 0,
            // Keep truck on road while transitioning
            currentX: roadX,
            currentY: roadY,
          );
        } else {
          // Still have inventory and more destinations that need items - continue to next machine
          updatedTrucks[i] = truck.copyWith(
            inventory: updatedTruckInventory,
            status: TruckStatus.traveling,
            currentRouteIndex: truck.currentRouteIndex + 1,
            // Keep truck on road
            currentX: roadX,
            currentY: roadY,
          );
        }

        // Update machine
        updatedMachines[machineIndex] = machine.copyWith(
          inventory: machineInventory,
          hoursSinceRestock: 0.0,
        );
      } else {
        // No items transferred (machine already full or truck empty)
        // Keep truck on road
        final roadX = truck.currentX.round().toDouble();
        final roadY = truck.currentY.round().toDouble();
        final isTruckEmpty = truck.inventory.isEmpty;
        final hasMoreDestinations = truck.currentRouteIndex + 1 < truck.route.length;
        
        // Check if any remaining destinations need items from the truck
        bool remainingDestinationsNeedItems = false;
        if (!isTruckEmpty && hasMoreDestinations) {
          // Check remaining machines in route
          for (int routeIdx = truck.currentRouteIndex + 1; routeIdx < truck.route.length; routeIdx++) {
            final remainingMachineId = truck.route[routeIdx];
            final remainingMachine = updatedMachines.firstWhere(
              (m) => m.id == remainingMachineId,
              orElse: () => updatedMachines.first, // Fallback (shouldn't happen)
            );
            
            // Check if this machine needs any of the products the truck is carrying
            for (final entry in truck.inventory.entries) {
              final product = entry.key;
              final truckQuantity = entry.value;
              if (truckQuantity <= 0) continue;
              
              final currentProductStock = remainingMachine.inventory[product]?.quantity ?? 0;
              if (currentProductStock < maxItemsPerProduct) {
                remainingDestinationsNeedItems = true;
                break;
              }
            }
            
            if (remainingDestinationsNeedItems) break;
          }
        }
        
        // Get warehouse position for returning
        final warehouseRoadX = state.warehouseRoadX ?? 4.0; // Fallback if not set
        final warehouseRoadY = state.warehouseRoadY ?? 4.0; // Fallback if not set
        
        if (isTruckEmpty || !hasMoreDestinations || !remainingDestinationsNeedItems) {
          // Truck is empty OR last destination OR no remaining destinations need items - return to warehouse
          updatedTrucks[i] = truck.copyWith(
            status: TruckStatus.traveling,
            currentRouteIndex: truck.route.length, // Mark route as complete
            targetX: warehouseRoadX,
            targetY: warehouseRoadY,
            path: [], // Clear path so it recalculates to warehouse
            pathIndex: 0,
            currentX: roadX,
            currentY: roadY,
          );
        } else {
          // Still have inventory and more destinations that need items - continue to next machine
          updatedTrucks[i] = truck.copyWith(
            status: TruckStatus.traveling,
            currentRouteIndex: truck.currentRouteIndex + 1,
            currentX: roadX,
            currentY: roadY,
          );
        }
      }
    }

    return (machines: updatedMachines, trucks: updatedTrucks);
  }
}

