import '../engine.dart';
import '../models/machine.dart';
import '../models/product.dart';
import '../models/truck.dart';
import '../models/research.dart';
import '../models/zone.dart';
import '../../state/game_log_entry.dart';
import '../../state/providers.dart'; // Import Warehouse
import 'simulation_system.dart';
import 'dart:math' as math;

class InventorySystem implements SimulationSystem {
  @override
  SimulationState update(SimulationState state, GameTime time) {
    var updatedMachines = _processSpoilage(state.machines, time, state.unlockedResearch);

    var autoRestockResult = _processAutoRestock(state.trucks, updatedMachines, state.warehouse, time);
    var updatedTrucks = autoRestockResult.trucks;
    updatedMachines = autoRestockResult.machines;
    var updatedWarehouse = autoRestockResult.warehouse;

    final currentMessages = List<GameLogEntry>.from(state.pendingMessages);
    currentMessages.addAll(autoRestockResult.messages);

    return state.copyWith(
      machines: updatedMachines,
      trucks: updatedTrucks,
      warehouse: updatedWarehouse,
      pendingMessages: currentMessages,
    );
  }

  /// Process spoilage
  List<Machine> _processSpoilage(List<Machine> machines, GameTime time, Set<ResearchType> unlockedResearch) {
    return machines.map((machine) {
      var updatedInventory = Map<Product, InventoryItem>.from(machine.inventory);
      var disposalCost = 0.0;

      final hasEfficientCooling = unlockedResearch.contains(ResearchType.efficientCooling);

      for (final entry in updatedInventory.entries) {
        final item = entry.value;

        bool isExpired = false;
        if (item.product.canSpoil) {
          int spoilageDays = item.product.spoilageDays;

          if (hasEfficientCooling) {
            spoilageDays *= 2;
          }

          isExpired = (time.day - item.dayAdded) >= spoilageDays;
        }

        if (isExpired) {
          disposalCost += SimulationConstants.disposalCostPerExpiredItem * item.quantity;
          updatedInventory[entry.key] = item.copyWith(quantity: 0);
        }
      }

      final updatedCash = machine.currentCash - disposalCost;

      return machine.copyWith(
        inventory: updatedInventory,
        currentCash: updatedCash,
      );
    }).toList();
  }

