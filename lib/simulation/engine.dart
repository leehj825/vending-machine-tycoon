import 'dart:async';
import 'dart:math' as math;
import 'package:state_notifier/state_notifier.dart';
import '../config.dart';
import 'models/product.dart';
import 'models/machine.dart';
import 'models/truck.dart';
import 'models/zone.dart';
import '../state/providers.dart';

/// Simulation constants
/// Note: Most constants have been moved to AppConfig. This class is kept for backward compatibility.
class SimulationConstants {
  static const double gasPrice = AppConfig.gasPrice;
  static const int hoursPerDay = AppConfig.hoursPerDay;
  static const int ticksPerHour = AppConfig.ticksPerHour;
  static const int ticksPerDay = AppConfig.ticksPerDay;
  static const int emptyMachinePenaltyHours = AppConfig.emptyMachinePenaltyHours;
  static const int reputationPenaltyPerEmptyHour = AppConfig.reputationPenaltyPerEmptyHour;
  static const int reputationGainPerSale = AppConfig.reputationGainPerSale;
  static const double disposalCostPerExpiredItem = AppConfig.disposalCostPerExpiredItem;
  
  // Pathfinding constants
  static const double roadSnapThreshold = AppConfig.roadSnapThreshold;
  static const double pathfindingHeuristicWeight = AppConfig.pathfindingHeuristicWeight;
  static const double wrongWayPenalty = AppConfig.wrongWayPenalty;
}

/// Game time state
class GameTime {
  final int day; // Current game day (starts at 1)
  final int hour; // Current hour (0-23)
  final int minute; // Current minute (0-59, in increments based on ticksPerHour)
  final int tick; // Current tick within the day (0-5999, since 6000 ticks per day)

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
    // Calculate minutes: each tick represents (60 minutes / ticksPerHour) of game time
    // Round to nearest minute for display
    final minutesPerTick = 60.0 / SimulationConstants.ticksPerHour;
    final minute = ((tickInDay % SimulationConstants.ticksPerHour) * minutesPerTick).round().clamp(0, 59);
    
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
  final double rushMultiplier; // Sales multiplier during Rush Hour (default 1.0)
  final Warehouse warehouse; // Warehouse inventory for auto-restock
  final List<String> pendingMessages; // Messages to be displayed to user
  final int mechanicCount; // Number of mechanics hired
  final int purchasingAgentCount; // Number of purchasing agents hired
  final Map<Product, int> purchasingAgentTargetInventory; // Target inventory levels for purchasing agent

  const SimulationState({
    required this.time,
    required this.machines,
    required this.trucks,
    required this.cash,
    required this.reputation,
    required this.random,
    this.warehouseRoadX,
    this.warehouseRoadY,
    this.rushMultiplier = 1.0,
    required this.warehouse,
    this.pendingMessages = const [],
    this.mechanicCount = 0,
    this.purchasingAgentCount = 0,
    this.purchasingAgentTargetInventory = const {},
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
    double? rushMultiplier,
    Warehouse? warehouse,
    List<String>? pendingMessages,
    int? mechanicCount,
    int? purchasingAgentCount,
    Map<Product, int>? purchasingAgentTargetInventory,
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
      rushMultiplier: rushMultiplier ?? this.rushMultiplier,
      warehouse: warehouse ?? this.warehouse,
      pendingMessages: pendingMessages ?? this.pendingMessages,
      mechanicCount: mechanicCount ?? this.mechanicCount,
      purchasingAgentCount: purchasingAgentCount ?? this.purchasingAgentCount,
      purchasingAgentTargetInventory: purchasingAgentTargetInventory ?? this.purchasingAgentTargetInventory,
    );
  }
}

/// The Simulation Engine - The Heartbeat of the Game
class SimulationEngine extends StateNotifier<SimulationState> {
  Timer? _tickTimer;
  final StreamController<SimulationState> _streamController = StreamController<SimulationState>.broadcast();
  
  // Pathfinding optimization: cached base graph
  // Exact road tile coordinates (set via setMapLayout method)
  Set<({double x, double y})> _roadTiles = {};
  Map<({double x, double y}), List<({double x, double y})>>? _cachedBaseGraph;
  
  // Debug output throttling - only print once per second
  DateTime? _lastDebugPrint;

