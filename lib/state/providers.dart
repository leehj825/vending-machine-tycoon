import 'dart:async';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateNotifierProvider, StateProvider;
import 'package:state_notifier/state_notifier.dart';
import 'package:uuid/uuid.dart';
import '../simulation/engine.dart';
import '../simulation/models/product.dart';
import '../simulation/models/zone.dart';
import '../simulation/models/machine.dart';
import '../simulation/models/truck.dart';
import 'game_state.dart';
import 'city_map_state.dart';

part 'providers.freezed.dart';

const _uuid = Uuid();

/// Machine prices by zone type
class MachinePrices {
  static const double basePrice = 400.0; // Reduced from 500.0
  static const Map<ZoneType, double> zoneMultipliers = {
    ZoneType.office: 1.75, // $700 (was $750)
    ZoneType.school: 1.5,  // $600 (was $600)
    ZoneType.gym: 1.25,    // $500 (was $500)
    ZoneType.shop: 1.0,    // $400 (was $400) - shop machines
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
          initialCash: 2000.0,
          initialReputation: 100,
        ),
        super(const GlobalGameState(
          cash: 2000.0, // Starting cash: $2000
          machines: [],
          trucks: [],
          warehouse: Warehouse(),
          warehouseRoadX: null, // Will be set when map is generated
          warehouseRoadY: null, // Will be set when map is generated
        )) {
    _setupSimulationListener();
  }

  /// Public getter to access current state
  GlobalGameState get currentState => state;

  StreamSubscription<SimulationState>? _simSubscription;