  /// Process auto-restock for trucks with drivers
  ({List<Truck> trucks, List<Machine> machines, Warehouse warehouse, List<GameLogEntry> messages}) _processAutoRestock(
    List<Truck> trucks,
    List<Machine> machines,
    Warehouse currentWarehouse,
    GameTime time,
  ) {
    var updatedTrucks = List<Truck>.from(trucks);
    var updatedMachines = List<Machine>.from(machines);
    var updatedWarehouseInventory = Map<Product, int>.from(currentWarehouse.inventory);
    var messages = <GameLogEntry>[];

    for (int i = 0; i < updatedTrucks.length; i++) {
      final truck = updatedTrucks[i];

      if (!truck.hasDriver || truck.status != TruckStatus.idle) {
        continue;
      }

      final routeMachines = <Machine>[];
      final routeDemand = <Product, int>{};
      bool hasLowStockItem = false;

      for (final machineId in truck.route) {
        final machineIndex = updatedMachines.indexWhere((m) => m.id == machineId);
        if (machineIndex == -1) continue;

        final machine = updatedMachines[machineIndex];
        final allowedProducts = Zone.getAllowedProducts(machine.zone.type);

        for (final product in allowedProducts) {
          final existingItem = machine.inventory[product];
          final currentStock = existingItem?.quantity ?? 0;
          final allocationTarget = existingItem?.allocation ?? 20;

          if (allocationTarget > 0 && currentStock < (allocationTarget / 2)) {
            hasLowStockItem = true;
            break;
          }
        }

        if (hasLowStockItem) break;
      }

      if (!hasLowStockItem) {
        continue;
      }

      for (final machineId in truck.route) {
        final machineIndex = updatedMachines.indexWhere((m) => m.id == machineId);
        if (machineIndex == -1) continue;

        final machine = updatedMachines[machineIndex];
        routeMachines.add(machine);

        final allowedProducts = Zone.getAllowedProducts(machine.zone.type);
        for (final product in allowedProducts) {
          final existingItem = machine.inventory[product];
          final currentStock = existingItem?.quantity ?? 0;
          final allocationTarget = existingItem?.allocation ?? 20;
          final deficit = allocationTarget - currentStock;

          if (deficit > 0) {
            routeDemand[product] = (routeDemand[product] ?? 0) + deficit;
          }
        }
      }

      if (routeMachines.isEmpty || routeDemand.isEmpty) {
        continue;
      }

      final currentTruck = updatedTrucks[i];
      final existingTruckInventory = Map<Product, int>.from(currentTruck.inventory);
      final truckInventory = <Product, int>{};
      int totalLoaded = existingTruckInventory.values.fold<int>(0, (sum, qty) => sum + qty);

      final baseTotalDemand = routeDemand.values.fold<int>(0, (sum, demand) => sum + demand);
      final totalDemandWithBuffer = (baseTotalDemand * 1.2).ceil();

      final adjustedRouteDemand = <Product, int>{};
      for (final entry in routeDemand.entries) {
        final adjustedDemand = (entry.value * 1.2).ceil();
        adjustedRouteDemand[entry.key] = adjustedDemand;
      }

      for (final entry in adjustedRouteDemand.entries) {
        if (totalLoaded >= currentTruck.capacity) break;

        final product = entry.key;
        final totalDemandForProduct = entry.value;
        final warehouseStock = updatedWarehouseInventory[product] ?? 0;
        final alreadyOnTruck = existingTruckInventory[product] ?? 0;
        final stillNeeded = totalDemandForProduct - alreadyOnTruck;

        if (warehouseStock > 0 && stillNeeded > 0) {
          final proportion = totalDemandForProduct / totalDemandWithBuffer;
          final proportionalCapacity = (currentTruck.capacity * proportion).ceil();
          final remainingCapacity = currentTruck.capacity - totalLoaded;

          final loadAmount = math.min(
            math.min(proportionalCapacity, remainingCapacity),
            math.min(stillNeeded, warehouseStock)
          );

          if (loadAmount > 0) {
            truckInventory[product] = alreadyOnTruck + loadAmount;
            updatedWarehouseInventory[product] = warehouseStock - loadAmount;
            totalLoaded += loadAmount;
          } else if (alreadyOnTruck > 0) {
            truckInventory[product] = alreadyOnTruck;
          }
        } else if (alreadyOnTruck > 0) {
          truckInventory[product] = alreadyOnTruck;
        }
      }

      if (totalLoaded < currentTruck.capacity) {
        final sortedDemand = adjustedRouteDemand.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        for (final entry in sortedDemand) {
          if (totalLoaded >= currentTruck.capacity) break;

          final product = entry.key;
          final totalDemandForProduct = entry.value;
          final warehouseStock = updatedWarehouseInventory[product] ?? 0;
          final alreadyLoaded = truckInventory[product] ?? 0;
          final remainingDemand = totalDemandForProduct - alreadyLoaded;

          if (remainingDemand > 0 && warehouseStock > 0) {
            final remainingCapacity = currentTruck.capacity - totalLoaded;
            final additionalLoad = math.min(remainingCapacity, math.min(remainingDemand, warehouseStock));

            if (additionalLoad > 0) {
              truckInventory[product] = alreadyLoaded + additionalLoad;
              updatedWarehouseInventory[product] = warehouseStock - additionalLoad;
              totalLoaded += additionalLoad;
            }
          }
        }
      }

      for (final entry in existingTruckInventory.entries) {
        if (!truckInventory.containsKey(entry.key)) {
          truckInventory[entry.key] = entry.value;
        }
      }

      final loadedTruck = currentTruck.copyWith(inventory: truckInventory);

      final targetMachine = routeMachines.first;
      final machineX = targetMachine.zone.x;
      final machineY = targetMachine.zone.y;

      final targetIndex = loadedTruck.route.indexOf(targetMachine.id);
      final routeIndex = targetIndex >= 0 ? targetIndex : 0;

      updatedTrucks[i] = loadedTruck.copyWith(
        status: TruckStatus.traveling,
        path: [],
        targetX: machineX,
        targetY: machineY,
        currentRouteIndex: routeIndex,
      );

      // Log loading
      if (truckInventory.isNotEmpty && totalLoaded > existingTruckInventory.values.fold<int>(0, (sum, qty) => sum + qty)) {
        final newlyLoaded = truckInventory.entries
            .where((e) => (e.value - (existingTruckInventory[e.key] ?? 0)) > 0)
            .map((e) => '${e.key.name}: +${e.value - (existingTruckInventory[e.key] ?? 0)}')
            .join(', ');

        messages.add(GameLogEntry(
          type: LogType.truckLoad,
          timestamp: time,
          data: {
            'details': newlyLoaded,
            'truckName': currentTruck.name,
          }
        ));
      }
    }

    return (
      trucks: updatedTrucks,
      machines: updatedMachines,
      warehouse: Warehouse(inventory: updatedWarehouseInventory),
      messages: messages,
    );
  }
}