  SimulationEngine({
    required List<Machine> initialMachines,
    required List<Truck> initialTrucks,
    double initialCash = 2000.0,
    int initialReputation = 100,
    double initialRushMultiplier = 1.0,
    Warehouse? initialWarehouse,
  }) : super(
          SimulationState(
            time: const GameTime(day: 1, hour: 8, minute: 0, tick: 1000), // 8:00 AM = 8 hours * 125 ticks/hour = 1000 ticks
            machines: initialMachines,
            trucks: initialTrucks,
            cash: initialCash,
            reputation: initialReputation,
            random: math.Random(),
            rushMultiplier: initialRushMultiplier,
            warehouse: initialWarehouse ?? const Warehouse(),
            pendingMessages: const [],
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

  /// Update a single machine in the simulation (atomic update to prevent race conditions)
  void updateMachine(Machine updatedMachine) {
    final index = state.machines.indexWhere((m) => m.id == updatedMachine.id);
    if (index != -1) {
      final newMachines = List<Machine>.from(state.machines);
      newMachines[index] = updatedMachine;
      state = state.copyWith(machines: newMachines);
      _streamController.add(state);
    }
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

  /// Update rush multiplier in the simulation
  void updateRushMultiplier(double multiplier) {
    print('🔴 ENGINE: Updating rush multiplier to $multiplier');
    state = state.copyWith(rushMultiplier: multiplier);
    _streamController.add(state);
  }

  /// Set map layout with exact road tile coordinates (called when map is generated/loaded)
  void setMapLayout(List<({double x, double y})> roadTiles) {
    _roadTiles = roadTiles.toSet();
    _cachedBaseGraph = null; // Clear cache so graph rebuilds with new roads
  }

  /// Restore simulation state (used for loading saved games)
  void restoreState({
    required GameTime time,
    required List<Machine> machines,
    required List<Truck> trucks,
    required double cash,
    required int reputation,
    double? warehouseRoadX,
    double? warehouseRoadY,
    double rushMultiplier = 1.0,
    Warehouse? warehouse,
    int mechanicCount = 0,
    int purchasingAgentCount = 0,
    Map<Product, int> purchasingAgentTargetInventory = const {},
  }) {
    print('🔴 ENGINE: Restoring state - Day ${time.day} ${time.hour}:00');
    state = state.copyWith(
      time: time,
      machines: machines,
      trucks: trucks,
      cash: cash,
      reputation: reputation,
      warehouseRoadX: warehouseRoadX,
      warehouseRoadY: warehouseRoadY,
      rushMultiplier: rushMultiplier,
      warehouse: warehouse,
      pendingMessages: const [],
      mechanicCount: mechanicCount,
      purchasingAgentCount: purchasingAgentCount,
      purchasingAgentTargetInventory: purchasingAgentTargetInventory,
    );
    _streamController.add(state);
  }

  /// Get and clear pending messages
  List<String> getAndClearPendingMessages() {
    final messages = List<String>.from(state.pendingMessages);
    state = state.copyWith(pendingMessages: const []);
    return messages;
  }

  /// Update warehouse in the simulation
  void updateWarehouse(Warehouse warehouse) {
    state = state.copyWith(warehouse: warehouse);
    _streamController.add(state);
  }

  /// Update staff counts in the simulation
  void updateStaffCounts({
    int? mechanicCount,
    int? purchasingAgentCount,
    Map<Product, int>? purchasingAgentTargetInventory,
  }) {
    state = state.copyWith(
      mechanicCount: mechanicCount ?? state.mechanicCount,
      purchasingAgentCount: purchasingAgentCount ?? state.purchasingAgentCount,
      purchasingAgentTargetInventory: purchasingAgentTargetInventory ?? state.purchasingAgentTargetInventory,
    );
    _streamController.add(state);
  }

  /// Start the simulation (ticks 10 times per second)
  void start() {
    print('🔴 ENGINE: Start requested');
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(
      AppConfig.animationDurationFast, // 10 ticks per second
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

  /// Get allowed products for a zone type (delegates to Zone.getAllowedProducts)
  List<Product> _getAllowedProductsForZone(ZoneType zoneType) {
    return Zone.getAllowedProducts(zoneType);
  }

  /// Build the base graph containing road tile connections
  /// This is cached to avoid rebuilding on every pathfinding call
  Map<({double x, double y}), List<({double x, double y})>> _getBaseGraph() {
    if (_cachedBaseGraph != null) return _cachedBaseGraph!;

    final graph = <({double x, double y}), List<({double x, double y})>>{};

    // Initialize all nodes
    for (final tile in _roadTiles) {
      graph[tile] = [];
    }

    // Connect adjacent road tiles (check 4 directions: Right, Left, Down, Up)
    for (final tile in _roadTiles) {
      final neighbors = [
        (x: tile.x + 1.0, y: tile.y), // Right
        (x: tile.x - 1.0, y: tile.y), // Left
        (x: tile.x, y: tile.y + 1.0), // Down
        (x: tile.x, y: tile.y - 1.0), // Up
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

  /// Helper to find nearest point on the road network from any coordinate
  /// This projects the point perpendicularly onto the nearest road.
  /// Helper to find nearest road tile from any coordinate using Euclidean distance
  ({double x, double y}) _getNearestRoadPoint(double x, double y) {
    if (_roadTiles.isEmpty) return (x: x, y: y); // Fallback

    double minDistance = double.infinity;
    var nearest = _roadTiles.first;

    for (final tile in _roadTiles) {
      final dx = tile.x - x;
      final dy = tile.y - y;
      final dist = dx * dx + dy * dy; // Squared distance is faster (no sqrt needed for comparison)
      if (dist < minDistance) {
        minDistance = dist;
        nearest = tile;
      }
    }
    return nearest;
  }

  /// Main tick function - called every 1 second (10 minutes in-game)
  void _tick() {
    final currentState = state;
    
    final now = DateTime.now();
    if (_lastDebugPrint == null || now.difference(_lastDebugPrint!).inSeconds >= 1) {
      print('🔴 ENGINE TICK: Day ${currentState.time.day} ${currentState.time.hour}:00 | Machines: ${currentState.machines.length} | Cash: \$${currentState.cash.toStringAsFixed(2)}');
      _lastDebugPrint = now;
    }

    final nextTime = currentState.time.nextTick();
    var pendingMessages = List<String>.from(currentState.pendingMessages);
    var updatedCash = currentState.cash;
    
    if (nextTime.day > currentState.time.day || (currentState.time.hour == 23 && nextTime.hour == 0)) {
      final trucksWithDrivers = currentState.trucks.where((t) => t.hasDriver).length;
        const double driverSalaryPerDay = 50.0;
      const double mechanicSalaryPerDay = 50.0;
      const double purchasingAgentSalaryPerDay = 50.0;
      
      final driverSalary = trucksWithDrivers * driverSalaryPerDay;
      final mechanicSalary = currentState.mechanicCount * mechanicSalaryPerDay;
      final agentSalary = currentState.purchasingAgentCount * purchasingAgentSalaryPerDay;
      final totalSalary = driverSalary + mechanicSalary + agentSalary;
      
      if (totalSalary > 0) {
        updatedCash = currentState.cash - totalSalary;
        pendingMessages.add('💰 Paid \$${totalSalary.toStringAsFixed(2)} in staff salaries');
      }
    }

    final salesResult = _processMachineSales(currentState.machines, nextTime, currentState.reputation);
    var updatedMachines = salesResult.machines;
    final totalSalesThisTick = salesResult.totalSales;
    
    updatedMachines = _processSpoilage(updatedMachines, nextTime);
    updatedMachines = _processRandomBreakdowns(updatedMachines);
    
    if (nextTime.minute == 0 && currentState.time.minute != 0) {
      updatedMachines = _processMechanics(updatedMachines);
    }
    var updatedWarehouse = currentState.warehouse;
    
    if (nextTime.minute == 0 && currentState.time.minute != 0) {
      final purchasingResult = _processPurchasingAgents(updatedCash);
      updatedCash = purchasingResult.cash;
      updatedWarehouse = purchasingResult.warehouse;
      pendingMessages.addAll(purchasingResult.messages);
    }
    
    var autoRestockResult = _processAutoRestock(currentState.trucks, updatedMachines, updatedWarehouse);
    var updatedTrucks = autoRestockResult.trucks;
    updatedMachines = autoRestockResult.machines;
    updatedWarehouse = autoRestockResult.warehouse;
    pendingMessages.addAll(autoRestockResult.messages);
    
    updatedTrucks = _processTruckMovement(updatedTrucks, updatedMachines);
    
    final restockResult = _processTruckRestocking(updatedTrucks, updatedMachines);
    updatedTrucks = restockResult.trucks;
    updatedMachines = restockResult.machines;

    final reputationPenalty = _calculateReputationPenalty(updatedMachines);
    final reputationGain = totalSalesThisTick * SimulationConstants.reputationGainPerSale;
    var updatedReputation = ((currentState.reputation - reputationPenalty + reputationGain).clamp(0, 1000)).round();
    updatedCash = _processFuelCosts(updatedTrucks, currentState.trucks, updatedCash);

    // Update State
    final newState = currentState.copyWith(
      time: nextTime,
      machines: updatedMachines,
      trucks: updatedTrucks,
      cash: updatedCash,
      reputation: updatedReputation,
      warehouse: updatedWarehouse,
      pendingMessages: pendingMessages,
    );
    state = newState;
    
    // Notify listeners of state change via stream
    _streamController.add(newState);
  }

  /// Calculate reputation multiplier for sales bonus
  /// Every 100 reputation = +5% sales rate (max 50% at 1000 reputation)
  double _calculateReputationMultiplier(int reputation) {
    final bonus = (reputation / 100).floor() * AppConfig.reputationBonusPer100;
    return (1.0 + bonus.clamp(0.0, AppConfig.maxReputationBonus));
  }

  /// Process machine sales based on demand math
  /// Returns machines and total sales count for reputation calculation
  ({List<Machine> machines, int totalSales}) _processMachineSales(
    List<Machine> machines, 
    GameTime time,
    int currentReputation,
  ) {
    var totalSales = 0;
    final reputationMultiplier = _calculateReputationMultiplier(currentReputation);
    final rushMultiplier = state.rushMultiplier; // Get rush multiplier from state
    
    final updatedMachines = machines.map((machine) {
      if (machine.isUnderMaintenance) {
        return machine.copyWith(
          hoursSinceRestock: machine.hoursSinceRestock + (1.0 / SimulationConstants.ticksPerHour), // 1 tick = 1/ticksPerHour hours
        );
      }
      
      if (machine.isBroken || machine.isEmpty) {
        return machine.copyWith(
          hoursSinceRestock: machine.hoursSinceRestock + (1.0 / SimulationConstants.ticksPerHour), // 1 tick = 1/ticksPerHour hours
        );
      }

      var updatedInventory = Map<Product, InventoryItem>.from(machine.inventory);
      var updatedCash = machine.currentCash;
      var salesCount = machine.totalSales;
      var hoursSinceRestock = machine.hoursSinceRestock;

      for (final product in Product.values) {
        final stock = machine.getStock(product);
        if (stock == 0) continue;

        final item = updatedInventory[product]!;
        
        final baseDemand = product.baseDemand;
        final zoneMultiplier = machine.zone.getDemandMultiplier(time.hour);
        final trafficMultiplier = machine.zone.trafficMultiplier;
        
        final saleChancePerHour = baseDemand * zoneMultiplier * trafficMultiplier * reputationMultiplier * rushMultiplier;
        final saleChance = saleChancePerHour / SimulationConstants.ticksPerHour;
        
        final clampedChance = saleChance.clamp(0.0, 1.0);
        final newSalesProgress = item.salesProgress + clampedChance;

        if (newSalesProgress >= 1.0) {
          final newQuantity = item.quantity - 1;
          final remainingProgress = newSalesProgress - 1.0;
          
          updatedInventory[product] = item.copyWith(
            quantity: newQuantity.clamp(0, double.infinity).toInt(),
            salesProgress: remainingProgress,
          );

          updatedCash += product.basePrice;
          salesCount++;
          totalSales++;
        } else {
          updatedInventory[product] = item.copyWith(salesProgress: newSalesProgress);
        }
      }
      hoursSinceRestock += (1.0 / SimulationConstants.ticksPerHour);

      return machine.copyWith(
        inventory: updatedInventory,
        currentCash: updatedCash,
        totalSales: salesCount,
        hoursSinceRestock: hoursSinceRestock,
      );
    }).toList();
    
    return (machines: updatedMachines, totalSales: totalSales);
  }

  /// Process spoilage - set expired items to 0 quantity (preserve allocation) and charge disposal cost
  List<Machine> _processSpoilage(List<Machine> machines, GameTime time) {
    return machines.map((machine) {
      var updatedInventory = Map<Product, InventoryItem>.from(machine.inventory);
      var disposalCost = 0.0;

      // Check each inventory item for expiration
      for (final entry in updatedInventory.entries) {
        final item = entry.value;
        if (item.isExpired(time.day)) {
          // Item expired - set quantity to 0 (preserve allocation) and charge disposal
          disposalCost += SimulationConstants.disposalCostPerExpiredItem * item.quantity;
          updatedInventory[entry.key] = item.copyWith(quantity: 0);
        }
      }

      // Deduct disposal cost from machine cash
      final updatedCash = machine.currentCash - disposalCost;

      return machine.copyWith(
        inventory: updatedInventory,
        currentCash: updatedCash,
      );
    }).toList();
  }

  /// Process random breakdowns - checks every tick with probability calculated to give 2% per day total
  /// This provides a good balance: frequent enough to be noticeable with multiple machines,
  /// but not so frequent as to be annoying. With 5 machines, expect ~9.6% chance per day
  /// that at least one breaks (happens roughly every 10 days on average).
  /// 
  /// Probability per tick: p = 1 - (1 - 0.02)^(1/ticksPerDay)
  /// This ensures the total probability per day is exactly 2%
  List<Machine> _processRandomBreakdowns(List<Machine> machines) {
    // Calculate probability per tick to achieve 2% per day total
    // Formula: 1 - (1 - dailyProbability)^(1/ticksPerDay)
    // For small probabilities, this approximates to: dailyProbability / ticksPerDay
    final dailyProbability = 0.02; // 2% per day
    final breakdownChancePerTick = (1.0 - math.pow(1.0 - dailyProbability, 1.0 / SimulationConstants.ticksPerDay)).toDouble();
    
    return machines.map((machine) {
      // Skip if already broken
      if (machine.isBroken) {
        return machine;
      }
      
      final randomValue = state.random.nextDouble();
      
      if (randomValue < breakdownChancePerTick) {
        print('ALERT: Machine ${machine.name} has broken down!');
        return machine.copyWith(
          condition: MachineCondition.broken,
        );
      }
      
      return machine;
    }).toList();
  }

  /// Process mechanics - auto-repair broken machines (1 repair per mechanic per hour)
  List<Machine> _processMechanics(List<Machine> machines) {
    if (state.mechanicCount <= 0) return machines;
    
    var updatedMachines = List<Machine>.from(machines);
    int repairsRemaining = state.mechanicCount;
    
    // Find all broken machines
    final brokenMachines = <int>[];
    for (int i = 0; i < updatedMachines.length; i++) {
      if (updatedMachines[i].isBroken) {
        brokenMachines.add(i);
      }
    }
    
    // Repair up to mechanicCount machines (1 per mechanic)
    for (int i = 0; i < brokenMachines.length && repairsRemaining > 0; i++) {
      final machineIndex = brokenMachines[i];
      updatedMachines[machineIndex] = updatedMachines[machineIndex].copyWith(
        condition: MachineCondition.good,
      );
      repairsRemaining--;
    }
    
    return updatedMachines;
  }

  /// Process purchasing agents - auto-buy stock if warehouse inventory < 50% of target
  /// Returns updated cash, warehouse, and messages
  ({double cash, Warehouse warehouse, List<String> messages}) _processPurchasingAgents(double currentCash) {
    if (state.purchasingAgentCount <= 0) {
      return (cash: currentCash, warehouse: state.warehouse, messages: []);
    }
    
    var updatedCash = currentCash;
    var updatedWarehouseInventory = Map<Product, int>.from(state.warehouse.inventory);
    var messages = <String>[];
    const int itemsPerAgentPerHour = 50;
    final totalItemsToBuy = state.purchasingAgentCount * itemsPerAgentPerHour;
    int itemsBought = 0;
    
    // Check each product for deficit
    for (final product in Product.values) {
      if (itemsBought >= totalItemsToBuy) break;
      
      final currentStock = updatedWarehouseInventory[product] ?? 0;
      final targetStock = state.purchasingAgentTargetInventory[product] ?? 0;
      
      // If target is 0, skip this product
      if (targetStock <= 0) continue;
      
      // Check if current stock < 50% of target
      if (currentStock < (targetStock * 0.5)) {
        // Calculate how much to buy to reach 100% of target
        final deficit = targetStock - currentStock;
        final itemsToBuy = math.min(deficit, totalItemsToBuy - itemsBought);
        
        if (itemsToBuy > 0) {
          // Calculate cost (basePrice * 0.4 as specified)
          final costPerItem = product.basePrice * 0.4;
          final totalCost = itemsToBuy * costPerItem;
          
          // Check if player has enough cash
          if (updatedCash >= totalCost) {
            updatedWarehouseInventory[product] = currentStock + itemsToBuy;
            updatedCash -= totalCost;
            itemsBought += itemsToBuy;
            
            if (itemsBought == itemsToBuy) {
              // Only log first purchase to avoid spam
              messages.add('📦 Purchasing Agent bought $itemsToBuy ${product.name}');
            }
          }
        }
      }
    }
    
    return (
      cash: updatedCash,
      warehouse: Warehouse(inventory: updatedWarehouseInventory),
      messages: messages,
    );
  }

  /// Calculate reputation penalty based on empty machines
  /// Decreases by 1 reputation per second (per tick) for each empty machine
  int _calculateReputationPenalty(List<Machine> machines) {
    int totalPenalty = 0;
    
    for (final machine in machines) {
      if (machine.isEmpty && machine.hoursEmpty >= SimulationConstants.emptyMachinePenaltyHours) {
        // Apply -1 reputation per second (per tick) for each empty machine
        // This is much slower than the previous per-hour calculation
        totalPenalty += 1;
      }
    }
    
    return totalPenalty;
  }

  /// Process auto-restock for trucks with drivers (with smart loading based on route demand)
  /// Returns updated trucks, machines, warehouse, and messages
  ({List<Truck> trucks, List<Machine> machines, Warehouse warehouse, List<String> messages}) _processAutoRestock(
    List<Truck> trucks,
    List<Machine> machines,
    Warehouse currentWarehouse,
  ) {
    var updatedTrucks = List<Truck>.from(trucks);
    var updatedMachines = List<Machine>.from(machines);
    var updatedWarehouseInventory = Map<Product, int>.from(currentWarehouse.inventory);
    var messages = <String>[];

    for (int i = 0; i < updatedTrucks.length; i++) {
      final truck = updatedTrucks[i];
      
      // Check if truck has driver and is idle
      if (!truck.hasDriver || truck.status != TruckStatus.idle) {
        continue;
      }

      // Simple logic: Check each product in each machine - if ANY product is below 50% of its allocation, trigger restock
      final routeMachines = <Machine>[];
      final routeDemand = <Product, int>{}; // Total demand across all machines in route
      bool hasLowStockItem = false; // Track if any product in any machine is below 50% of its allocation
      
      // First pass: Check if any product in any machine is below 50% of its allocation
      for (final machineId in truck.route) {
        final machineIndex = updatedMachines.indexWhere((m) => m.id == machineId);
        if (machineIndex == -1) continue;
        
        final machine = updatedMachines[machineIndex];
        final allowedProducts = _getAllowedProductsForZone(machine.zone.type);
        
        for (final product in allowedProducts) {
          final existingItem = machine.inventory[product];
          final currentStock = existingItem?.quantity ?? 0;
          final allocationTarget = existingItem?.allocation ?? 20;
          
          // Check if this specific product is below 50% of its allocation
          if (allocationTarget > 0 && currentStock < (allocationTarget / 2)) {
            hasLowStockItem = true;
            break; // Found at least one low stock item, that's enough
          }
        }
        
        if (hasLowStockItem) break; // Found low stock, no need to check more machines
      }
      
      // If no products are below 50%, skip this truck
      if (!hasLowStockItem) {
        continue;
      }

      // Second pass: Add ALL machines in route and calculate demand for all products
      for (final machineId in truck.route) {
        final machineIndex = updatedMachines.indexWhere((m) => m.id == machineId);
        if (machineIndex == -1) continue;
        
        final machine = updatedMachines[machineIndex];
        routeMachines.add(machine); // Add all machines in route
        
        // Calculate demand for each product (deficit from allocation target)
        final allowedProducts = _getAllowedProductsForZone(machine.zone.type);
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

      // If no machines in route or no demand, skip this truck
      if (routeMachines.isEmpty || routeDemand.isEmpty) {
        continue;
      }
      
      // Debug: Log route demand and warehouse stock
      print('🚚 TRUCK ROUTE DEMAND: ${truck.name} route has ${routeMachines.length} machines');
      print('   Route demand: ${routeDemand.entries.map((e) => '${e.key.name}: ${e.value}').join(', ')}');
      print('   Warehouse stock: ${updatedWarehouseInventory.entries.where((e) => routeDemand.containsKey(e.key)).map((e) => '${e.key.name}: ${e.value}').join(', ')}');

      // LOAD TRUCK WITH ITEMS FOR ALL MACHINES IN ROUTE (with 20% buffer for last stop)
      final currentTruck = updatedTrucks[i];
      final existingTruckInventory = Map<Product, int>.from(currentTruck.inventory);
      final truckInventory = <Product, int>{};
      int totalLoaded = existingTruckInventory.values.fold<int>(0, (sum, qty) => sum + qty);
      
      // Calculate total demand with 20% buffer (so last stop can be fully stocked)
      final baseTotalDemand = routeDemand.values.fold<int>(0, (sum, demand) => sum + demand);
      final totalDemandWithBuffer = (baseTotalDemand * 1.2).ceil(); // 20% more than needed
      
      // Calculate adjusted demand per product with 20% buffer
      final adjustedRouteDemand = <Product, int>{};
      for (final entry in routeDemand.entries) {
        final adjustedDemand = (entry.value * 1.2).ceil(); // 20% more per product
        adjustedRouteDemand[entry.key] = adjustedDemand;
      }
      
      // Load items proportionally for all machines in route (with buffer)
      for (final entry in adjustedRouteDemand.entries) {
        if (totalLoaded >= currentTruck.capacity) break;
        
        final product = entry.key;
        final totalDemandForProduct = entry.value; // Already includes 20% buffer
        final warehouseStock = updatedWarehouseInventory[product] ?? 0;
        final alreadyOnTruck = existingTruckInventory[product] ?? 0;
        final stillNeeded = totalDemandForProduct - alreadyOnTruck;
        
        if (warehouseStock > 0 && stillNeeded > 0) {
          // Calculate proportional allocation based on buffered demand
          final proportion = totalDemandForProduct / totalDemandWithBuffer;
          final proportionalCapacity = (currentTruck.capacity * proportion).ceil();
          final remainingCapacity = currentTruck.capacity - totalLoaded;
          
          // Load as much as possible: min of (proportional capacity, remaining capacity, still needed, warehouse stock)
          final loadAmount = math.min(
            math.min(proportionalCapacity, remainingCapacity),
            math.min(stillNeeded, warehouseStock)
          );
          
          if (loadAmount > 0) {
            truckInventory[product] = alreadyOnTruck + loadAmount;
            updatedWarehouseInventory[product] = warehouseStock - loadAmount;
            totalLoaded += loadAmount;
          } else if (alreadyOnTruck > 0) {
            // Keep existing items on truck even if we can't load more
            truckInventory[product] = alreadyOnTruck;
          }
        } else if (alreadyOnTruck > 0) {
          // Keep existing items on truck
          truckInventory[product] = alreadyOnTruck;
        }
      }
      
      // If there's still capacity after proportional loading, fill remaining space (using buffered demand)
      if (totalLoaded < currentTruck.capacity) {
        // Sort products by buffered demand (highest first)
        final sortedDemand = adjustedRouteDemand.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        
        for (final entry in sortedDemand) {
          if (totalLoaded >= currentTruck.capacity) break;
          
          final product = entry.key;
          final totalDemandForProduct = entry.value; // Already includes 20% buffer
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
      
      // Keep any other items that were already on the truck
      for (final entry in existingTruckInventory.entries) {
        if (!truckInventory.containsKey(entry.key)) {
          truckInventory[entry.key] = entry.value;
        }
      }
      
      // Update truck with loaded inventory
      final loadedTruck = currentTruck.copyWith(inventory: truckInventory);
      updatedTrucks[i] = loadedTruck;
      
      // Log loading
      if (truckInventory.isNotEmpty && totalLoaded > existingTruckInventory.values.fold<int>(0, (sum, qty) => sum + qty)) {
        final newlyLoaded = truckInventory.entries
            .where((e) => (e.value - (existingTruckInventory[e.key] ?? 0)) > 0)
            .map((e) => '${e.key.name}: +${e.value - (existingTruckInventory[e.key] ?? 0)}')
            .join(', ');
        print('🚚 TRUCK LOAD: Loaded $newlyLoaded into ${currentTruck.name} for ${routeMachines.length} machines in route (total: ${truckInventory.values.fold(0, (a, b) => a + b)}/${currentTruck.capacity})');
      } else if (routeDemand.isNotEmpty && truckInventory.isEmpty) {
        // Debug: Why didn't we load anything?
        final missingProducts = routeDemand.entries
            .where((e) => (updatedWarehouseInventory[e.key] ?? 0) == 0)
            .map((e) => e.key.name)
            .toList();
        if (missingProducts.isNotEmpty) {
          print('⚠️ TRUCK LOAD: ${currentTruck.name} has demand but warehouse has no stock for: ${missingProducts.join(', ')}');
        }
      }
      
      // Dispatch truck to first machine in route (will visit all stops in order)
      // Even if truck is empty, dispatch to complete the route
      final targetMachine = routeMachines.first;
      final machineX = targetMachine.zone.x;
      final machineY = targetMachine.zone.y;
      final roadPoint = _getNearestRoadPoint(machineX, machineY);

      // Dispatch truck to target machine
      final targetIndex = loadedTruck.route.indexOf(targetMachine.id);
      final routeIndex = targetIndex >= 0 ? targetIndex : 0;
      
      updatedTrucks[i] = loadedTruck.copyWith(
        status: TruckStatus.traveling,
        path: [], // Clear path to force recalculation
        targetX: roadPoint.x,
        targetY: roadPoint.y,
        currentRouteIndex: routeIndex,
      );
    }

    return (
      trucks: updatedTrucks,
      machines: updatedMachines,
      warehouse: Warehouse(inventory: updatedWarehouseInventory),
      messages: messages,
    );
  }

  /// Process truck movement and route logic
  List<Truck> _processTruckMovement(
    List<Truck> trucks,
    List<Machine> machines,
  ) {
    const double movementSpeed = AppConfig.movementSpeed;
    
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
        final graph = Map<({double x, double y}), List<({double x, double y})>>.from(
          baseGraph.map((key, value) => MapEntry(key, List<({double x, double y})>.from(value))),
        );

        final startEntry = _getNearestRoadPoint(startX, startY);
        final endExit = _getNearestRoadPoint(endX, endY);

        // Connect Start to network
        if (startEntry != start) {
          graph[start] = [startEntry];
          if (!graph.containsKey(startEntry)) graph[startEntry] = [];
          graph[startEntry]!.add(start); 
        } else {
          if (!graph.containsKey(start)) graph[start] = [];
        }

        // Connect End to network
        if (endExit != end) {
           if (!graph.containsKey(endExit)) graph[endExit] = [];
           graph[endExit]!.add(end);
           graph[end] = [endExit];
        } else {
           if (!graph.containsKey(end)) graph[end] = [];
        }

        // Ensure graph connectivity for dynamic nodes
        void connectToRoadNetwork(({double x, double y}) point) {
          if (baseGraph.containsKey(point)) return; 
          final neighbors = [
            (x: point.x + 1.0, y: point.y),
            (x: point.x - 1.0, y: point.y),
            (x: point.x, y: point.y + 1.0),
            (x: point.x, y: point.y - 1.0),
          ];
          for (final neighbor in neighbors) {
            if (_roadTiles.contains(neighbor)) {
              if (!graph.containsKey(neighbor)) graph[neighbor] = [];
              if (!graph.containsKey(point)) graph[point] = [];
              if (!graph[point]!.contains(neighbor)) graph[point]!.add(neighbor);
              if (!graph[neighbor]!.contains(point)) graph[neighbor]!.add(point);
            }
          }
        }
        connectToRoadNetwork(startEntry);
        connectToRoadNetwork(endExit);

        // A* Search
        final openSet = <({double x, double y})>{start};
        final cameFrom = <({double x, double y}), ({double x, double y})>{};
        final gScore = <({double x, double y}), double>{start: 0.0};
        final fScore = <({double x, double y}), double>{start: (end.x - start.x).abs() + (end.y - start.y).abs()};
        
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
              if (node == start) break; // Exclude start node
              path.insert(0, node);
            }
            if (path.isEmpty || path.last != end) path.add(end);
            return path;
          }
          
          openSet.remove(current);
          final neighbors = graph[current] ?? [];
          
          for (final neighbor in neighbors) {
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
    
    return trucks.map((truck) {
      if (truck.status == TruckStatus.idle) return truck;
      
      double targetX, targetY;
      TruckStatus nextStatus = truck.status;
      bool isRoutingToMachine = false;

      if (truck.isRouteComplete) {
        targetX = state.warehouseRoadX ?? 4.0;
        targetY = state.warehouseRoadY ?? 4.0;
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

      // --- FIX: Geometric "Passed Node" Check (Applied Every Tick) ---
      // Skip nodes that the truck has already passed or is very close to
      while (pathIndex < path.length) {
        final currentTarget = path[pathIndex];
        
        // First check: Is the truck already at or very close to this node?
        final distToNode = (currentTarget.x - truck.currentX).abs() + (currentTarget.y - truck.currentY).abs();
        if (distToNode < 0.15) {
          // Truck is at this node, skip it
          pathIndex++;
          continue;
        }
        
        // Second check: Has the truck passed this node relative to the next node?
        if (path.length > pathIndex + 1) {
          final nextTarget = path[pathIndex + 1];
          // Vector Truck->CurrentNode
          final dx1 = currentTarget.x - truck.currentX;
          final dy1 = currentTarget.y - truck.currentY;
          // Vector CurrentNode->NextNode (path direction)
          final dx2 = nextTarget.x - currentTarget.x;
          final dy2 = nextTarget.y - currentTarget.y;
          
          // If dot product is negative, the truck is ahead of the current node
          // Also check if the truck is closer to the next node than the current node
          final distToNext = (nextTarget.x - truck.currentX).abs() + (nextTarget.y - truck.currentY).abs();
          if ((dx1 * dx2 + dy1 * dy2) < -0.01 || distToNext < distToNode) {
            pathIndex++;
            continue;
          }
        }
        
        // Node is valid, stop checking
        break;
      }
      // ------------------------------------------

      // Movement Execution
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
      
      // Check Final Arrival after move
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

  /// Process fuel costs for trucks
  double _processFuelCosts(List<Truck> updatedTrucks, List<Truck> oldTrucks, double currentCash) {
    double totalFuelCost = 0.0;
    
    // Movement speed: 0.1 units per tick = 1 tile per second (matches truck movement speed)
    const double movementSpeed = AppConfig.movementSpeed;

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

  /// Force a sale at a machine (called when pedestrian is tapped)
  /// Returns true if sale was successful, false if machine is empty
  bool forceSale(String machineId) {
    final machineIndex = state.machines.indexWhere((m) => m.id == machineId);
    if (machineIndex == -1) {
      return false; // Machine not found
    }

    final machine = state.machines[machineIndex];
    
    // Check if machine is empty
    if (machine.isEmpty) {
      return false;
    }

    // Find a random available product from inventory
    final availableProducts = machine.inventory.entries
        .where((entry) => entry.value.quantity > 0)
        .toList();
    
    if (availableProducts.isEmpty) {
      return false;
    }

    // Select random product
    final selectedEntry = availableProducts[state.random.nextInt(availableProducts.length)];
    final product = selectedEntry.key;
    final item = selectedEntry.value;

    // Decrement quantity
    final updatedInventory = Map<Product, InventoryItem>.from(machine.inventory);
    updatedInventory[product] = item.copyWith(quantity: item.quantity - 1);

    // Increment cash and sales
    final updatedCash = machine.currentCash + product.basePrice;
    final updatedSales = machine.totalSales + 1;

    // Update machine
    final updatedMachine = machine.copyWith(
      inventory: updatedInventory,
      currentCash: updatedCash,
      totalSales: updatedSales,
    );

    // Update state
    final updatedMachines = List<Machine>.from(state.machines);
    updatedMachines[machineIndex] = updatedMachine;
    state = state.copyWith(machines: updatedMachines);
    _streamController.add(state);

    return true;
  }

  /// Process a single tick with provided machines and trucks, returning updated lists
  /// This method is used by GameController to sync state
  ({List<Machine> machines, List<Truck> trucks}) tick(
    List<Machine> machines,
    List<Truck> trucks,
  ) {
    final currentTime = state.time;
    final nextTime = currentTime.nextTick();
    final currentReputation = state.reputation;

    // Process all simulation systems
    final salesResult = _processMachineSales(machines, nextTime, currentReputation);
    var updatedMachines = salesResult.machines;
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
      
      final destinationId = truck.currentDestination;
      if (destinationId == null) continue;

      // Find the machine being restocked
      final machineIndex = updatedMachines.indexWhere((m) => m.id == destinationId);
      if (machineIndex == -1) continue;

      final machine = updatedMachines[machineIndex];
      
      // Calculate the target road coordinates for this machine
      final machineX = machine.zone.x;
      final machineY = machine.zone.y;
      final targetRoadPoint = _getNearestRoadPoint(machineX, machineY);
      final targetRoadX = targetRoadPoint.x;
      final targetRoadY = targetRoadPoint.y;
      
      // Check if truck is close enough to the target road coordinates
      final dxToTarget = (truck.currentX - targetRoadX).abs();
      final dyToTarget = (truck.currentY - targetRoadY).abs();
      final isCloseEnough = dxToTarget < SimulationConstants.roadSnapThreshold && 
                             dyToTarget < SimulationConstants.roadSnapThreshold;
      
      // Only snap to road if close enough, otherwise keep current position
      // This prevents teleporting trucks that are mid-movement
      final roadX = isCloseEnough ? targetRoadX : truck.currentX;
      final roadY = isCloseEnough ? targetRoadY : truck.currentY;
      var machineInventory = Map<Product, InventoryItem>.from(machine.inventory);
      var truckInventory = Map<Product, int>.from(truck.inventory);
      var itemsToTransfer = <Product, int>{}; // Items remaining in truck after transfer

      // Transfer items from truck to machine (up to allocation target for each product)
      if (truckInventory.isNotEmpty) {
        // Transfer items from truck to machine
        for (final entry in truckInventory.entries) {
          final product = entry.key;
          final truckQuantity = entry.value;
          if (truckQuantity <= 0) continue;

          // Check if product is allowed in this machine's zone type
          final allowedProducts = _getAllowedProductsForZone(machine.zone.type);
          if (!allowedProducts.contains(product)) {
            // Product not allowed - keep in truck
            itemsToTransfer[product] = truckQuantity;
            continue;
          }

          // Get current stock and allocation target for this product
          final existingItem = machineInventory[product];
          final currentProductStock = existingItem?.quantity ?? 0;
          final allocationTarget = existingItem?.allocation ?? 20; // Default to 20 if new product
          
          // Calculate how much we need to reach allocation target
          final neededToReachAllocation = allocationTarget - currentProductStock;
          
          if (neededToReachAllocation <= 0) {
            // Already at or above allocation target - keep in truck
            itemsToTransfer[product] = truckQuantity;
            continue;
          }

          // Transfer up to the allocation target
          final transferAmount = ((truckQuantity < neededToReachAllocation)
              ? truckQuantity
              : neededToReachAllocation).toInt();

          // Update machine inventory
          if (existingItem != null) {
            // Always update dayAdded to current day when restocking to ensure fresh items
            // This prevents newly stocked items from immediately expiring (bug fix)
            machineInventory[product] = existingItem.copyWith(
              quantity: existingItem.quantity + transferAmount,
              dayAdded: currentDay, // Reset to current day for fresh stock
            );
          } else {
            // New product - create with default allocation of 20
            machineInventory[product] = InventoryItem(
              product: product,
              quantity: transferAmount,
              dayAdded: currentDay,
              allocation: 20,
            );
          }

          // Update truck inventory - keep remaining quantity
          final remainingTruckQuantity = truckQuantity - transferAmount;
          if (remainingTruckQuantity > 0) {
            itemsToTransfer[product] = remainingTruckQuantity;
          }
          }
        }

      // Update truck inventory (empty if all items transferred, or remaining items)
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
              orElse: () => updatedMachines.first, 
            );
            
            // Check if this machine needs any of the products the truck is carrying
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
        
        // Get warehouse position for returning
        final warehouseRoadX = state.warehouseRoadX ?? 4.0;
        final warehouseRoadY = state.warehouseRoadY ?? 4.0;
        
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

      // Update machine inventory (always update, even if no items were transferred)
      // This ensures the machine state is properly updated with any transferred items
      // IMPORTANT: Create a new map to ensure Freezed properly handles the update
      final updatedMachineInventory = Map<Product, InventoryItem>.from(machineInventory);
      final updatedMachine = machine.copyWith(
        inventory: updatedMachineInventory,
          hoursSinceRestock: 0.0,
        );
      
      // Debug: Log if items were actually transferred
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
          print('🔄 TRUCK RESTOCK: Transferred ${itemsTransferred.join(", ")} to machine ${machine.name}');
          print('   Machine inventory before: ${machine.inventory.map((k, v) => MapEntry(k.name, v.quantity))}');
          print('   Machine inventory after: ${updatedMachineInventory.map((k, v) => MapEntry(k.name, v.quantity))}');
        } else {
          print('⚠️ TRUCK RESTOCK: Truck had items but nothing was transferred to machine ${machine.name}');
          print('   Truck inventory: $truckInventory');
          print('   Machine inventory: ${machine.inventory.map((k, v) => MapEntry(k.name, v.quantity))}');
        }
      } else {
        print('⚠️ TRUCK RESTOCK: Truck arrived at machine ${machine.name} but inventory is empty');
      }
      
      updatedMachines[machineIndex] = updatedMachine;
    }

    return (machines: updatedMachines, trucks: updatedTrucks);
  }
}
