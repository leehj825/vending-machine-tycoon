import 'dart:async';
import 'dart:math' as math;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateNotifierProvider, StateProvider;
import 'package:state_notifier/state_notifier.dart';
import 'package:uuid/uuid.dart';
import '../config.dart';
import '../simulation/engine.dart';
import '../simulation/models/product.dart';
import '../simulation/models/zone.dart';
import '../simulation/models/machine.dart';
import '../simulation/models/truck.dart';
import '../services/rewarded_ad_manager.dart';
import 'game_state.dart';
import 'city_map_state.dart';

part 'providers.freezed.dart';

const _uuid = Uuid();

/// Machine prices by zone type
class MachinePrices {
  static const double basePrice = AppConfig.machineBasePrice;
  static const Map<ZoneType, double> zoneMultipliers = {
    ZoneType.office: 2.5,  // $1000
    ZoneType.school: 1.5,  // $600
    ZoneType.gym: 2.0,     // $800
    ZoneType.shop: 1.0,    // $400 - shop machines
    ZoneType.subway: 2.2,  // $880
    ZoneType.hospital: 2.8, // $1120
    ZoneType.university: 2.3, // $920
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
  Timer? _marketingButtonSpawnTimer;
  
  // Debug output throttling - only print once per second
  DateTime? _lastDebugPrint;

  GameController(this.ref)
      : simulationEngine = SimulationEngine(
          initialMachines: [],
          initialTrucks: [],
          initialCash: 2000.0,
          initialReputation: 100,
          initialWarehouse: const Warehouse(),
        ),
        super(const GlobalGameState(
          cash: 2000.0, // Starting cash: $2000
          machines: [],
          trucks: [],
          warehouse: Warehouse(),
          warehouseRoadX: null, // Will be set when map is generated
          warehouseRoadY: null, // Will be set when map is generated
          dailyRevenueHistory: [],
          currentDayRevenue: 0.0,
          productSalesCount: {},
        )) {
    _setupSimulationListener();
    // Spawn marketing button at initial random location
    _spawnMarketingButton();
  }
  
  /// Spawn marketing button at random road tile on the city map
  void _spawnMarketingButton() {
    final random = math.Random();
    final cityMapState = state.cityMapState;
    
    if (cityMapState == null || cityMapState.grid.isEmpty) {
      // Fallback to random position if map not loaded yet
      final buttonGridX = random.nextInt(10);
      final buttonGridY = random.nextInt(10);
      print('🟢 CONTROLLER: Spawning marketing button at random grid ($buttonGridX, $buttonGridY) - map not loaded');
      state = state.copyWith(
        marketingButtonGridX: buttonGridX,
        marketingButtonGridY: buttonGridY,
      );
      return;
    }
    
    // Find all road tiles
    final roadTiles = <({int x, int y})>[];
    for (int y = 0; y < cityMapState.grid.length; y++) {
      for (int x = 0; x < cityMapState.grid[y].length; x++) {
        if (cityMapState.grid[y][x] == 'road') {
          roadTiles.add((x: x, y: y));
        }
      }
    }
    
    if (roadTiles.isEmpty) {
      // Fallback if no roads found
      final buttonGridX = random.nextInt(10);
      final buttonGridY = random.nextInt(10);
      print('🟢 CONTROLLER: No road tiles found, spawning at random grid ($buttonGridX, $buttonGridY)');
      state = state.copyWith(
        marketingButtonGridX: buttonGridX,
        marketingButtonGridY: buttonGridY,
      );
      return;
    }
    
    // Get positions to exclude (buildings with purchase buttons and machines)
    final excludedPositions = <String>{};
    
    // 1. Exclude building positions that have purchase buttons
    // Purchase buttons appear on buildings where there's no machine yet
    for (int y = 0; y < cityMapState.grid.length; y++) {
      for (int x = 0; x < cityMapState.grid[y].length; x++) {
        final tileType = cityMapState.grid[y][x];
        // Check if it's a building type that can have purchase buttons
        if (tileType == 'shop' || tileType == 'school' || tileType == 'gym' || tileType == 'office') {
          final zoneX = (x + 1).toDouble() + 0.5;
          final zoneY = (y + 1).toDouble() + 0.5;
          
          // Check if there's already a machine at this position
          final hasMachine = state.machines.any(
            (m) => (m.zone.x - zoneX).abs() < 0.1 && (m.zone.y - zoneY).abs() < 0.1,
          );
          
          // If no machine, there will be a purchase button - exclude this position
          if (!hasMachine) {
            excludedPositions.add('$x,$y');
          }
        }
      }
    }
    
    // 2. Exclude machine positions (machines have magnifier buttons)
    for (final machine in state.machines) {
      // Convert zone coordinates to grid coordinates
      // zoneX = (gridX + 1) + 0.5, so gridX = zoneX - 1.5
      final gridX = (machine.zone.x - 1.5).round();
      final gridY = (machine.zone.y - 1.5).round();
      // Exclude the tile and adjacent tiles (to avoid overlap)
      for (int dx = -1; dx <= 1; dx++) {
        for (int dy = -1; dy <= 1; dy++) {
          final checkX = gridX + dx;
          final checkY = gridY + dy;
          if (checkX >= 0 && checkX < 10 && checkY >= 0 && checkY < 10) {
            excludedPositions.add('$checkX,$checkY');
          }
        }
      }
    }
    
    // Filter out excluded positions from road tiles
    final availableRoadTiles = roadTiles.where((road) {
      return !excludedPositions.contains('${road.x},${road.y}');
    }).toList();
    
    if (availableRoadTiles.isEmpty) {
      // If all roads are excluded, fall back to any road (better than nothing)
      print('🟢 CONTROLLER: All road tiles excluded, using any road tile');
      final selectedRoad = roadTiles[random.nextInt(roadTiles.length)];
      state = state.copyWith(
        marketingButtonGridX: selectedRoad.x,
        marketingButtonGridY: selectedRoad.y,
      );
      return;
    }
    
    // Pick a random road tile from available ones
    final selectedRoad = availableRoadTiles[random.nextInt(availableRoadTiles.length)];
    print('🟢 CONTROLLER: Spawning marketing button at road tile ($selectedRoad.x, $selectedRoad.y)');
    
    state = state.copyWith(
      marketingButtonGridX: selectedRoad.x,
      marketingButtonGridY: selectedRoad.y,
    );
  }
  
  /// Public method to spawn marketing button (called from UI)
  void spawnMarketingButton() {
    _spawnMarketingButton();
  }

  /// Hide marketing button (called when auto-hide timer expires)
  void hideMarketingButton() {
    state = state.copyWith(
      marketingButtonGridX: null,
      marketingButtonGridY: null,
    );
    
    // After hiding, schedule next appearance after 10-30 seconds
    _marketingButtonSpawnTimer?.cancel();
    final random = math.Random();
    final delaySeconds = 10 + random.nextInt(21); // 10-30 seconds
    _marketingButtonSpawnTimer = Timer(Duration(seconds: delaySeconds), () {
      _spawnMarketingButton();
    });
  }

  /// Public getter to access current state
  GlobalGameState get currentState => state;

  StreamSubscription<SimulationState>? _simSubscription;

  /// Setup listener for simulation engine updates
  void _setupSimulationListener() {
    print('🟡 CONTROLLER: Setting up simulation listener...');
    
    _simSubscription = simulationEngine.stream.listen((SimulationState simState) {
      if (!mounted) return;
      
      final now = DateTime.now();
      if (_lastDebugPrint == null || now.difference(_lastDebugPrint!).inSeconds >= 1) {
        print('🟡 CONTROLLER SYNC: Received update. Cash: \$${simState.cash.toStringAsFixed(2)}, Machines: ${simState.machines.length}');
        _lastDebugPrint = now;
      }
      
      var updatedTrucks = simState.trucks.map((simTruck) {
        final localTruck = state.trucks.firstWhere(
          (t) => t.id == simTruck.id,
          orElse: () => simTruck,
        );
        if (localTruck.pendingRoute.isNotEmpty) {
          return simTruck.copyWith(pendingRoute: localTruck.pendingRoute);
        }
        
        return simTruck;
      }).toList();
      
      final previousHour = state.hourOfDay;
      final previousDay = state.dayCount;
      final previousTotalCash = state.cash + state.machines.fold<double>(0.0, (sum, m) => sum + m.currentCash);
      
      final currentTotalCash = simState.cash + simState.machines.fold<double>(0.0, (sum, m) => sum + m.currentCash);
      final revenueThisTick = (currentTotalCash - previousTotalCash).clamp(0.0, double.infinity);
      
      final updatedProductSales = Map<Product, int>.from(state.productSalesCount);
      for (final machine in simState.machines) {
        final oldMachine = state.machines.firstWhere(
          (m) => m.id == machine.id,
          orElse: () => machine,
        );
        final salesIncrease = machine.totalSales - oldMachine.totalSales;
        if (salesIncrease > 0) {
          // Distribute sales increase across products in inventory (rough estimate)
          final totalInventory = machine.inventory.values.fold<int>(0, (sum, item) => sum + item.quantity);
          if (totalInventory > 0) {
            for (final entry in machine.inventory.entries) {
              final product = entry.key;
              final quantity = entry.value.quantity;
              final estimatedSales = ((salesIncrease * quantity) / totalInventory).round();
              updatedProductSales[product] = (updatedProductSales[product] ?? 0) + estimatedSales;
            }
          }
        }
      }
      
      // Detect day rollover (hour 23 -> 0 or day changed)
      var updatedDailyRevenueHistory = List<double>.from(state.dailyRevenueHistory);
      var updatedCurrentDayRevenue = state.currentDayRevenue + revenueThisTick;
      
      if (simState.time.day > previousDay || (previousHour == 23 && simState.time.hour == 0)) {
        // Day rolled over - save previous day's revenue
        if (previousDay > 0) {
          updatedDailyRevenueHistory.add(updatedCurrentDayRevenue);
          // Keep only last 7 days
          if (updatedDailyRevenueHistory.length > 7) {
            updatedDailyRevenueHistory = updatedDailyRevenueHistory.sublist(updatedDailyRevenueHistory.length - 7);
          }
        }
        // Reset current day revenue
        updatedCurrentDayRevenue = revenueThisTick;
      }
      
      // Process pending messages from engine (e.g., auto-restock errors)
      final pendingMessages = simulationEngine.getAndClearPendingMessages();
      for (final message in pendingMessages) {
        state = state.addLogMessage(message);
      }

      // Check for game over condition: cash too negative (less than -$1000)
      final isGameOver = simState.cash < -1000.0 && !state.isGameOver;
      
      state = state.copyWith(
        machines: simState.machines,
        trucks: updatedTrucks,
        cash: simState.cash,
        reputation: simState.reputation,
        dayCount: simState.time.day,
        hourOfDay: simState.time.hour,
        dailyRevenueHistory: updatedDailyRevenueHistory,
        currentDayRevenue: updatedCurrentDayRevenue,
        productSalesCount: updatedProductSales,
        warehouse: simState.warehouse, // Sync warehouse from engine (for auto-restock)
        isGameOver: isGameOver || state.isGameOver, // Set game over flag if cash is too negative
        // Logs are managed locally by Controller, so we don't overwrite them
      );
      
      // Log game over message
      if (isGameOver) {
        state = state.addLogMessage('💀 GAME OVER: Your business went bankrupt!');
      }
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

    // Update simulation engine (use addMachine to append, not overwrite)
    simulationEngine.addMachine(newMachine);

    // Update state
    final newCash = state.cash - price;
    state = state.copyWith(
      cash: newCash,
      machines: [...state.machines, newMachine],
    );
    
    // Create log message
    final logMsg = withStock 
        ? "Bought ${newMachine.name} (stocked)"
        : "Bought ${newMachine.name}";
    state = state.addLogMessage(logMsg);
    
    // Sync cash to simulation engine to prevent reversion on next tick
    simulationEngine.updateCash(newCash);
  }

  /// Get allowed products for a zone type (delegates to Zone.getAllowedProducts)
  List<Product> getAllowedProductsForZone(ZoneType zoneType) {
    return Zone.getAllowedProducts(zoneType);
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
      case ZoneType.subway:
        return 'Subway';
      case ZoneType.hospital:
        return 'Hospital';
      case ZoneType.university:
        return 'University';
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
      case ZoneType.subway:
        return ZoneFactory.createSubway(id: id, name: name, x: x, y: y);
      case ZoneType.hospital:
        return ZoneFactory.createHospital(id: id, name: name, x: x, y: y);
      case ZoneType.university:
        return ZoneFactory.createUniversity(id: id, name: name, x: x, y: y);
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
    final newWarehouse = state.warehouse.copyWith(inventory: newInventory);
    state = state.copyWith(
      cash: state.cash - totalPrice,
      warehouse: newWarehouse,
    );
    state = state.addLogMessage("Bought $quantity ${product.name}");
    
    // Sync cash and warehouse to simulation engine to prevent reversion on next tick
    simulationEngine.updateCash(newCashAmount);
    simulationEngine.updateWarehouse(newWarehouse);
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

    // If truck is currently moving (traveling or restocking), save route to pendingRoute
    // The route will be applied when the truck finishes and becomes idle
    if (truck.status != TruckStatus.idle) {
      final updatedTruck = truck.copyWith(
        pendingRoute: machineIds, // Save new route as pending
      );

      final updatedTrucks = [...state.trucks];
      updatedTrucks[truckIndex] = updatedTruck;

      state = state.copyWith(trucks: updatedTrucks);
      state = state.addLogMessage(
        'Route updated for ${truck.name} (will apply when truck finishes current route): ${machineIds.length} stops',
      );
      
      // Sync to simulation engine to prevent reversion on next tick
      simulationEngine.updateTrucks(updatedTrucks);
      return;
    }

    // Truck is idle - apply route changes immediately
    final updatedTruck = truck.copyWith(
      route: machineIds,
      pendingRoute: [], // Clear any pending route
      currentRouteIndex: 0, // Reset to start of route
      status: TruckStatus.idle, // Keep idle - truck only moves when "Go Stock" is pressed
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

    // Check if truck is idle (can't start if already moving)
    if (truck.status != TruckStatus.idle) {
      state = state.addLogMessage('${truck.name} is already on a route');
      return;
    }

    // Apply pending route if it exists (route was updated while truck was moving)
    final routeToUse = truck.pendingRoute.isNotEmpty ? truck.pendingRoute : truck.route;

    // Check if truck has items
    if (truck.inventory.isEmpty) {
      state = state.addLogMessage('${truck.name} has no items to stock');
      return;
    }

    // Check if truck has a route
    if (routeToUse.isEmpty) {
      state = state.addLogMessage('${truck.name} has no route assigned');
      return;
    }

    // Apply pending route and reset route index to 0, then set status to traveling
    final updatedTruck = truck.copyWith(
      route: routeToUse, // Apply pending route if it exists
      pendingRoute: [], // Clear pending route
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
    simulationEngine.updateWarehouse(newWarehouse);
  }

  /// Get the current truck price based on number of trucks owned
  /// Price increases by 500 for each truck already owned
  double getTruckPrice() {
    const basePrice = AppConfig.truckPrice;
    const priceIncrement = 500.0;
    return basePrice + (state.trucks.length * priceIncrement);
  }

  /// Buy a new truck
  void buyTruck() {
    print('🟢 CONTROLLER ACTION: Buying truck');
    final truckPrice = getTruckPrice();
    
    if (state.cash < truckPrice) {
      state = state.addLogMessage('Insufficient funds to buy truck (${truckPrice.toInt()})');
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
    state = state.addLogMessage('Bought ${truck.name} for \$${truckPrice.toInt()}');
    
    // Sync to simulation engine
    simulationEngine.updateTrucks(updatedTrucks);
    simulationEngine.updateCash(newCash);
    
    // Auto-assign drivers to new truck if available
    _autoAssignDrivers();
  }

  /// Hire a driver to the driver pool (HQ Staff Management)
  void hireDriver() {
    state = state.copyWith(driverPoolCount: state.driverPoolCount + 1);
    state = state.addLogMessage('Hired a driver to the pool (Auto-assignment enabled)');
    
    // Auto-assign drivers to empty trucks
    _autoAssignDrivers();
  }

  /// Fire a driver from the driver pool (HQ Staff Management)
  void fireDriver() {
    // Calculate total drivers (pool + assigned)
    final assignedDrivers = state.trucks.where((t) => t.hasDriver).length;
    final totalDrivers = state.driverPoolCount + assignedDrivers;
    
    if (totalDrivers <= 0) {
      state = state.addLogMessage('No drivers to fire');
      return;
    }

    // Priority: Fire from pool first, only unassign from trucks if pool is empty
    if (state.driverPoolCount > 0) {
      // Fire from pool
      final newDriverPoolCount = state.driverPoolCount - 1;
      state = state.copyWith(driverPoolCount: newDriverPoolCount);
      state = state.addLogMessage('Fired a driver from the pool');
    } else {
      // Pool is empty, unassign a driver from a truck
      final trucksWithDrivers = state.trucks.where((t) => t.hasDriver).toList();
      if (trucksWithDrivers.isNotEmpty) {
        // Unassign driver from first truck with driver
        final truckToUnassign = trucksWithDrivers.first;
        final truckIndex = state.trucks.indexWhere((t) => t.id == truckToUnassign.id);
        if (truckIndex != -1) {
          final updatedTrucks = [...state.trucks];
          updatedTrucks[truckIndex] = truckToUnassign.copyWith(hasDriver: false);
          state = state.copyWith(trucks: updatedTrucks);
          simulationEngine.updateTrucks(updatedTrucks);
          state = state.addLogMessage('Fired a driver (unassigned from ${truckToUnassign.name})');
        }
      }
    }
  }

  /// Auto-assign idle drivers to empty trucks
  void _autoAssignDrivers() {
    final idleDrivers = state.driverPoolCount;
    final emptyTrucks = state.trucks.where((t) => !t.hasDriver).toList();
    
    if (idleDrivers <= 0 || emptyTrucks.isEmpty) {
      return; // No drivers or trucks to assign
    }

    final updatedTrucks = [...state.trucks];
    int driversAssigned = 0;
    int driversRemaining = idleDrivers;

    // Assign drivers to empty trucks
    for (final truck in emptyTrucks) {
      if (driversRemaining <= 0) break;
      
      final truckIndex = updatedTrucks.indexWhere((t) => t.id == truck.id);
      if (truckIndex != -1) {
        updatedTrucks[truckIndex] = truck.copyWith(hasDriver: true);
        driversAssigned++;
        driversRemaining--;
      }
    }

    // Update driver pool count (reduce by number assigned)
    state = state.copyWith(
      trucks: updatedTrucks,
      driverPoolCount: driversRemaining,
    );

    if (driversAssigned > 0) {
      state = state.addLogMessage('Auto-assigned $driversAssigned driver(s) to trucks');
    }

    // Sync to simulation engine
    simulationEngine.updateTrucks(updatedTrucks);
  }

  /// Hire a mechanic (HQ Staff Management)
  void hireMechanic() {
    state = state.copyWith(mechanicCount: state.mechanicCount + 1);
    state = state.addLogMessage('Hired a mechanic (Auto-repairs enabled)');
    simulationEngine.updateStaffCounts(
      mechanicCount: state.mechanicCount,
      purchasingAgentTargetInventory: state.purchasingAgentTargetInventory,
    );
  }

  /// Fire a mechanic (HQ Staff Management)
  void fireMechanic() {
    if (state.mechanicCount <= 0) {
      state = state.addLogMessage('No mechanics to fire');
      return;
    }
    state = state.copyWith(mechanicCount: state.mechanicCount - 1);
    state = state.addLogMessage('Fired a mechanic');
    simulationEngine.updateStaffCounts(
      mechanicCount: state.mechanicCount,
      purchasingAgentTargetInventory: state.purchasingAgentTargetInventory,
    );
  }

  /// Hire a purchasing agent (HQ Staff Management)
  void hirePurchasingAgent() {
    state = state.copyWith(purchasingAgentCount: state.purchasingAgentCount + 1);
    state = state.addLogMessage('Hired a purchasing agent (Auto-buy stock enabled)');
    simulationEngine.updateStaffCounts(
      purchasingAgentCount: state.purchasingAgentCount,
      purchasingAgentTargetInventory: state.purchasingAgentTargetInventory,
    );
  }

  /// Fire a purchasing agent (HQ Staff Management)
  void firePurchasingAgent() {
    if (state.purchasingAgentCount <= 0) {
      state = state.addLogMessage('No purchasing agents to fire');
      return;
    }
    state = state.copyWith(purchasingAgentCount: state.purchasingAgentCount - 1);
    state = state.addLogMessage('Fired a purchasing agent');
    simulationEngine.updateStaffCounts(
      purchasingAgentCount: state.purchasingAgentCount,
      purchasingAgentTargetInventory: state.purchasingAgentTargetInventory,
    );
  }

  /// Set target inventory for a product (Purchasing Agent settings)
  void setPurchasingAgentTarget(Product product, int target) {
    final updatedTargets = Map<Product, int>.from(state.purchasingAgentTargetInventory);
    updatedTargets[product] = target;
    state = state.copyWith(purchasingAgentTargetInventory: updatedTargets);
    state = state.addLogMessage('Set ${product.name} target inventory to $target');
    
    // Sync to simulation engine
    simulationEngine.updateStaffCounts(
      purchasingAgentTargetInventory: updatedTargets,
    );
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
      rushMultiplier: 1.0,
      warehouse: const Warehouse(),
      mechanicCount: 0,
      purchasingAgentCount: 0,
      purchasingAgentTargetInventory: {},
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
      dailyRevenueHistory: [],
      currentDayRevenue: 0.0,
      productSalesCount: {},
      hypeLevel: 0.0,
      isRushHour: false,
      rushMultiplier: 1.0,
      marketingButtonGridX: null,
      isGameOver: false,
      marketingButtonGridY: null,
    );
    
    // Reset rush multiplier in simulation engine
    simulationEngine.updateRushMultiplier(1.0);
    
    // Reset tutorial flags for new game (in state)
    state = state.copyWith(
      hasSeenPedestrianTapTutorial: false,
      hasSeenBuyTruckTutorial: false,
      hasSeenTruckTutorial: false,
      hasSeenGoStockTutorial: false,
      hasSeenMarketTutorial: false,
      hasSeenMoneyExtractionTutorial: false,
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
      rushMultiplier: savedState.rushMultiplier,
      warehouse: savedState.warehouse,
      mechanicCount: savedState.mechanicCount,
      purchasingAgentCount: savedState.purchasingAgentCount,
      purchasingAgentTargetInventory: savedState.purchasingAgentTargetInventory,
    );
    
    // Restore game state
    state = savedState;
    
    // Sync staff counts to simulation engine (including driver pool)
    simulationEngine.updateStaffCounts(
      mechanicCount: state.mechanicCount,
      purchasingAgentCount: state.purchasingAgentCount,
      purchasingAgentTargetInventory: state.purchasingAgentTargetInventory,
    );
    
    // Auto-assign drivers to trucks after loading (if there are idle drivers and empty trucks)
    _autoAssignDrivers();
    
    // If marketing button position is not set and not in rush hour, spawn it
    if ((state.marketingButtonGridX == null || state.marketingButtonGridY == null) && !state.isRushHour) {
      _spawnMarketingButton();
    }
    
    state = state.addLogMessage('Game loaded successfully');
  }

  /// Update city map state
  void updateCityMapState(CityMapState? mapState) {
    // Directly update state - this works around freezed limitations
    // The state will be properly serialized when saving
    state = state.copyWith(cityMapState: mapState);
    
    // Extract road tiles from map and update simulation engine pathfinding
    if (mapState != null) {
      final roadTiles = <({double x, double y})>[];
      for (int y = 0; y < mapState.grid.length; y++) {
        for (int x = 0; x < mapState.grid[y].length; x++) {
          if (mapState.grid[y][x] == 'road') {
            // Convert grid coordinates to zone coordinates (grid + 1)
            roadTiles.add((x: (x + 1).toDouble(), y: (y + 1).toDouble()));
          }
        }
      }
      simulationEngine.setMapLayout(roadTiles);
    }
  }

  /// Update a single machine (used for maintenance status, cash collection, etc.)
  void updateMachine(Machine updatedMachine) {
    final machineIndex = state.machines.indexWhere((m) => m.id == updatedMachine.id);
    if (machineIndex == -1) {
      state = state.addLogMessage('Machine not found');
      return;
    }

    final updatedMachines = [...state.machines];
    updatedMachines[machineIndex] = updatedMachine;

    // Update state
    state = state.copyWith(machines: updatedMachines);

    // Sync to simulation engine (use updateMachine for atomic update)
    simulationEngine.updateMachine(updatedMachine);
  }

  /// Update machine inventory item allocation
  void updateMachineAllocation(String machineId, Product product, int newAllocation) {
    final machineIndex = state.machines.indexWhere((m) => m.id == machineId);
    if (machineIndex == -1) {
      state = state.addLogMessage('Machine not found');
      return;
    }

    final machine = state.machines[machineIndex];
    final currentItem = machine.inventory[product];
    
    // Calculate new total allocation
    final currentTotalAllocation = machine.totalAllocation;
    final currentItemAllocation = currentItem?.allocation ?? 0;
    final newTotalAllocation = currentTotalAllocation - currentItemAllocation + newAllocation;
    
    // Check if new allocation exceeds max capacity
    if (newTotalAllocation > machine.maxCapacity) {
      state = state.addLogMessage('Cannot exceed machine capacity of ${machine.maxCapacity} items');
      return;
    }

    // Update or create inventory item
    final updatedInventory = Map<Product, InventoryItem>.from(machine.inventory);
    if (currentItem != null) {
      updatedInventory[product] = currentItem.copyWith(allocation: newAllocation);
    } else {
      // Create new item with 0 quantity and specified allocation
      updatedInventory[product] = InventoryItem(
        product: product,
        quantity: 0,
        dayAdded: simulationEngine.state.time.day,
        allocation: newAllocation,
      );
    }

    final updatedMachine = machine.copyWith(inventory: updatedInventory);
    updateMachine(updatedMachine);
  }

  /// Update player cash
  void updateCash(double newCash) {
    state = state.copyWith(cash: newCash);
    simulationEngine.updateCash(newCash);
  }

  /// Add cash to player (e.g., from rewarded ads)
  void addCash(double amount) {
    final newCash = state.cash + amount;
    state = state.copyWith(cash: newCash);
    simulationEngine.updateCash(newCash);
    state = state.addLogMessage('Received \$${amount.toStringAsFixed(0)} from investors');
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

    // Sync to simulation engine (use updateMachine for atomic update)
    simulationEngine.updateMachine(updatedMachine);
    simulationEngine.updateCash(newCash);
  }

  /// Repair a broken machine
  void repairMachine(String machineId) {
    const repairCost = 150.0;
    
    // Find the machine
    final machineIndex = state.machines.indexWhere((m) => m.id == machineId);
    if (machineIndex == -1) {
      state = state.addLogMessage('Machine not found');
      return;
    }

    final machine = state.machines[machineIndex];
    
    // Check if machine is actually broken
    if (!machine.isBroken) {
      state = state.addLogMessage('${machine.name} is not broken');
      return;
    }
    
    // Check if player has enough cash
    if (state.cash < repairCost) {
      state = state.addLogMessage('Insufficient funds to repair ${machine.name} (need \$${repairCost.toStringAsFixed(2)})');
      return;
    }

    // Repair the machine
    final updatedMachine = machine.copyWith(condition: MachineCondition.good);
    final updatedMachines = [...state.machines];
    updatedMachines[machineIndex] = updatedMachine;

    // Deduct repair cost
    final newCash = state.cash - repairCost;

    // Update state
    state = state.copyWith(
      machines: updatedMachines,
      cash: newCash,
    );
    state = state.addLogMessage(
      'Repaired ${machine.name} for \$${repairCost.toStringAsFixed(2)}',
    );

    // Sync to simulation engine (use updateMachine for atomic update)
    simulationEngine.updateMachine(updatedMachine);
    simulationEngine.updateCash(newCash);
  }

  /// Update hype level (0.0 to 1.0)
  void updateHypeLevel(double newHype) {
    state = state.copyWith(
      hypeLevel: newHype.clamp(0.0, 1.0),
    );
  }

  /// Start Rush Hour - sets multiplier to 10.0 and resets hype
  void startRushHour() {
    state = state.copyWith(
      isRushHour: true,
      hypeLevel: 0.0,
      rushMultiplier: 10.0,
    );
    // Sync rush multiplier to simulation engine
    simulationEngine.updateRushMultiplier(10.0);
    state = state.addLogMessage('Rush Hour activated! Sales speed increased!');
  }

  /// End Rush Hour - resets multiplier to 1.0 and spawns marketing button at random location
  void endRushHour() {
    // Clear any existing timer
    _marketingButtonSpawnTimer?.cancel();
    
    // Update rush hour state immediately
    state = state.copyWith(
      isRushHour: false,
      rushMultiplier: 1.0,
      // Clear marketing button position so it doesn't show immediately
      marketingButtonGridX: null,
      marketingButtonGridY: null,
    );
    // Sync rush multiplier to simulation engine
    simulationEngine.updateRushMultiplier(1.0);
    
    // Spawn marketing button after random delay (10 to 30 seconds)
    final random = math.Random();
    final delaySeconds = 10 + random.nextInt(21); // 10-30 seconds
    _marketingButtonSpawnTimer = Timer(Duration(seconds: delaySeconds), () {
      _spawnMarketingButton();
    });
    state = state.addLogMessage('Rush Hour ended. Marketing opportunity appeared!');
  }

  @override
  @override
  void dispose() {
    // Cancel the marketing button spawn timer
    _marketingButtonSpawnTimer?.cancel();
    
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

/// Provider for rewarded ad manager
final rewardedAdProvider = Provider<RewardedAdManager>((ref) {
  return RewardedAdManager();
});

