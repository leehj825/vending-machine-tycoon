import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateNotifierProvider;
import 'package:state_notifier/state_notifier.dart';
import 'package:uuid/uuid.dart';
import '../simulation/engine.dart';
import '../simulation/models/product.dart';
import '../simulation/models/zone.dart';
import '../simulation/models/machine.dart';
import '../simulation/models/truck.dart';
import 'game_state.dart';

part 'providers.freezed.dart';

const _uuid = Uuid();

/// Machine prices by zone type
class MachinePrices {
  static const double basePrice = 500.0;
  static const Map<ZoneType, double> zoneMultipliers = {
    ZoneType.office: 1.5,
    ZoneType.school: 1.2,
    ZoneType.gym: 1.0,
    ZoneType.subway: 1.3,
    ZoneType.park: 0.8,
  };

  static double getPrice(ZoneType zoneType) {
    return basePrice * (zoneMultipliers[zoneType] ?? 1.0);
  }
}

/// Warehouse inventory (global stock available for restocking)
@freezed
abstract class Warehouse with _$Warehouse {
  const factory Warehouse({
    @Default({}) Map<Product, int> inventory,
  }) = _Warehouse;

  const Warehouse._();
}

/// Game Controller - Manages the overall game state and simulation
class GameController extends StateNotifier<GlobalGameState> {
  final SimulationEngine simulationEngine;
  final Ref ref;

  bool _isSimulationRunning = false;

  GameController(this.ref)
      : simulationEngine = SimulationEngine(
          initialMachines: [],
          initialTrucks: [],
          initialCash: 5000.0,
          initialReputation: 100,
        ),
        super(const GlobalGameState(
          machines: [],
          trucks: [],
          warehouse: Warehouse(),
        )) {
    _setupSimulationListener();
  }

  /// Public getter to access current state
  GlobalGameState get currentState => state;

  /// Setup listener for simulation engine updates
  void _setupSimulationListener() {
    print('🟡 CONTROLLER: Setting up simulation listener...');
    
    simulationEngine.stream.listen((simState) {
      // This print confirms data is flowing from Engine -> UI
      print('🟡 CONTROLLER SYNC: Received update. Cash: \$${simState.cash.toStringAsFixed(2)}, Machines: ${simState.machines.length}');
      
      state = state.copyWith(
        machines: simState.machines,
        trucks: simState.trucks,
        cash: simState.cash,
        reputation: simState.reputation,
        dayCount: simState.time.day,
        hourOfDay: simState.time.hour,
        // Warehouse and logs are managed locally by Controller, so we don't overwrite them
      );
    });
  }

  /// Check if simulation is running
  bool get isSimulationRunning => _isSimulationRunning;

  /// Start the simulation
  void startSimulation() {
    print('🔵 CONTROLLER: Starting Simulation Engine...');
    simulationEngine.start();
    _isSimulationRunning = true;
    state = state.addLogMessage('Simulation started');
  }

  /// Stop the simulation
  void stopSimulation() {
    simulationEngine.stop();
    _isSimulationRunning = false;
    state = state.addLogMessage('Simulation stopped');
  }

  /// Pause the simulation
  void pauseSimulation() {
    simulationEngine.pause();
    _isSimulationRunning = false;
    state = state.addLogMessage('Simulation paused');
  }

  /// Resume the simulation
  void resumeSimulation() {
    simulationEngine.resume();
    _isSimulationRunning = true;
    state = state.addLogMessage('Simulation resumed');
  }

  /// Toggle simulation (start if paused, pause if running)
  void toggleSimulation() {
    if (_isSimulationRunning) {
      pauseSimulation();
    } else {
      startSimulation();
    }
  }

