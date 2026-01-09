import 'dart:async';
import 'dart:math' as math;
import 'package:state_notifier/state_notifier.dart';
import '../config.dart';
import 'models/product.dart';
import 'models/machine.dart';
import 'models/truck.dart';
import 'models/zone.dart';
import 'models/research.dart';
import 'models/weather.dart';
import '../state/providers.dart';
import '../state/game_log_entry.dart';
import 'systems/simulation_system.dart';
import 'systems/sales_system.dart';
import 'systems/inventory_system.dart';
import 'systems/logistics_system.dart';
import 'systems/maintenance_system.dart';
import 'systems/purchasing_system.dart';
import 'systems/reputation_system.dart';

/// Simulation constants
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
  final List<GameLogEntry> pendingMessages; // Messages to be displayed to user
  final int mechanicCount; // Number of mechanics hired
  final int purchasingAgentCount; // Number of purchasing agents hired
  final Map<Product, int> purchasingAgentTargetInventory; // Target inventory levels for purchasing agent
  final Set<ResearchType> unlockedResearch; // Unlocked research items
  final WeatherType weather; // Current weather

  // Helper to check if it's night time (8 PM to 6 AM)
  bool get isNight => time.hour < 6 || time.hour >= 20;

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
    this.unlockedResearch = const {},
    this.weather = WeatherType.sunny,
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
    List<GameLogEntry>? pendingMessages,
    int? mechanicCount,
    int? purchasingAgentCount,
    Map<Product, int>? purchasingAgentTargetInventory,
    Set<ResearchType>? unlockedResearch,
    WeatherType? weather,
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
      unlockedResearch: unlockedResearch ?? this.unlockedResearch,
      weather: weather ?? this.weather,
    );
  }
}

/// The Simulation Engine - The Heartbeat of the Game
class SimulationEngine extends StateNotifier<SimulationState> {
  Timer? _tickTimer;
  final StreamController<SimulationState> _streamController = StreamController<SimulationState>.broadcast();
  
  // Systems
  final List<SimulationSystem> _systems;
  late final LogisticsSystem _logisticsSystem;
  
  // Debug output throttling - only print once per second
  DateTime? _lastDebugPrint;

  SimulationEngine({
    required List<Machine> initialMachines,
    required List<Truck> initialTrucks,
    double initialCash = 2000.0,
    int initialReputation = 100,
    double initialRushMultiplier = 1.0,
    Warehouse? initialWarehouse,
  }) :
      // Initialize systems
      _logisticsSystem = LogisticsSystem(),
      _systems = [
        SalesSystem(),
        MaintenanceSystem(),
        PurchasingSystem(),
        InventorySystem(),
        // LogisticsSystem injected here, but also kept as field for direct access (setMapLayout)
      ],
      super(
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
        ) {
    // Add remaining systems that need initialization or were created above
    _systems.add(_logisticsSystem);
    _systems.add(ReputationSystem());
  }

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

  /// Update unlocked research
  void updateUnlockedResearch(Set<ResearchType> unlocked) {
    state = state.copyWith(unlockedResearch: unlocked);
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
    _logisticsSystem.setMapLayout(roadTiles);
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
    WeatherType weather = WeatherType.sunny,
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
      weather: weather,
    );
    _streamController.add(state);
  }

  /// Get and clear pending messages
  List<GameLogEntry> getAndClearPendingMessages() {
    final messages = List<GameLogEntry>.from(state.pendingMessages);
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
    super.dispose();
  }

  /// Main tick function - called every 1 second (10 minutes in-game)
  void _tick() {
    var currentState = state;
    
    final now = DateTime.now();
    if (_lastDebugPrint == null || now.difference(_lastDebugPrint!).inSeconds >= 1) {
      print('🔴 ENGINE TICK: Day ${currentState.time.day} ${currentState.time.hour}:00 | Machines: ${currentState.machines.length} | Cash: \$${currentState.cash.toStringAsFixed(2)}');
      _lastDebugPrint = now;
    }

    final nextTime = currentState.time.nextTick();
    var pendingMessages = List<GameLogEntry>.from(currentState.pendingMessages);
    var updatedCash = currentState.cash;
    var updatedWeather = currentState.weather;

    // Random weather change (5% chance per hour)
    if (nextTime.minute == 0 && nextTime.hour != currentState.time.hour) {
      if (state.random.nextDouble() < 0.05) {
        final weatherTypes = WeatherType.values;
        updatedWeather = weatherTypes[state.random.nextInt(weatherTypes.length)];

        pendingMessages.add(GameLogEntry(
          type: LogType.weatherChange,
          timestamp: nextTime,
          data: {'weather': updatedWeather.name},
        ));
      }
    }
    
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
        pendingMessages.add(GameLogEntry(
          type: LogType.staffSalary,
          timestamp: nextTime,
          data: {'amount': totalSalary},
        ));
      }
    }
    
    // Update basic state before passing to systems
    currentState = currentState.copyWith(
      time: nextTime,
      cash: updatedCash,
      weather: updatedWeather,
      pendingMessages: pendingMessages,
    );

    // Process all systems
    for (final system in _systems) {
      currentState = system.update(currentState, nextTime);
    }

    // Update State
    state = currentState;
    
    // Notify listeners of state change via stream
    _streamController.add(currentState);
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

    // Create a temporary state to run through systems
    var tempState = state.copyWith(
      machines: machines,
      trucks: trucks,
      time: nextTime,
    );
    
    // Process all systems
    for (final system in _systems) {
      tempState = system.update(tempState, nextTime);
    }

    return (machines: tempState.machines, trucks: tempState.trucks);
  }
}
