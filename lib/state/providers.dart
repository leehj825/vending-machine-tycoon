import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    // Listen to simulation engine state changes
    _setupSimulationListener();
  }

  /// Public getter to access current state
  GlobalGameState get currentState => state;

  /// Setup listener for simulation engine updates
  void _setupSimulationListener() {
    // Note: In a real implementation, you'd use a stream or callback
    // For now, we'll update manually through methods
    // The simulation engine will update its state, and we sync periodically
  }

  /// Check if simulation is running
  bool get isSimulationRunning => _isSimulationRunning;

  /// Start the simulation
  void startSimulation() {
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
    final price = MachinePrices.getPrice(zoneType);
    
    if (state.cash < price) {
      state = state.addLogMessage('Insufficient funds to buy machine');
      return;
    }

    // Create zone based on type
    final zone = _createZoneForType(zoneType, x: x, y: y);
    
    // Create machine
    final machine = Machine(
      id: _uuid.v4(),
      name: '${zoneType.name.toUpperCase()} Machine ${state.machines.length + 1}',
      zone: zone,
      condition: MachineCondition.excellent,
      inventory: {},
      currentCash: 0.0,
    );

    // Update simulation engine
    final updatedMachines = [...state.machines, machine];
    _updateSimulationMachines(updatedMachines);

    // Deduct cash and update state
    final newCash = state.cash - price;
    state = state.copyWith(
      machines: updatedMachines,
      cash: newCash,
    );
    state = state.addLogMessage(
      'Purchased ${machine.name} for \$${price.toStringAsFixed(2)}',
    );
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

  /// Update machines in simulation engine
  void _updateSimulationMachines(List<Machine> machines) {
    // Note: SimulationEngine doesn't have a direct setter for machines
    // In a full implementation, you'd need to add a method to update machines
    // For now, we'll track them locally and sync periodically
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
    
    // Update the STATE object completely
    state = state.copyWith(
      cash: state.cash - totalPrice,
      warehouse: state.warehouse.copyWith(inventory: newInventory),
    );
    state = state.addLogMessage("Bought $quantity ${product.name}");
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

    // Update simulation engine trucks
    _updateSimulationTrucks(updatedTrucks);

    // Update state
    state = state.copyWith(trucks: updatedTrucks);
    state = state.addLogMessage(
      'Assigned route with ${machineIds.length} stops to ${truck.name}',
    );
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

    // Update simulation engine trucks
    _updateSimulationTrucks(updatedTrucks);

    // Update state
    state = state.copyWith(trucks: updatedTrucks);
    state = state.addLogMessage(
      'Updated route for ${truck.name}: ${machineIds.length} stops',
    );
  }

  /// Update trucks in simulation engine
  void _updateSimulationTrucks(List<Truck> trucks) {
    // Similar to machines, would need simulation engine method to update
  }

  /// Get current machines list
  List<Machine> get machines => state.machines;

  /// Get current trucks list
  List<Truck> get trucks => state.trucks;

  /// Get warehouse inventory
  Warehouse get warehouse => state.warehouse;

  /// Restock a machine from truck inventory
  /// Finds a truck at the machine and transfers items from truck to machine
  void restockMachine(String machineId, Map<Product, int> productsToAdd) {
    final machineIndex = state.machines.indexWhere((m) => m.id == machineId);
    if (machineIndex == -1) {
      state = state.addLogMessage('Machine not found');
      return;
    }

    final machine = state.machines[machineIndex];
    
    // Find a truck that's at this machine (restocking or nearby)
    Truck? truckAtMachine;
    int truckIndex = -1;
    
    for (int i = 0; i < state.trucks.length; i++) {
      final truck = state.trucks[i];
      final dx = machine.zone.x - truck.currentX;
      final dy = machine.zone.y - truck.currentY;
      final distance = (dx * dx + dy * dy) * 0.5;
      
      // Check if truck is at machine (within 0.1 units) or is restocking this machine
      if (distance < 0.1 || 
          (truck.status == TruckStatus.restocking && truck.currentDestination == machineId)) {
        truckAtMachine = truck;
        truckIndex = i;
        break;
      }
    }

    if (truckAtMachine == null || truckIndex == -1) {
      state = state.addLogMessage(
        'No truck available at ${machine.name}. Trucks must be at the machine to restock.',
      );
      return;
    }

    final currentDay = state.dayCount;
    var updatedInventory = Map<Product, InventoryItem>.from(machine.inventory);
    var updatedTruckInventory = Map<Product, int>.from(truckAtMachine.inventory);

    // Check truck inventory and transfer
    for (final entry in productsToAdd.entries) {
      final product = entry.key;
      final quantity = entry.value;
      final truckStock = updatedTruckInventory[product] ?? 0;

      if (truckStock < quantity) {
        state = state.addLogMessage(
          'Not enough ${product.name} in truck inventory (have $truckStock, need $quantity)',
        );
        continue;
      }

      // Remove from truck inventory
      final remaining = truckStock - quantity;
      if (remaining > 0) {
        updatedTruckInventory[product] = remaining;
      } else {
        updatedTruckInventory.remove(product);
      }

      // Add to machine inventory
      final existingItem = updatedInventory[product];
      if (existingItem != null) {
        updatedInventory[product] = existingItem.copyWith(
          quantity: existingItem.quantity + quantity,
        );
      } else {
        updatedInventory[product] = InventoryItem(
          product: product,
          quantity: quantity,
          dayAdded: currentDay,
        );
      }
    }

    // Update truck
    final updatedTruck = truckAtMachine.copyWith(inventory: updatedTruckInventory);
    final updatedTrucks = [...state.trucks];
    updatedTrucks[truckIndex] = updatedTruck;

    // Update machine
    final updatedMachine = machine.copyWith(
      inventory: updatedInventory,
      hoursSinceRestock: 0.0,
    );

    final updatedMachines = [...state.machines];
    updatedMachines[machineIndex] = updatedMachine;
    _updateSimulationMachines(updatedMachines);

    // Update state
    state = state.copyWith(
      machines: updatedMachines,
      trucks: updatedTrucks,
    );
    state = state.addLogMessage('Restocked ${machine.name} from ${truckAtMachine.name}');
  }

  /// Process a simulation tick - syncs with engine and updates state
  void tick() {
    if (!_isSimulationRunning) return;

    // Call engine tick with current state
    final result = simulationEngine.tick(state.machines, state.trucks);
    
    // Update state with engine results
    state = state.copyWith(
      machines: result.machines,
      trucks: result.trucks,
    );
  }

  @override
  void dispose() {
    simulationEngine.dispose();
    super.dispose();
  }
}

/// Provider for GameController
// Note: Using a custom provider since StateNotifierProvider is in legacy
// This creates a provider that manages the GameController lifecycle
final gameControllerProvider = Provider<GameController>((ref) {
  final controller = GameController(ref);
  ref.onDispose(() => controller.dispose());
  return controller;
});

/// Provider for the game state
/// Note: GameController extends StateNotifier, so we expose state through a getter
final gameStateProvider = Provider<GlobalGameState>((ref) {
  final controller = ref.watch(gameControllerProvider);
  // Access state through a public getter since StateNotifier.state is protected
  return controller.currentState;
});

/// Provider for machines list
final machinesProvider = Provider<List<Machine>>((ref) {
  final controller = ref.watch(gameControllerProvider);
  return controller.machines;
});

/// Provider for trucks list
final trucksProvider = Provider<List<Truck>>((ref) {
  final controller = ref.watch(gameControllerProvider);
  return controller.trucks;
});

/// Provider for warehouse
final warehouseProvider = Provider<Warehouse>((ref) {
  final controller = ref.watch(gameControllerProvider);
  return controller.warehouse;
});