  /// Buy a new vending machine and place it in a zone
  void buyMachine(ZoneType zoneType, {required double x, required double y}) {
    print('🟢 CONTROLLER ACTION: Attempting to buy machine...');
    final price = MachinePrices.getPrice(zoneType);
    if (state.cash < price) {
      state = state.addLogMessage('Insufficient funds');
      return;
    }

    // 1. Create Data
    final zone = _createZoneForType(zoneType, x: x, y: y);
    
    // Create machine
    final newMachine = Machine(
      id: _uuid.v4(),
      name: '${zoneType.name.toUpperCase()} Machine ${state.machines.length + 1}',
      zone: zone,
      condition: MachineCondition.excellent,
      inventory: {},
      currentCash: 0.0,
    );

    // Update simulation engine
    final updatedMachines = [...state.machines, newMachine];
    _updateSimulationMachines(updatedMachines);

    // UPDATE STATE DIRECTLY
    state = state.copyWith(
      cash: state.cash - price,
      machines: updatedMachines,
    );
    state = state.addLogMessage("Bought ${newMachine.name}");
  }

  /// Create a zone based on zone type
  Zone _createZoneForType(ZoneType zoneType, {required double x, required double y}) {
    final id = _uuid.v4();
    final name = '${zoneType.name.toUpperCase()} Zone';

    switch (zoneType) {
      case ZoneType.office:
        return ZoneFactory.createOffice(id: id, name: name, x: x, y: y);
      case ZoneType.school:
        return ZoneFactory.createSchool(id: id, name: name, x: x, y: y);
      case ZoneType.gym:
        return ZoneFactory.createGym(id: id, name: name, x: x, y: y);
      case ZoneType.subway:
        return ZoneFactory.createSubway(id: id, name: name, x: x, y: y);
      case ZoneType.park:
        // Create a basic park zone (no factory method yet)
        return Zone(
          id: id,
          type: zoneType,
          name: name,
          x: x,
          y: y,
          demandCurve: {
            10: 1.2,  // 10 AM: Moderate
            14: 1.5,  // 2 PM: Afternoon peak
            18: 1.0,  // 6 PM: Evening
          },
          trafficMultiplier: 0.8,
        );
    }
  }


  /// Buy stock and add to warehouse
  void buyStock(Product product, int quantity, {required double unitPrice}) {
    final totalPrice = unitPrice * quantity;
    if (state.cash < totalPrice) {
      state = state.addLogMessage("Not enough cash!");
      return;
    }
    final currentQty = state.warehouse.inventory[product] ?? 0;
    final newInventory = Map<Product, int>.from(state.warehouse.inventory);
    newInventory[product] = currentQty + quantity;
    
    // Calculate new cash amount
    final newCashAmount = state.cash - totalPrice;
    
    // Update the STATE object completely
    state = state.copyWith(
      cash: state.cash - totalPrice,
      warehouse: state.warehouse.copyWith(inventory: newInventory),
    );
    state = state.addLogMessage("Bought $quantity ${product.name}");
    
    // Sync cash to simulation engine to prevent reversion on next tick
    simulationEngine.updateCash(newCashAmount);
  }

  /// Assign a route to a truck
  void assignRoute(Truck truck, List<String> machineIds) {
    if (machineIds.isEmpty) {
      state = state.addLogMessage('Cannot assign empty route to truck');
      return;
    }

    // Find truck in list
    final truckIndex = state.trucks.indexWhere((t) => t.id == truck.id);
    if (truckIndex == -1) {
      state = state.addLogMessage('Truck not found');
      return;
    }

    // Update truck route
    final updatedTruck = truck.copyWith(
      route: machineIds,
      currentRouteIndex: 0,
      status: TruckStatus.traveling,
    );

    final updatedTrucks = [...state.trucks];
    updatedTrucks[truckIndex] = updatedTruck;

    // Update state
    state = state.copyWith(trucks: updatedTrucks);
    state = state.addLogMessage(
      'Assigned route with ${machineIds.length} stops to ${truck.name}',
    );
    
    // Sync to simulation engine to prevent reversion on next tick
    simulationEngine.updateTrucks(updatedTrucks);
  }

