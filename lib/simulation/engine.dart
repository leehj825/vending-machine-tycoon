import 'dart:async';
import 'dart:math' as math;
import 'package:state_notifier/state_notifier.dart';
import 'models/product.dart';
import 'models/machine.dart';
import 'models/truck.dart';
import 'models/zone.dart';

/// Simulation constants
class SimulationConstants {
  static const double gasPrice = 0.05; // Cost per unit distance
  static const int hoursPerDay = 24;
  static const int ticksPerHour = 10; // 10 ticks = 1 hour
  static const int ticksPerDay = hoursPerDay * ticksPerHour; // 240 ticks per day
  static const int emptyMachinePenaltyHours = 4; // Hours before reputation penalty
  static const int reputationPenaltyPerEmptyHour = 5;
  static const double disposalCostPerExpiredItem = 0.50;
  
  // Pathfinding constants
  static const double roadSnapThreshold = 0.1;
  static const double pathfindingHeuristicWeight = 1.0;
  static const double wrongWayPenalty = 10.0;
}

/// Game time state
class GameTime {
  final int day; // Current game day (starts at 1)
  final int hour; // Current hour (0-23)
  final int minute; // Current minute (0-59, in 6-minute increments since 10 ticks = 1 hour)
  final int tick; // Current tick within the day (0-239, since 240 ticks per day)

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
    // Since 10 ticks = 1 hour, each tick is 6 minutes (60 minutes / 10 ticks)
    final minute = (tickInDay % SimulationConstants.ticksPerHour) * 6;
    
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
  
  // Pathfinding optimization: cached base graph
  static const List<double> _validRoads = [1.0, 4.0, 7.0, 10.0];
  static const List<double> _outwardRoads = [1.0, 10.0];
  Map<({double x, double y}), List<({double x, double y})>>? _cachedBaseGraph;
  
  // Helper function to snap to nearest valid road coordinate
  double _snapToNearestRoad(double coord) {
    final rounded = coord.round().toDouble();
    double nearest = _validRoads[0];
    double minDist = (rounded - nearest).abs();
    for (final road in _validRoads) {
      final dist = (rounded - road).abs();
      if (dist < minDist) {
        minDist = dist;
        nearest = road;
      }
    }
    return nearest;
  }
  
  // Helper function to validate and clamp coordinates to valid roads
  // Ensures trucks never move to invalid coordinates like 0 or 9
  // Allows movement along road lines (horizontal or vertical)
  ({double x, double y}) _clampToValidRoad(double x, double y) {
    double clampedX = x;
    double clampedY = y;
    
    // Check if x is on a valid vertical road (within threshold)
    bool xOnRoad = false;
    double nearestRoadX = x;
    for (final roadX in _validRoads) {
      if ((x - roadX).abs() < SimulationConstants.roadSnapThreshold) {
        nearestRoadX = roadX;
        xOnRoad = true;
        break;
      }
    }
    
    // Check if y is on a valid horizontal road (within threshold)
    bool yOnRoad = false;
    double nearestRoadY = y;
    for (final roadY in _validRoads) {
      if ((y - roadY).abs() < SimulationConstants.roadSnapThreshold) {
        nearestRoadY = roadY;
        yOnRoad = true;
        break;
      }
    }
    
    // Only clamp coordinates that are at invalid positions (0 or 9)
    // Allow free movement along road lines
    final roundedX = x.round().toDouble();
    final roundedY = y.round().toDouble();
    
    if (xOnRoad && yOnRoad) {
      // At intersection - snap both to exact road coordinates
      clampedX = nearestRoadX;
      clampedY = nearestRoadY;
    } else if (xOnRoad) {
      // On vertical road - snap x to road, allow y to move freely unless it's 0 or 9
      clampedX = nearestRoadX;
      if (roundedY == 0.0 || roundedY == 9.0) {
        clampedY = _snapToNearestRoad(y);
      } else {
        clampedY = y; // Allow free movement along the road
      }
    } else if (yOnRoad) {
      // On horizontal road - snap y to road, allow x to move freely unless it's 0 or 9
      clampedY = nearestRoadY;
      if (roundedX == 0.0 || roundedX == 9.0) {
        clampedX = _snapToNearestRoad(x);
      } else {
        clampedX = x; // Allow free movement along the road
      }
    } else {
      // Not on any road - check if at invalid coordinates
      if (roundedX == 0.0 || roundedX == 9.0 || roundedY == 0.0 || roundedY == 9.0) {
        // At invalid position - snap to nearest intersection
        clampedX = _snapToNearestRoad(x);
        clampedY = _snapToNearestRoad(y);
      } else {
        // Allow current position (might be transitioning between roads)
        clampedX = x;
        clampedY = y;
      }
    }
    
    return (x: clampedX, y: clampedY);
  }