  /// Setup listener for simulation engine updates
  void _setupSimulationListener() {
    print('🟡 CONTROLLER: Setting up simulation listener...');
    
    _simSubscription = simulationEngine.stream.listen((SimulationState simState) {
      // Check if controller is still alive
      if (!mounted) return;
      
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
    _processMachinePurchase(zoneType, x, y, withStock: false);
  }

  /// Buy a new vending machine with automatic initial stocking
  void buyMachineWithStock(ZoneType zoneType, {required double x, required double y}) {
    _processMachinePurchase(zoneType, x, y, withStock: true);
  }

  /// Common logic for purchasing a machine (with or without stock)
  void _processMachinePurchase(ZoneType zoneType, double x, double y, {required bool withStock}) {
    print('🟢 CONTROLLER ACTION: Attempting to buy machine${withStock ? " with stock" : ""}...');
    final price = MachinePrices.getPrice(zoneType);
    
    if (state.cash < price) {
      state = state.addLogMessage('Insufficient funds');
      return;
    }

    // Create zone and building name
    final zone = _createZoneForType(zoneType, x: x, y: y);
    final buildingName = _getBuildingNameForZone(zoneType);
    
    // Create inventory (empty or with initial stock)
    Map<Product, InventoryItem> inventory = {};
    if (withStock) {
      final initialProducts = _getInitialProductsForZone(zoneType);
      final currentDay = simulationEngine.state.time.day;
      for (final product in initialProducts) {
        inventory[product] = InventoryItem(
          product: product,
          quantity: 20,
          dayAdded: currentDay,
        );
      }
    }
    
    // Create machine
    final newMachine = Machine(
      id: _uuid.v4(),
      name: '$buildingName Machine ${state.machines.length + 1}',
      zone: zone,
      condition: MachineCondition.excellent,
      inventory: inventory,
      currentCash: 0.0,
    );

    // Update simulation engine
    final updatedMachines = [...state.machines, newMachine];
    simulationEngine.updateMachines(updatedMachines);

    // Update state
    final newCash = state.cash - price;
    state = state.copyWith(
      cash: newCash,
      machines: updatedMachines,
    );
    
    // Create log message
    final logMsg = withStock 
        ? "Bought ${newMachine.name} (stocked)"
        : "Bought ${newMachine.name}";
    state = state.addLogMessage(logMsg);
    
    // Sync cash to simulation engine to prevent reversion on next tick
    simulationEngine.updateCash(newCash);
  }

  /// Get allowed products for a zone type
  List<Product> getAllowedProductsForZone(ZoneType zoneType) {
    switch (zoneType) {
      case ZoneType.shop:
        return [Product.soda, Product.chips];
      case ZoneType.school:
        return [Product.soda, Product.chips, Product.sandwich];
      case ZoneType.gym:
        return [Product.proteinBar, Product.soda, Product.chips];
      case ZoneType.office:
        return [Product.coffee, Product.techGadget];
    }
  }

  /// Get initial products for a zone type based on progression rules
  List<Product> _getInitialProductsForZone(ZoneType zoneType) {
    return getAllowedProductsForZone(zoneType);
  }

  /// Check if a product is allowed in a zone type
  bool isProductAllowedInZone(Product product, ZoneType zoneType) {
    return getAllowedProductsForZone(zoneType).contains(product);
  }

  /// Get building name for zone type (for machine naming)
  String _getBuildingNameForZone(ZoneType zoneType) {
    switch (zoneType) {
      case ZoneType.shop:
        return 'Shop';
      case ZoneType.school:
        return 'School';
      case ZoneType.gym:
        return 'Gym';
      case ZoneType.office:
        return 'Office';
    }
  }

  /// Create a zone based on zone type
  Zone _createZoneForType(ZoneType zoneType, {required double x, required double y}) {
    final id = _uuid.v4();
    final name = '${zoneType.name.toUpperCase()} Zone';

    switch (zoneType) {
      case ZoneType.shop:
        return ZoneFactory.createShop(id: id, name: name, x: x, y: y);
      case ZoneType.office:
        return ZoneFactory.createOffice(id: id, name: name, x: x, y: y);
      case ZoneType.school:
        return ZoneFactory.createSchool(id: id, name: name, x: x, y: y);
      case ZoneType.gym:
        return ZoneFactory.createGym(id: id, name: name, x: x, y: y);
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

  /// Start truck on route to stock machines (reset route index and start traveling)
  void goStock(String truckId) {
    // Find truck in list
    final truckIndex = state.trucks.indexWhere((t) => t.id == truckId);
    if (truckIndex == -1) {
      state = state.addLogMessage('Truck not found');
      return;
    }

    final truck = state.trucks[truckIndex];

    // Check if truck has items
    if (truck.inventory.isEmpty) {
      state = state.addLogMessage('${truck.name} has no items to stock');
      return;
    }

    // Check if truck has a route
    if (truck.route.isEmpty) {
      state = state.addLogMessage('${truck.name} has no route assigned');
      return;
    }

    // Reset route index to 0 and set status to traveling
    final updatedTruck = truck.copyWith(
      currentRouteIndex: 0,
      status: TruckStatus.traveling,
    );

    final updatedTrucks = [...state.trucks];
    updatedTrucks[truckIndex] = updatedTruck;

    // Update state
    state = state.copyWith(trucks: updatedTrucks);
    state = state.addLogMessage(
      '${truck.name} starting route to stock ${truck.route.length} machines',
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

  /// Buy a new truck
  void buyTruck() {
    print('🟢 CONTROLLER ACTION: Buying truck');
    const truckPrice = 500.0;
    
    if (state.cash < truckPrice) {
      state = state.addLogMessage('Insufficient funds to buy truck ($truckPrice)');
      return;
    }

    // Get warehouse road position from game state (set when map is generated)
    final warehouseRoadX = state.warehouseRoadX ?? 4.0; // Fallback to 4.0 if not set
    final warehouseRoadY = state.warehouseRoadY ?? 4.0; // Fallback to 4.0 if not set

    final truck = Truck(
      id: _uuid.v4(),
      name: 'Truck ${state.trucks.length + 1}',
      inventory: {},
      currentX: warehouseRoadX,
      currentY: warehouseRoadY,
      targetX: warehouseRoadX,
      targetY: warehouseRoadY,
    );

    // Update state
    final updatedTrucks = [...state.trucks, truck];
    final newCash = state.cash - truckPrice;
    
    state = state.copyWith(
      trucks: updatedTrucks,
      cash: newCash,
    );
    state = state.addLogMessage('Bought ${truck.name} for \$$truckPrice');
    
    // Sync to simulation engine
    simulationEngine.updateTrucks(updatedTrucks);
    simulationEngine.updateCash(newCash);
  }

  /// Get current machines list
  List<Machine> get machines => state.machines;

  /// Set warehouse road position (called when map is generated)
  void setWarehouseRoadPosition(double roadX, double roadY) {
    state = state.copyWith(
      warehouseRoadX: roadX,
      warehouseRoadY: roadY,
    );
    // Also update simulation engine so trucks can use it
    simulationEngine.updateWarehouseRoadPosition(roadX, roadY);
  }

  /// Get current trucks list
  List<Truck> get trucks => state.trucks;

  /// Get warehouse inventory
  Warehouse get warehouse => state.warehouse;

  /// Reset game to initial state (for new game)
  void resetGame() {
    print('🟢 CONTROLLER: Resetting game to initial state');
    
    // Stop simulation first
    stopSimulation();
    
    // Reset simulation engine
    simulationEngine.restoreState(
      time: const GameTime(day: 1, hour: 8, minute: 0, tick: 80),
      machines: [],
      trucks: [],
      cash: 2000.0,
      reputation: 100,
      warehouseRoadX: null,
      warehouseRoadY: null,
    );
    
    // Reset game state
    state = const GlobalGameState(
      cash: 2000.0,
      reputation: 100,
      dayCount: 1,
      hourOfDay: 8,
      machines: [],
      trucks: [],
      warehouse: Warehouse(),
      warehouseRoadX: null,
      warehouseRoadY: null,
      logMessages: [],
    );
    
    state = state.addLogMessage('New game started');
  }

  /// Load game state from saved data
  void loadGameState(GlobalGameState savedState) {
    print('🟢 CONTROLLER: Loading saved game state');
    
    // Calculate game time from day and hour
    final tick = (savedState.dayCount - 1) * SimulationConstants.ticksPerDay +
        (savedState.hourOfDay * SimulationConstants.ticksPerHour);
    final gameTime = GameTime.fromTicks(tick);
    
    // Restore simulation engine state
    simulationEngine.restoreState(
      time: gameTime,
      machines: savedState.machines,
      trucks: savedState.trucks,
      cash: savedState.cash,
      reputation: savedState.reputation,
      warehouseRoadX: savedState.warehouseRoadX,
      warehouseRoadY: savedState.warehouseRoadY,
    );
    
    // Restore game state
    state = savedState;
    
    state = state.addLogMessage('Game loaded successfully');
  }

  /// Update city map state
  void updateCityMapState(CityMapState? mapState) {
    // Directly update state - this works around freezed limitations
    // The state will be properly serialized when saving
    state = state.copyWith(cityMapState: mapState);
  }

  /// Retrieve cash from a machine
  void retrieveCash(String machineId) {
    // Find the machine
    final machineIndex = state.machines.indexWhere((m) => m.id == machineId);
    if (machineIndex == -1) {
      state = state.addLogMessage('Machine not found');
      return;
    }

    final machine = state.machines[machineIndex];
    final cashToRetrieve = machine.currentCash;

    if (cashToRetrieve <= 0) {
      state = state.addLogMessage('${machine.name} has no cash to retrieve');
      return;
    }

    // Update machine (set cash to 0)
    final updatedMachine = machine.copyWith(currentCash: 0.0);
    final updatedMachines = [...state.machines];
    updatedMachines[machineIndex] = updatedMachine;

    // Add cash to player's total
    final newCash = state.cash + cashToRetrieve;

    // Update state
    state = state.copyWith(
      machines: updatedMachines,
      cash: newCash,
    );
    state = state.addLogMessage(
      'Retrieved \$${cashToRetrieve.toStringAsFixed(2)} from ${machine.name}',
    );

    // Sync to simulation engine
    simulationEngine.updateMachines(updatedMachines);
    simulationEngine.updateCash(newCash);
  }

  @override
  void dispose() {
    // Cancel the stream subscription to prevent updates after disposal
    _simSubscription?.cancel();
    _simSubscription = null;
    
    // Stop the simulation engine
    simulationEngine.stop();
    
    // Call super.dispose() - StateNotifier requires this
    super.dispose();
  }
}

/// Provider for GameController
final gameControllerProvider =
    StateNotifierProvider<GameController, GlobalGameState>((ref) {
  return GameController(ref);
});

/// Provider for the game state
final gameStateProvider = Provider<GlobalGameState>((ref) {
  return ref.watch(gameControllerProvider);
});

/// Provider for machines list
final machinesProvider = Provider<List<Machine>>((ref) {
  return ref.watch(gameControllerProvider).machines;
});

/// Provider for trucks list
final trucksProvider = Provider<List<Truck>>((ref) {
  return ref.watch(gameControllerProvider).trucks;
});

/// Provider for warehouse
final warehouseProvider = Provider<Warehouse>((ref) {
  return ref.watch(gameControllerProvider).warehouse;
});

/// Provider for selected machine ID on the map
final selectedMachineIdProvider = StateProvider<String?>((ref) => null);