  /// Update a truck's route (used by route planner)
  void updateRoute(String truckId, List<String> machineIds) {
    // Find truck in list
    final truckIndex = state.trucks.indexWhere((t) => t.id == truckId);
    if (truckIndex == -1) {
      state = state.addLogMessage('Truck not found');
      return;
    }

    final truck = state.trucks[truckIndex];

    // Update truck route
    final updatedTruck = truck.copyWith(
      route: machineIds,
      currentRouteIndex: 0, // Reset to start of route
      status: machineIds.isEmpty ? TruckStatus.idle : TruckStatus.traveling,
    );

    final updatedTrucks = [...state.trucks];
    updatedTrucks[truckIndex] = updatedTruck;

    // Update state
    state = state.copyWith(trucks: updatedTrucks);
    state = state.addLogMessage(
      'Updated route for ${truck.name}: ${machineIds.length} stops',
    );
    
    // Sync to simulation engine to prevent reversion on next tick
    simulationEngine.updateTrucks(updatedTrucks);
  }

  /// Load cargo onto a truck from warehouse
  void loadTruck(String truckId, Product product, int quantity) {
    // Find the truck
    final truckIndex = state.trucks.indexWhere((t) => t.id == truckId);
    if (truckIndex == -1) {
      state = state.addLogMessage('Truck not found');
      return;
    }

    final truck = state.trucks[truckIndex];

    // Check warehouse stock
    final warehouseStock = state.warehouse.inventory[product] ?? 0;
    if (warehouseStock < quantity) {
      state = state.addLogMessage(
        'Not enough ${product.name} in warehouse (have $warehouseStock, need $quantity)',
      );
      return;
    }

    // Check truck capacity
    final currentLoad = truck.currentLoad;
    if (currentLoad + quantity > truck.capacity) {
      final available = truck.capacity - currentLoad;
      state = state.addLogMessage(
        'Truck ${truck.name} is full! Only $available slots available',
      );
      return;
    }

    // Deduct from warehouse
    final updatedWarehouseInventory = Map<Product, int>.from(state.warehouse.inventory);
    final remainingWarehouseStock = warehouseStock - quantity;
    if (remainingWarehouseStock > 0) {
      updatedWarehouseInventory[product] = remainingWarehouseStock;
    } else {
      updatedWarehouseInventory.remove(product);
    }
    final newWarehouse = state.warehouse.copyWith(inventory: updatedWarehouseInventory);

    // Add to truck inventory
    final updatedTruckInventory = Map<Product, int>.from(truck.inventory);
    final currentTruckStock = updatedTruckInventory[product] ?? 0;
    updatedTruckInventory[product] = currentTruckStock + quantity;
    final updatedTruck = truck.copyWith(inventory: updatedTruckInventory);

    // Update state
    final updatedTrucks = [...state.trucks];
    updatedTrucks[truckIndex] = updatedTruck;

    state = state.copyWith(
      trucks: updatedTrucks,
      warehouse: newWarehouse,
    );
    state = state.addLogMessage(
      'Loaded $quantity ${product.name} onto ${truck.name}',
    );
    
    // Sync to simulation engine to prevent reversion on next tick
    simulationEngine.updateTrucks(updatedTrucks);
  }

  /// Get current machines list
  List<Machine> get machines => state.machines;

  /// Get current trucks list
  List<Truck> get trucks => state.trucks;

  /// Get warehouse inventory
  Warehouse get warehouse => state.warehouse;

  @override
  void dispose() {
    simulationEngine.dispose();
    super.dispose();
  }
}

/// Provider for GameController
// CHANGE TO StateNotifierProvider
// Note: Using Provider with StateNotifier for Riverpod 3.0 compatibility
final gameControllerProvider = Provider<GameController>((ref) {
  final controller = GameController(ref);
  ref.onDispose(() => controller.dispose());
  return controller;
});

/// Provider for the game state
final gameStateProvider = Provider<GlobalGameState>((ref) {
  final controller = ref.watch(gameControllerProvider);
  return controller.currentState;
});

/// Provider for machines list
// UPDATE Derived Providers to read from the state
final machinesProvider = Provider<List<Machine>>((ref) {
  final controller = ref.watch(gameControllerProvider);
  return controller.currentState.machines;
});

/// Provider for trucks list
/// Read directly from state
final trucksProvider = Provider<List<Truck>>((ref) {
  final controller = ref.watch(gameControllerProvider);
  return controller.currentState.trucks;
});

/// Provider for warehouse
/// Read directly from state
final warehouseProvider = Provider<Warehouse>((ref) {
  final controller = ref.watch(gameControllerProvider);
  return controller.currentState.warehouse;
});