  SimulationEngine({
    required List<Machine> initialMachines,
    required List<Truck> initialTrucks,
    double initialCash = 2000.0,
    int initialReputation = 100,
  }) : super(
          SimulationState(
            time: const GameTime(day: 1, hour: 8, minute: 0, tick: 80), // 8:00 AM = 8 hours * 10 ticks/hour = 80 ticks
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

  /// Restore simulation state (used for loading saved games)
  void restoreState({
    required GameTime time,
    required List<Machine> machines,
    required List<Truck> trucks,
    required double cash,
    required int reputation,
    double? warehouseRoadX,
    double? warehouseRoadY,
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
    );
    _streamController.add(state);
  }

  /// Start the simulation (ticks 10 times per second)
  void start() {
    print('🔴 ENGINE: Start requested');
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(
      const Duration(milliseconds: 100), // 10 ticks per second
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

  /// Get allowed products for a zone type
  List<Product> _getAllowedProductsForZone(ZoneType zoneType) {
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

  /// Build the base graph containing permanent road intersections
  /// This is cached to avoid rebuilding on every pathfinding call
  /// Graph connects intersections that are on the same horizontal or vertical road
  Map<({double x, double y}), List<({double x, double y})>> _getBaseGraph() {
    if (_cachedBaseGraph != null) return Map.from(_cachedBaseGraph!);

    final graph = <({double x, double y}), List<({double x, double y})>>{};
    
    // Helper to check if a coordinate is on an outward road
    bool isOutwardRoad(double coord) => _outwardRoads.contains(coord);
    
    // Build basic grid graph (intersections)
    // Each intersection connects to all other intersections on the same horizontal or vertical road
    for (final roadX in _validRoads) {
      for (final roadY in _validRoads) {
        final node = (x: roadX, y: roadY);
        graph[node] = [];
        
        // Connect horizontally (same y, different x)
        for (final otherRoadX in _validRoads) {
          if (otherRoadX != roadX) {
            final targetNode = (x: otherRoadX, y: roadY);
            final isCurrentOutward = isOutwardRoad(roadX);
            final isTargetOutward = isOutwardRoad(otherRoadX);
            // Avoid outward roads unless already on one
            if (!isTargetOutward || isCurrentOutward) {
              graph[node]!.add(targetNode);
            }
          }
        }
        
        // Connect vertically (same x, different y)
        for (final otherRoadY in _validRoads) {
          if (otherRoadY != roadY) {
            final targetNode = (x: roadX, y: otherRoadY);
            final isCurrentOutward = isOutwardRoad(roadY);
            final isTargetOutward = isOutwardRoad(otherRoadY);
            if (!isTargetOutward || isCurrentOutward) {
              graph[node]!.add(targetNode);
            }
          }
        }
      }
    }
    
    _cachedBaseGraph = graph;
    return Map.from(graph); // Return a copy to avoid modifying cache
  }

  /// Main tick function - called every 1 second (10 minutes in-game)
  void _tick() {
    try {
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

      // Update State - ensure all data is valid before updating
      try {
        final newState = currentState.copyWith(
          time: nextTime,
          machines: updatedMachines,
          trucks: updatedTrucks,
          cash: updatedCash,
          reputation: updatedReputation,
        );
        state = newState;
        
        // Notify listeners of state change via stream
        if (!_streamController.isClosed) {
          _streamController.add(newState);
        }
      } catch (stateError, stateStack) {
        print('❌ ERROR updating state: $stateError');
        print('Stack trace: $stateStack');
        // Don't update state if there's an error, but continue ticking
      }
    } catch (e, stackTrace) {
      // Log error but don't stop the simulation
      print('❌ ERROR in simulation tick: $e');
      print('Stack trace: $stackTrace');
      // Continue simulation even if there's an error - don't let exceptions stop the timer
    }
  }

  /// Process machine sales based on demand math
  /// Implements: SaleChance = BaseDemand * ZoneMultiplier * HourMultiplier * Traffic
  List<Machine> _processMachineSales(List<Machine> machines, GameTime time) {
    return machines.map((machine) {
      if (machine.isBroken || machine.isEmpty) {
        // Increment hours since restock if empty (1 tick = 0.1 hours since 10 ticks = 1 hour)
        return machine.copyWith(
          hoursSinceRestock: machine.hoursSinceRestock + 0.1, // 1 tick = 0.1 hours
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
        // SaleChance per hour = 0.10 * 2.0 * 1.2 = 0.24 (24% chance per hour)
        // Since 10 ticks = 1 hour, divide by 10 to get per-tick chance
        final saleChancePerHour = baseDemand * zoneMultiplier * trafficMultiplier;
        final saleChance = saleChancePerHour / 10.0; // Divide by 10 since 10 ticks = 1 hour
        
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

      // Update hours since restock (increment by 0.1 hours since 10 ticks = 1 hour)
      hoursSinceRestock += 0.1;

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
    try {
      // Movement speed: 0.1 units per tick = 1 tile per second (10 ticks per second)
      const double movementSpeed = 0.1;
    
    // Helper function to generate a simple road-based path when pathfinding fails
    // This ensures trucks always follow roads, not direct paths
    List<({double x, double y})> _generateSimpleRoadPath(
      double startX, double startY,
      double endX, double endY,
    ) {
      // Snap to nearest roads
      final startRoadX = _snapToNearestRoad(startX);
      final startRoadY = _snapToNearestRoad(startY);
      final endRoadX = _snapToNearestRoad(endX);
      final endRoadY = _snapToNearestRoad(endY);
      
      final path = <({double x, double y})>[];
      
      // If on same vertical road, go straight vertically
      if ((startRoadX - endRoadX).abs() < 0.01) {
        final step = endRoadY > startRoadY ? 1.0 : -1.0;
        var y = startRoadY;
        while ((endRoadY > startRoadY && y <= endRoadY) || (endRoadY < startRoadY && y >= endRoadY)) {
          path.add((x: startRoadX, y: y));
          y += step;
          if (path.length > 50) break;
        }
        return path.isEmpty ? [(x: endRoadX, y: endRoadY)] : path;
      }
      
      // If on same horizontal road, go straight horizontally
      if ((startRoadY - endRoadY).abs() < 0.01) {
        final step = endRoadX > startRoadX ? 1.0 : -1.0;
        var x = startRoadX;
        while ((endRoadX > startRoadX && x <= endRoadX) || (endRoadX < startRoadX && x >= endRoadX)) {
          path.add((x: x, y: startRoadY));
          x += step;
          if (path.length > 50) break;
        }
        return path.isEmpty ? [(x: endRoadX, y: endRoadY)] : path;
      }
      
      // Need to go through an intersection - find a common road
      // Try going horizontally first, then vertically
      final midRoadX = startRoadX;
      final midRoadY = endRoadY;
      
      // Check if mid point is on a valid road
      bool midOnRoad = false;
      for (final roadX in _validRoads) {
        if ((roadX - midRoadX).abs() < 0.01) midOnRoad = true;
      }
      for (final roadY in _validRoads) {
        if ((roadY - midRoadY).abs() < 0.01) midOnRoad = true;
      }
      
      if (midOnRoad) {
        // Path: start -> (startRoadX, endRoadY) -> end
        // Horizontal segment
        final stepX = midRoadX > startRoadX ? 1.0 : -1.0;
        var x = startRoadX;
        while ((midRoadX > startRoadX && x <= midRoadX) || (midRoadX < startRoadX && x >= midRoadX)) {
          path.add((x: x, y: startRoadY));
          x += stepX;
          if (path.length > 50) break;
        }
        // Vertical segment
        final stepY = endRoadY > midRoadY ? 1.0 : -1.0;
        var y = midRoadY;
        while ((endRoadY > midRoadY && y <= endRoadY) || (endRoadY < midRoadY && y >= endRoadY)) {
          path.add((x: midRoadX, y: y));
          y += stepY;
          if (path.length > 50) break;
        }
        if (path.isEmpty || (path.last.x != endRoadX || path.last.y != endRoadY)) {
          path.add((x: endRoadX, y: endRoadY));
        }
        return path;
      }
      
      // Try going vertically first, then horizontally
      final midRoadX2 = endRoadX;
      final midRoadY2 = startRoadY;
      
      bool mid2OnRoad = false;
      for (final roadX in _validRoads) {
        if ((roadX - midRoadX2).abs() < 0.01) mid2OnRoad = true;
      }
      for (final roadY in _validRoads) {
        if ((roadY - midRoadY2).abs() < 0.01) mid2OnRoad = true;
      }
      
      if (mid2OnRoad) {
        // Path: start -> (endRoadX, startRoadY) -> end
        // Vertical segment
        final stepY = midRoadY2 > startRoadY ? 1.0 : -1.0;
        var y = startRoadY;
        while ((midRoadY2 > startRoadY && y <= midRoadY2) || (midRoadY2 < startRoadY && y >= midRoadY2)) {
          path.add((x: startRoadX, y: y));
          y += stepY;
          if (path.length > 50) break;
        }
        // Horizontal segment
        final stepX = endRoadX > midRoadX2 ? 1.0 : -1.0;
        var x = midRoadX2;
        while ((endRoadX > midRoadX2 && x <= endRoadX) || (endRoadX < midRoadX2 && x >= endRoadX)) {
          path.add((x: x, y: midRoadY2));
          x += stepX;
          if (path.length > 50) break;
        }
        if (path.isEmpty || (path.last.x != endRoadX || path.last.y != endRoadY)) {
          path.add((x: endRoadX, y: endRoadY));
        }
        return path;
      }
      
      // Fallback: find nearest intersection and create path through it
      ({double x, double y})? bestIntersection;
      double bestDist = double.infinity;
      
      for (final roadX in _validRoads) {
        for (final roadY in _validRoads) {
          final dist1 = (roadX - startRoadX).abs() + (roadY - startRoadY).abs();
          final dist2 = (roadX - endRoadX).abs() + (roadY - endRoadY).abs();
          final totalDist = dist1 + dist2;
          if (totalDist < bestDist) {
            bestDist = totalDist;
            bestIntersection = (x: roadX, y: roadY);
          }
        }
      }
      
      if (bestIntersection != null) {
        // Path through intersection: start -> intersection -> end
        // Horizontal segment to intersection
        final stepX = bestIntersection.x > startRoadX ? 1.0 : -1.0;
        var x = startRoadX;
        while ((bestIntersection.x > startRoadX && x <= bestIntersection.x) || 
               (bestIntersection.x < startRoadX && x >= bestIntersection.x)) {
          path.add((x: x, y: startRoadY));
          x += stepX;
          if (path.length > 50) break;
        }
        // Vertical segment from intersection to end
        final stepY = endRoadY > bestIntersection.y ? 1.0 : -1.0;
        var y = bestIntersection.y;
        while ((endRoadY > bestIntersection.y && y <= endRoadY) || 
               (endRoadY < bestIntersection.y && y >= endRoadY)) {
          path.add((x: bestIntersection.x, y: y));
          y += stepY;
          if (path.length > 50) break;
        }
        if (path.isEmpty || (path.last.x != endRoadX || path.last.y != endRoadY)) {
          path.add((x: endRoadX, y: endRoadY));
        }
        return path;
      }
      
      // Last resort: direct path (shouldn't happen)
      return [(x: endRoadX, y: endRoadY)];
    }
    
    // Simplified pathfinding - generates paths along roads only
    // Returns a list of waypoints where trucks can move step by step
    List<({double x, double y})> findPath(
      double startX, double startY,
      double endX, double endY,
    ) {
      // Snap to nearest road intersections for pathfinding
      final startRoadX = _snapToNearestRoad(startX);
      final startRoadY = _snapToNearestRoad(startY);
      final endRoadX = _snapToNearestRoad(endX);
      final endRoadY = _snapToNearestRoad(endY);
      
      // If already at destination
      if ((startRoadX - endRoadX).abs() < 0.01 && (startRoadY - endRoadY).abs() < 0.01) {
        return [(x: endRoadX, y: endRoadY)];
      }
      
      // Simple case: same road line (horizontal or vertical)
      if ((startRoadX - endRoadX).abs() < 0.01) {
        // Same vertical road
        final path = <({double x, double y})>[];
        final step = endRoadY > startRoadY ? 1.0 : -1.0;
        var y = startRoadY;
        while ((endRoadY > startRoadY && y <= endRoadY) || (endRoadY < startRoadY && y >= endRoadY)) {
          path.add((x: startRoadX, y: y));
          y += step;
          if (path.length > 50) break; // Safety
        }
        if (path.isEmpty || (path.last.x - endRoadX).abs() > 0.01 || (path.last.y - endRoadY).abs() > 0.01) {
          path.add((x: endRoadX, y: endRoadY));
        }
        return path;
      }
      
      if ((startRoadY - endRoadY).abs() < 0.01) {
        // Same horizontal road
        final path = <({double x, double y})>[];
        final step = endRoadX > startRoadX ? 1.0 : -1.0;
        var x = startRoadX;
        while ((endRoadX > startRoadX && x <= endRoadX) || (endRoadX < startRoadX && x >= endRoadX)) {
          path.add((x: x, y: startRoadY));
          x += step;
          if (path.length > 50) break; // Safety
        }
        if (path.isEmpty || (path.last.x - endRoadX).abs() > 0.01 || (path.last.y - endRoadY).abs() > 0.01) {
          path.add((x: endRoadX, y: endRoadY));
        }
        return path;
      }
      
      // Need to go through intersections - use A* on road graph
      final baseGraph = _getBaseGraph();
      final start = (x: startRoadX, y: startRoadY);
      final end = (x: endRoadX, y: endRoadY);
      
      // Add start and end to graph if needed
      final graph = Map<({double x, double y}), List<({double x, double y})>>.from(
        baseGraph.map((key, value) => MapEntry(key, List.from(value))),
      );
      
      if (!graph.containsKey(start)) graph[start] = [];
      if (!graph.containsKey(end)) graph[end] = [];
      
      // Connect start/end to intersections on same roads
      for (final roadX in _validRoads) {
        if ((roadX - startRoadX).abs() < 0.01) {
          for (final roadY in _validRoads) {
            final n = (x: roadX, y: roadY);
            if (graph.containsKey(n) && (n.x != start.x || n.y != start.y)) {
              graph[start]!.add(n);
              graph[n]!.add(start);
            }
          }
        }
        if ((roadX - endRoadX).abs() < 0.01) {
          for (final roadY in _validRoads) {
            final n = (x: roadX, y: roadY);
            if (graph.containsKey(n) && (n.x != end.x || n.y != end.y)) {
              graph[end]!.add(n);
              graph[n]!.add(end);
            }
          }
        }
      }
      for (final roadY in _validRoads) {
        if ((roadY - startRoadY).abs() < 0.01) {
          for (final roadX in _validRoads) {
            final n = (x: roadX, y: roadY);
            if (graph.containsKey(n) && (n.x != start.x || n.y != start.y)) {
              graph[start]!.add(n);
              graph[n]!.add(start);
            }
          }
        }
        if ((roadY - endRoadY).abs() < 0.01) {
          for (final roadX in _validRoads) {
            final n = (x: roadX, y: roadY);
            if (graph.containsKey(n) && (n.x != end.x || n.y != end.y)) {
              graph[end]!.add(n);
              graph[n]!.add(end);
            }
          }
        }
      }
      
      // Simple A* pathfinding
      final openSet = <({double x, double y})>{start};
      final cameFrom = <({double x, double y}), ({double x, double y})>{};
      final gScore = <({double x, double y}), double>{start: 0.0};
      final fScore = <({double x, double y}), double>{start: (end.x - start.x).abs() + (end.y - start.y).abs()};
      
      ({double x, double y})? goal;
      
      while (openSet.isNotEmpty) {
        ({double x, double y})? current;
        double minF = double.infinity;
        for (final n in openSet) {
          final f = fScore[n] ?? double.infinity;
          if (f < minF) {
            minF = f;
            current = n;
          }
        }
        if (current == null) break;
        
        if ((current.x - end.x).abs() < 0.01 && (current.y - end.y).abs() < 0.01) {
          goal = current;
          break;
        }
        
        openSet.remove(current);
        for (final neighbor in graph[current] ?? []) {
          final dx = (neighbor.x - current.x).abs();
          final dy = (neighbor.y - current.y).abs();
          if (dx > 0 && dy > 0) continue; // No diagonal
          
          final cost = dx + dy;
          final tg = (gScore[current] ?? double.infinity) + cost;
          if (tg < (gScore[neighbor] ?? double.infinity)) {
            cameFrom[neighbor] = current;
            gScore[neighbor] = tg;
            fScore[neighbor] = tg + ((end.x - neighbor.x).abs() + (end.y - neighbor.y).abs());
            if (!openSet.contains(neighbor)) {
              openSet.add(neighbor);
            }
          }
        }
      }
      
      // Reconstruct path
      final path = <({double x, double y})>[];
      if (goal != null) {
        var node = goal;
        while (true) {
          path.insert(0, node);
          final nextNode = cameFrom[node];
          if (nextNode == null || (nextNode.x == start.x && nextNode.y == start.y)) {
            break;
          }
          node = nextNode;
          if (path.length > 50) break;
        }
      }
      
      if (path.isEmpty) {
        // Generate simple road path instead of direct path
        return _generateSimpleRoadPath(startRoadX, startRoadY, endRoadX, endRoadY);
      }
      
      // Expand path with intermediate waypoints
      final expanded = <({double x, double y})>[];
      expanded.add((x: startRoadX, y: startRoadY));
      
      for (int i = 0; i < path.length; i++) {
        final prev = i > 0 ? path[i - 1] : (x: startRoadX, y: startRoadY);
        final curr = path[i];
        
        if ((prev.x - curr.x).abs() < 0.01) {
          // Vertical movement
          final step = curr.y > prev.y ? 1.0 : -1.0;
          var y = prev.y + step;
          while ((curr.y > prev.y && y <= curr.y) || (curr.y < prev.y && y >= curr.y)) {
            expanded.add((x: prev.x, y: y));
            y += step;
            if (expanded.length > 100) break;
          }
        } else if ((prev.y - curr.y).abs() < 0.01) {
          // Horizontal movement
          final step = curr.x > prev.x ? 1.0 : -1.0;
          var x = prev.x + step;
          while ((curr.x > prev.x && x <= curr.x) || (curr.x < prev.x && x >= curr.x)) {
            expanded.add((x: x, y: prev.y));
            x += step;
            if (expanded.length > 100) break;
          }
        }
        expanded.add(curr);
      }
      
      return expanded.isEmpty ? [(x: endRoadX, y: endRoadY)] : expanded;
    }
    
    // Helper function to expand path with intermediate waypoints along road segments
    // This ensures smooth movement between intersections
    List<({double x, double y})> _expandPathWithWaypoints(List<({double x, double y})> path) {
      if (path.length < 2) return path;
      
      final expanded = <({double x, double y})>[path[0]];
      
      for (int i = 1; i < path.length; i++) {
        final prev = path[i - 1];
        final curr = path[i];
        
        // If moving horizontally (same y)
        if ((prev.y - curr.y).abs() < 0.01) {
          final startX = prev.x;
          final endX = curr.x;
          final y = prev.y;
          final step = endX > startX ? 1.0 : -1.0;
          
          // Add intermediate points every 1 unit along the road
          var x = startX + step;
          while ((endX > startX && x < endX) || (endX < startX && x > endX)) {
            expanded.add((x: x, y: y));
            x += step;
          }
        }
        // If moving vertically (same x)
        else if ((prev.x - curr.x).abs() < 0.01) {
          final startY = prev.y;
          final endY = curr.y;
          final x = prev.x;
          final step = endY > startY ? 1.0 : -1.0;
          
          // Add intermediate points every 1 unit along the road
          var y = startY + step;
          while ((endY > startY && y < endY) || (endY < startY && y > startY)) {
            expanded.add((x: x, y: y));
            y += step;
          }
        }
        
        // Always add the destination waypoint
        expanded.add(curr);
      }
      
      return expanded;
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
        if (distanceToWarehouse < SimulationConstants.roadSnapThreshold) {
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
          // Generate path through intersections
          try {
            path = findPath(currentX, currentY, warehouseRoadX, warehouseRoadY);
            pathIndex = 0;
          // Ensure path is not empty and has at least the destination
          if (path.isEmpty) {
            path = _generateSimpleRoadPath(currentX, currentY, warehouseRoadX, warehouseRoadY);
          }
            // If truck is already at first waypoint, skip to next
            // But be careful not to skip too many waypoints
            while (pathIndex < path.length) {
              final waypoint = path[pathIndex];
              final distToWaypoint = math.sqrt(
                (waypoint.x - currentX) * (waypoint.x - currentX) + 
                (waypoint.y - currentY) * (waypoint.y - currentY)
              );
              if (distToWaypoint < SimulationConstants.roadSnapThreshold) {
                pathIndex++;
                if (pathIndex >= path.length) break;
              } else {
                break; // Found a waypoint we're not at yet
              }
            }
        } catch (e) {
          // Pathfinding failed - generate simple road-based path
          print('⚠️ Pathfinding failed for truck ${truck.id} to warehouse: $e');
          // Generate a simple path along roads
          path = _generateSimpleRoadPath(currentX, currentY, warehouseRoadX, warehouseRoadY);
          pathIndex = 0;
        }
        }
        
        // Move along the path
        var currentPathIndex = pathIndex;
        var simX = currentX;
        var simY = currentY;
        var newStatus = currentStatus == TruckStatus.idle ? TruckStatus.traveling : currentStatus;

        // Ensure we have a valid path index
        if (currentPathIndex >= path.length && path.isNotEmpty) {
          currentPathIndex = path.length - 1;
        }
        
        // Process movement along path waypoints
        // Trucks MUST follow the path, not go straight
        if (path.isNotEmpty && currentPathIndex < path.length) {
          while (currentPathIndex < path.length) {
            final targetWaypoint = path[currentPathIndex];
            final dx = targetWaypoint.x - simX;
            final dy = targetWaypoint.y - simY;
            final distance = math.sqrt(dx * dx + dy * dy);
            
            // If very close to waypoint, snap to it and move to next
            if (distance < SimulationConstants.roadSnapThreshold) {
              simX = targetWaypoint.x;
              simY = targetWaypoint.y;
              currentPathIndex++;
              // Continue to next waypoint if we have movement budget
              continue;
            } else {
              // Move towards waypoint along the path
              final moveDistance = movementSpeed.clamp(0.0, distance);
              if (moveDistance > 0.0 && distance > 0.0) {
                final ratio = moveDistance / distance;
                simX += dx * ratio;
                simY += dy * ratio;
              }
              break; // Used movement budget for this tick
            }
          }
        } else if (path.isEmpty) {
          // No path - regenerate it
          try {
            final newPath = findPath(currentX, currentY, warehouseRoadX, warehouseRoadY);
            if (newPath.isNotEmpty) {
              path = newPath;
              currentPathIndex = 0;
              // Move towards first waypoint
              final targetWaypoint = path[0];
              final dx = targetWaypoint.x - simX;
              final dy = targetWaypoint.y - simY;
              final distance = math.sqrt(dx * dx + dy * dy);
              if (distance > SimulationConstants.roadSnapThreshold) {
                final moveDistance = movementSpeed.clamp(0.0, distance);
                if (moveDistance > 0.0 && distance > 0.0) {
                  final ratio = moveDistance / distance;
                  simX += dx * ratio;
                  simY += dy * ratio;
                }
              } else {
                simX = targetWaypoint.x;
                simY = targetWaypoint.y;
                currentPathIndex = 1;
              }
            }
          } catch (e) {
            print('⚠️ Failed to regenerate path: $e');
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
      final destinationIndex = machines.indexWhere((m) => m.id == destinationId);
      if (destinationIndex == -1 || machines.isEmpty) {
        // Machine not found - transition to idle or return to warehouse
        final warehouseRoadX = state.warehouseRoadX ?? 4.0;
        final warehouseRoadY = state.warehouseRoadY ?? 4.0;
        return truck.copyWith(
          status: TruckStatus.traveling,
          currentRouteIndex: truck.route.length, // Mark route as complete
          targetX: warehouseRoadX,
          targetY: warehouseRoadY,
          path: [],
          pathIndex: 0,
        );
      }
      final destination = machines[destinationIndex];

      // Get machine position and snap to nearest road
      final machineX = destination.zone.x;
      final machineY = destination.zone.y;
      
      // Find the closest valid road to the machine
      double destRoadX = _validRoads[0];
      double destRoadY = _validRoads[0];
      double minDist = double.infinity;
      
      // Check all valid road positions
      for (final roadX in _validRoads) {
        for (final roadY in _validRoads) {
          final dist = (machineX - roadX).abs() + (machineY - roadY).abs();
          if (dist < minDist) {
            minDist = dist;
            destRoadX = roadX;
            destRoadY = roadY;
          }
        }
      }
      
      // Also check if we can use a road line closer to machine
      for (final roadY in _validRoads) {
        final closestRoadX = _snapToNearestRoad(machineX);
        final dist = (machineX - closestRoadX).abs() + (machineY - roadY).abs();
        if (dist < minDist) {
          minDist = dist;
          destRoadX = closestRoadX;
          destRoadY = roadY;
        }
      }
      for (final roadX in _validRoads) {
        final closestRoadY = _snapToNearestRoad(machineY);
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
      if (manhattanDistance < SimulationConstants.roadSnapThreshold) {
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
        // Generate path through intersections
        try {
          path = findPath(currentX, currentY, destRoadX, destRoadY);
          pathIndex = 0;
          // Ensure path is not empty and has at least the destination
          if (path.isEmpty) {
            path = _generateSimpleRoadPath(currentX, currentY, destRoadX, destRoadY);
          }
          // If truck is already at waypoints, skip past them
          // But be careful not to skip too many waypoints
          while (pathIndex < path.length) {
            final waypoint = path[pathIndex];
            final distToWaypoint = math.sqrt(
              (waypoint.x - currentX) * (waypoint.x - currentX) + 
              (waypoint.y - currentY) * (waypoint.y - currentY)
            );
            if (distToWaypoint < SimulationConstants.roadSnapThreshold) {
              pathIndex++;
              if (pathIndex >= path.length) break;
            } else {
              break; // Found a waypoint we're not at yet
            }
          }
        } catch (e) {
          // Pathfinding failed - generate simple road-based path
          print('⚠️ Pathfinding failed for truck ${truck.id}: $e');
          // Generate a simple path along roads
          path = _generateSimpleRoadPath(currentX, currentY, destRoadX, destRoadY);
          pathIndex = 0;
        }
      }
      
      // Move along the path
      var currentPathIndex = pathIndex;
      var simX = currentX;
      var simY = currentY;
      var newStatus = TruckStatus.traveling;
      
      // Ensure we have a valid path index
      if (currentPathIndex >= path.length && path.isNotEmpty) {
        currentPathIndex = path.length - 1;
      }
      
      // Process movement along path waypoints
      // Trucks MUST follow the path, not go straight
      if (path.isNotEmpty && currentPathIndex < path.length) {
        while (currentPathIndex < path.length) {
          final targetWaypoint = path[currentPathIndex];
          final dx = targetWaypoint.x - simX;
          final dy = targetWaypoint.y - simY;
          final distance = math.sqrt(dx * dx + dy * dy);
          
          // If very close to waypoint, snap to it and move to next
          if (distance < SimulationConstants.roadSnapThreshold) {
            simX = targetWaypoint.x;
            simY = targetWaypoint.y;
            currentPathIndex++;
            // Continue to next waypoint if we have movement budget
            continue;
          } else {
            // Move towards waypoint along the path
            final moveDistance = movementSpeed.clamp(0.0, distance);
            if (moveDistance > 0.0 && distance > 0.0) {
              final ratio = moveDistance / distance;
              simX += dx * ratio;
              simY += dy * ratio;
            }
            break; // Used movement budget for this tick
          }
        }
      } else if (path.isEmpty) {
        // No path - regenerate it
        try {
          final newPath = findPath(currentX, currentY, destRoadX, destRoadY);
          if (newPath.isNotEmpty) {
            path = newPath;
            currentPathIndex = 0;
            // Move towards first waypoint
            final targetWaypoint = path[0];
            final dx = targetWaypoint.x - simX;
            final dy = targetWaypoint.y - simY;
            final distance = math.sqrt(dx * dx + dy * dy);
            if (distance > SimulationConstants.roadSnapThreshold) {
              final moveDistance = movementSpeed.clamp(0.0, distance);
              if (moveDistance > 0.0 && distance > 0.0) {
                final ratio = moveDistance / distance;
                simX += dx * ratio;
                simY += dy * ratio;
              }
            } else {
              simX = targetWaypoint.x;
              simY = targetWaypoint.y;
              currentPathIndex = 1;
            }
          }
        } catch (e) {
          print('⚠️ Failed to regenerate path: $e');
        }
      }
      
      // Check if reached destination
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
    } catch (e, stackTrace) {
      // Log error but return trucks as-is to prevent simulation from stopping
      print('❌ ERROR in _processTruckMovement: $e');
      print('Stack trace: $stackTrace');
      // Return trucks unchanged to prevent state corruption
      return trucks;
    }
  }

  /// Process fuel costs for trucks
  double _processFuelCosts(List<Truck> updatedTrucks, List<Truck> oldTrucks, double currentCash) {
    double totalFuelCost = 0.0;
    
    // Movement speed: 0.1 units per tick = 1 tile per second (matches truck movement speed)
    const double movementSpeed = 0.1;

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
      final machine1Index = machines.indexWhere((m) => m.id == machineIds[i]);
      final machine2Index = machines.indexWhere((m) => m.id == machineIds[i + 1]);
      if (machine1Index == -1 || machine2Index == -1) continue;
      
      final machine1 = machines[machine1Index];
      final machine2 = machines[machine2Index];

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
    try {
      var updatedMachines = List<Machine>.from(machines);
      var updatedTrucks = List<Truck>.from(trucks);
      final currentDay = state.time.day;

    for (int i = 0; i < updatedTrucks.length; i++) {
      final truck = updatedTrucks[i];
      
      // Only process trucks that are restocking
      // Also handle trucks that are stuck in restocking but route is complete
      if (truck.status != TruckStatus.restocking) continue;
      
      // If route is complete, immediately transition to traveling back to warehouse
      if (truck.isRouteComplete) {
        final warehouseRoadX = state.warehouseRoadX ?? 4.0;
        final warehouseRoadY = state.warehouseRoadY ?? 4.0;
        final roadX = _snapToNearestRoad(truck.currentX);
        final roadY = _snapToNearestRoad(truck.currentY);
        updatedTrucks[i] = truck.copyWith(
          status: TruckStatus.traveling,
          currentRouteIndex: truck.route.length,
          targetX: warehouseRoadX,
          targetY: warehouseRoadY,
          path: [],
          pathIndex: 0,
          currentX: roadX,
          currentY: roadY,
        );
        continue;
      }
      
      // Ensure truck stays on road (snap to nearest valid road coordinate)
      // Use _snapToNearestRoad helper to prevent trucks from being at invalid coordinates (0, 9, etc.)
      final roadX = _snapToNearestRoad(truck.currentX);
      final roadY = _snapToNearestRoad(truck.currentY);
      
      final destinationId = truck.currentDestination;
      if (destinationId == null) {
        // No destination - transition to traveling back to warehouse
        final warehouseRoadX = state.warehouseRoadX ?? 4.0;
        final warehouseRoadY = state.warehouseRoadY ?? 4.0;
        updatedTrucks[i] = truck.copyWith(
          status: TruckStatus.traveling,
          currentRouteIndex: truck.route.length,
          targetX: warehouseRoadX,
          targetY: warehouseRoadY,
          path: [],
          pathIndex: 0,
          currentX: roadX,
          currentY: roadY,
        );
        continue;
      }

      // Find the machine being restocked
      final machineIndex = updatedMachines.indexWhere((m) => m.id == destinationId);
      if (machineIndex == -1) {
        // Machine not found - transition to traveling back to warehouse
        final warehouseRoadX = state.warehouseRoadX ?? 4.0;
        final warehouseRoadY = state.warehouseRoadY ?? 4.0;
        updatedTrucks[i] = truck.copyWith(
          status: TruckStatus.traveling,
          currentRouteIndex: truck.route.length,
          targetX: warehouseRoadX,
          targetY: warehouseRoadY,
          path: [],
          pathIndex: 0,
          currentX: roadX,
          currentY: roadY,
        );
        continue;
      }

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

          // Check if product is allowed in this machine's zone type
          final allowedProducts = _getAllowedProductsForZone(machine.zone.type);
          if (!allowedProducts.contains(product)) {
            // Skip this product - not allowed in this zone type
            // Keep it in truck inventory for other machines
            itemsToTransfer[product] = truckQuantity;
            continue;
          }

          // Check current stock of this product in machine
          final currentProductStock = machineInventory[product]?.quantity ?? 0;
          final availableSpaceForProduct = maxItemsPerProduct - currentProductStock;
          
          if (availableSpaceForProduct <= 0) {
            // Machine is full for this product, keep it in truck
            itemsToTransfer[product] = truckQuantity;
            continue;
          }

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

          // Update truck inventory - keep remaining quantity
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
            final remainingMachineIndex = updatedMachines.indexWhere((m) => m.id == remainingMachineId);
            if (remainingMachineIndex == -1) continue; // Machine not found, skip
            
            final remainingMachine = updatedMachines[remainingMachineIndex];
            
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
            targetX: 0.0, // Will be set in movement processing
            targetY: 0.0, // Will be set in movement processing
            path: [], // Clear path so it recalculates
            pathIndex: 0,
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
        // Keep truck on road (snap to nearest valid road coordinate)
        final roadX = _snapToNearestRoad(truck.currentX);
        final roadY = _snapToNearestRoad(truck.currentY);
        final isTruckEmpty = truck.inventory.isEmpty;
        final hasMoreDestinations = truck.currentRouteIndex + 1 < truck.route.length;
        
        // Check if any remaining destinations need items from the truck
        bool remainingDestinationsNeedItems = false;
        if (!isTruckEmpty && hasMoreDestinations) {
          // Check remaining machines in route
          for (int routeIdx = truck.currentRouteIndex + 1; routeIdx < truck.route.length; routeIdx++) {
            final remainingMachineId = truck.route[routeIdx];
            final remainingMachineIndex = updatedMachines.indexWhere((m) => m.id == remainingMachineId);
            if (remainingMachineIndex == -1) continue; // Machine not found, skip
            
            final remainingMachine = updatedMachines[remainingMachineIndex];
            
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
    } catch (e, stackTrace) {
      // Log error but return current state to prevent simulation from stopping
      print('❌ ERROR in _processTruckRestocking: $e');
      print('Stack trace: $stackTrace');
      // Return trucks and machines as-is to prevent state corruption
      return (machines: machines, trucks: trucks);
    }
  }
}

