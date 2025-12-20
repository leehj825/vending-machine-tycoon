import 'dart:async';
import 'dart:math';
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
  final Random random;

  const SimulationState({
    required this.time,
    required this.machines,
    required this.trucks,
    required this.cash,
    required this.reputation,
    required this.random,
  });

  SimulationState copyWith({
    GameTime? time,
    List<Machine>? machines,
    List<Truck>? trucks,
    double? cash,
    int? reputation,
    Random? random,
  }) {
    return SimulationState(
      time: time ?? this.time,
      machines: machines ?? this.machines,
      trucks: trucks ?? this.trucks,
      cash: cash ?? this.cash,
      reputation: reputation ?? this.reputation,
      random: random ?? this.random,
    );
  }
}

/// The Simulation Engine - The Heartbeat of the Game
class SimulationEngine extends StateNotifier<SimulationState> {
  Timer? _tickTimer;
  final Random _random = Random();
  final StreamController<SimulationState> _streamController = StreamController<SimulationState>.broadcast();

  SimulationEngine({
    required List<Machine> initialMachines,
    required List<Truck> initialTrucks,
    double initialCash = 1000.0,
    int initialReputation = 100,
  }) : super(
          SimulationState(
            time: const GameTime(day: 1, hour: 8, minute: 0, tick: 48), // 8:00 AM = 8 hours * 6 ticks/hour = 48 ticks
            machines: initialMachines,
            trucks: initialTrucks,
            cash: initialCash,
            reputation: initialReputation,
            random: Random(),
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

  /// Start the simulation (ticks every 1 second)
  void start() {
    print('🔴 ENGINE: Start requested');
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _tick(),
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

  /// Dispose resources
  @override
  void dispose() {
    stop();
    _streamController.close();
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
    updatedCash = _processFuelCosts(updatedTrucks, updatedCash);

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
    return trucks.map((truck) {
      if (!truck.hasRoute || truck.isRouteComplete) {
        return truck.copyWith(status: TruckStatus.idle);
      }

      // Get current destination
      final destinationId = truck.currentDestination;
      if (destinationId == null) {
        return truck.copyWith(status: TruckStatus.idle);
      }

      // Find destination machine
      final destination = machines.firstWhere(
        (m) => m.id == destinationId,
        orElse: () => machines.first, // Fallback
      );

      // Calculate distance to destination
      final dx = destination.zone.x - truck.currentX;
      final dy = destination.zone.y - truck.currentY;
      final distance = (dx * dx + dy * dy) * 0.5; // Euclidean distance

      // If truck is at destination, start restocking
      if (distance < 5.0) {
        // Truck arrived - restock the machine
        // (In a full implementation, this would transfer inventory)
        return truck.copyWith(
          status: TruckStatus.restocking,
          currentRouteIndex: truck.currentRouteIndex + 1,
        );
      }

      // Move truck towards destination
      // Simple movement: move 5.0 units per tick towards target (appropriate for 1000x1000 grid)
      final moveDistance = 5.0;
      final moveRatio = (moveDistance / distance).clamp(0.0, 1.0);
      
      final newX = truck.currentX + (dx * moveRatio);
      final newY = truck.currentY + (dy * moveRatio);

      return truck.copyWith(
        status: TruckStatus.traveling,
        currentX: newX,
        currentY: newY,
        targetX: destination.zone.x,
        targetY: destination.zone.y,
      );
    }).toList();
  }

  /// Process fuel costs for trucks
  double _processFuelCosts(List<Truck> trucks, double currentCash) {
    double totalFuelCost = 0.0;

    for (final truck in trucks) {
      if (truck.status == TruckStatus.traveling) {
        final distance = truck.distanceToTarget;
        final fuelCost = distance * SimulationConstants.gasPrice;
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
      
      final destinationId = truck.currentDestination;
      if (destinationId == null) continue;

      // Find the machine being restocked
      final machineIndex = updatedMachines.indexWhere((m) => m.id == destinationId);
      if (machineIndex == -1) continue;

      final machine = updatedMachines[machineIndex];
      var machineInventory = Map<Product, InventoryItem>.from(machine.inventory);
      var truckInventory = Map<Product, int>.from(truck.inventory);

      // Transfer items from truck to machine (up to machine capacity)
      final maxMachineCapacity = 100; // Max items a machine can hold
      final currentMachineTotal = machineInventory.values.fold<int>(
        0,
        (sum, item) => sum + item.quantity,
      );
      final availableSpace = maxMachineCapacity - currentMachineTotal;

      if (availableSpace > 0 && truckInventory.isNotEmpty) {
        var itemsToTransfer = <Product, int>{};
        var totalTransferred = 0;

        // Transfer items from truck to machine
        for (final entry in truckInventory.entries) {
          if (totalTransferred >= availableSpace) break;
          
          final product = entry.key;
          final truckQuantity = entry.value;
          if (truckQuantity <= 0) continue;

          final transferAmount = (truckQuantity < availableSpace - totalTransferred)
              ? truckQuantity
              : availableSpace - totalTransferred;

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

          totalTransferred += transferAmount;
        }

        // Update truck inventory
        final updatedTruckInventory = itemsToTransfer;
        updatedTrucks[i] = truck.copyWith(
          inventory: updatedTruckInventory,
          status: TruckStatus.traveling, // Done restocking, continue route
        );

        // Update machine
        updatedMachines[machineIndex] = machine.copyWith(
          inventory: machineInventory,
          hoursSinceRestock: 0.0,
        );
      } else {
        // No space or no items, just mark truck as done
        updatedTrucks[i] = truck.copyWith(
          status: TruckStatus.traveling,
        );
      }
    }

    return (machines: updatedMachines, trucks: updatedTrucks);
  }
}

