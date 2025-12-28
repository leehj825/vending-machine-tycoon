import 'dart:async';
import 'dart:math' as math;
import 'package:state_notifier/state_notifier.dart';
import '../config.dart';
import 'models/product.dart';
import 'models/machine.dart';
import 'models/truck.dart';
import 'models/zone.dart';

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
    );
  }
}

/// The Simulation Engine - The Heartbeat of the Game
class SimulationEngine extends StateNotifier<SimulationState> {
  Timer? _tickTimer;
  final StreamController<SimulationState> _streamController = StreamController<SimulationState>.broadcast();
  
  // Pathfinding optimization: cached base graph
  // UPDATED: Valid roads are only at indices 4 and 7 as per map layout
  static const List<double> _validRoads = [4.0, 7.0];
  static const List<double> _outwardRoads = []; // Cleared as we only use inner roads 4 and 7
  Map<({double x, double y}), List<({double x, double y})>>? _cachedBaseGraph;

  SimulationEngine({
    required List<Machine> initialMachines,
    required List<Truck> initialTrucks,
    double initialCash = 2000.0,
    int initialReputation = 100,
    double initialRushMultiplier = 1.0,
  }) : super(
          SimulationState(
            time: const GameTime(day: 1, hour: 8, minute: 0, tick: 1000), // 8:00 AM = 8 hours * 125 ticks/hour = 1000 ticks
            machines: initialMachines,
            trucks: initialTrucks,
            cash: initialCash,
            reputation: initialReputation,
            random: math.Random(),
            rushMultiplier: initialRushMultiplier,
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

  /// Update rush multiplier in the simulation
  void updateRushMultiplier(double multiplier) {
    print('🔴 ENGINE: Updating rush multiplier to $multiplier');
    state = state.copyWith(rushMultiplier: multiplier);
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
    double rushMultiplier = 1.0,
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
  Map<({double x, double y}), List<({double x, double y})>> _getBaseGraph() {
    if (_cachedBaseGraph != null) return _cachedBaseGraph!;

    final graph = <({double x, double y}), List<({double x, double y})>>{};
    
    // Helper to check if a coordinate is on an outward road
    bool isOutwardRoad(double coord) => _outwardRoads.contains(coord);
    
    // Build basic grid graph (intersections)
    for (final roadX in _validRoads) {
      for (final roadY in _validRoads) {
        final node = (x: roadX, y: roadY);
        graph[node] = [];
        
        // Connect horizontally
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
        
        // Connect vertically
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
    return graph;
  }

  /// Helper to find nearest point on the road network from any coordinate
  /// This projects the point perpendicularly onto the nearest road.
  ({double x, double y}) _getNearestRoadPoint(double x, double y) {
    double minDist = double.infinity;
    var bestPoint = (x: x, y: y);

    // Check vertical roads (fixed X)
    for (final roadX in _validRoads) {
      final dist = (x - roadX).abs();
      if (dist < minDist) {
        minDist = dist;
        bestPoint = (x: roadX, y: y);
      }
    }

    // Check horizontal roads (fixed Y)
    for (final roadY in _validRoads) {
      final dist = (y - roadY).abs();
      if (dist < minDist) { 
        minDist = dist;
        bestPoint = (x: x, y: roadY);
      }
    }
    return bestPoint;
  }

  /// Main tick function - called every 1 second (10 minutes in-game)
  void _tick() {
    final currentState = state;
    
    // DEBUG PRINT
    print('🔴 ENGINE TICK: Day ${currentState.time.day} ${currentState.time.hour}:00 | Machines: ${currentState.machines.length} | Cash: \$${currentState.cash.toStringAsFixed(2)}');

    final nextTime = currentState.time.nextTick();

    // 1. Process Sales (with reputation bonus and rush multiplier)
    final salesResult = _processMachineSales(currentState.machines, nextTime, currentState.reputation);
    var updatedMachines = salesResult.machines;
    final totalSalesThisTick = salesResult.totalSales;
    
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
    final reputationGain = totalSalesThisTick * SimulationConstants.reputationGainPerSale;
    var updatedReputation = ((currentState.reputation - reputationPenalty + reputationGain).clamp(0, 1000)).round();
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
      // Skip sales processing if machine is under maintenance
      if (machine.isUnderMaintenance) {
        // Debug: Only this specific machine is paused
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

      // Process each product type
      for (final product in Product.values) {
        final stock = machine.getStock(product);
        if (stock == 0) continue;

        // Get current inventory item
        final item = updatedInventory[product]!;
        
        // Calculate sale chance using the demand formula
        final baseDemand = product.baseDemand;
        final zoneMultiplier = machine.zone.getDemandMultiplier(time.hour);
        final trafficMultiplier = machine.zone.trafficMultiplier;
        
        // Apply reputation bonus and rush multiplier (calculated once per tick, reused for all products)
        final saleChancePerHour = baseDemand * zoneMultiplier * trafficMultiplier * reputationMultiplier * rushMultiplier;
        final saleChance = saleChancePerHour / SimulationConstants.ticksPerHour; // Divide by ticksPerHour to get chance per tick
        
        // Clamp to reasonable range (0.0 to 1.0)
        final clampedChance = saleChance.clamp(0.0, 1.0);

        // Accumulator approach: Add probability to sales progress
        final newSalesProgress = item.salesProgress + clampedChance;

        // Check if we've accumulated enough interest for a sale
        if (newSalesProgress >= 1.0) {
          // Sale occurred!
          final newQuantity = item.quantity - 1;
          final remainingProgress = newSalesProgress - 1.0; // Carry over remainder
          
          if (newQuantity > 0) {
            updatedInventory[product] = item.copyWith(
              quantity: newQuantity,
              salesProgress: remainingProgress,
            );
          } else {
            // Item sold out, remove from inventory (don't carry progress to empty slot)
            updatedInventory.remove(product);
          }

          updatedCash += product.basePrice;
          salesCount++;
          totalSales++; // Track total sales for reputation gain
        } else {
          // No sale yet, just update the progress
          updatedInventory[product] = item.copyWith(salesProgress: newSalesProgress);
        }
      }

      // Update hours since restock
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
    // Movement speed: 0.1 units per tick = 1 tile per second (10 ticks per second)
    const double movementSpeed = AppConfig.movementSpeed;
    
    // A* pathfinding to find shortest path through road network
    List<({double x, double y})> findPath(
      double startX, double startY,
      double endX, double endY,
    ) {
      final start = (x: startX, y: startY);
      final end = (x: endX, y: endY);
      
      // If start and end are close enough (e.g. moving slightly on same spot), just go direct
      if ((start.x - end.x).abs() < SimulationConstants.roadSnapThreshold && 
          (start.y - end.y).abs() < SimulationConstants.roadSnapThreshold) {
        return [end];
      }
      
      // 1. Get Base Graph (Intersections)
      final baseGraph = _getBaseGraph();
      final graph = Map<({double x, double y}), List<({double x, double y})>>.from(
        baseGraph.map((key, value) => MapEntry(key, List<({double x, double y})>.from(value))),
      );
      
      // 2. Identify Entry and Exit points on the road network
      // Use helper to project current/target position onto nearest road line
      final startEntry = _getNearestRoadPoint(startX, startY);
      final endExit = _getNearestRoadPoint(endX, endY);
      
      // 3. Connect START point to ENTRY point (if different)
      if (startEntry != start) {
        // Connect Start -> StartEntry
        graph[start] = [startEntry];
        if (!graph.containsKey(startEntry)) graph[startEntry] = [];
        graph[startEntry]!.add(start); // Undirected for consistency
      } else {
        // Start IS on the road, ensure it's in the graph
        if (!graph.containsKey(start)) graph[start] = [];
      }

      // 4. Connect END point to EXIT point (if different)
      if (endExit != end) {
         if (!graph.containsKey(endExit)) graph[endExit] = [];
         graph[endExit]!.add(end);
         graph[end] = [endExit];
      } else {
         if (!graph.containsKey(end)) graph[end] = [];
      }

      // 5. Connect Entry/Exit points to the rest of the road network
      // Helper to connect a road point to its neighbors on the same road line
      void connectToRoadNetwork(({double x, double y}) point) {
        if (baseGraph.containsKey(point)) return; // Already an intersection

        // Check if on a vertical road (X is a valid road X)
        if (_validRoads.contains(point.x)) {
           // Connect to all intersections on this vertical line
           for (final rY in _validRoads) {
             final neighbor = (x: point.x, y: rY);
             // Ensure neighbor exists in base graph or is effectively a node
             if (!graph.containsKey(neighbor)) graph[neighbor] = [];
             
             // Add edges
             if (!graph[point]!.contains(neighbor)) graph[point]!.add(neighbor);
             if (!graph[neighbor]!.contains(point)) graph[neighbor]!.add(point);
           }
        }
        
        // Check if on a horizontal road (Y is a valid road Y)
        if (_validRoads.contains(point.y)) {
           // Connect to all intersections on this horizontal line
           for (final rX in _validRoads) {
             final neighbor = (x: rX, y: point.y);
             if (!graph.containsKey(neighbor)) graph[neighbor] = [];
             
             if (!graph[point]!.contains(neighbor)) graph[point]!.add(neighbor);
             if (!graph[neighbor]!.contains(point)) graph[neighbor]!.add(point);
           }
        }
      }

      connectToRoadNetwork(startEntry);
      connectToRoadNetwork(endExit);

      // 6. Direct connection check: If Entry and Exit are on the same road segment, connect them
      bool sameVertical = (startEntry.x == endExit.x) && _validRoads.contains(startEntry.x);
      bool sameHorizontal = (startEntry.y == endExit.y) && _validRoads.contains(startEntry.y);
      
      if (sameVertical || sameHorizontal) {
          if (!graph[startEntry]!.contains(endExit)) graph[startEntry]!.add(endExit);
          if (!graph[endExit]!.contains(startEntry)) graph[endExit]!.add(startEntry);
      }

      // A* Algorithm
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
          // Reconstruct path
          final path = <({double x, double y})>[end];
          var node = current;
          while (cameFrom.containsKey(node)) {
            node = cameFrom[node]!;
            if (node == start) break; // Don't include start in path
            path.insert(0, node);
          }
          if (path.isEmpty || path.last != end) path.add(end);
          return path;
        }
        
        openSet.remove(current);
        final neighbors = graph[current] ?? [];
        
        for (final neighbor in neighbors) {
          // Manhattan distance as edge cost
          double edgeCost = (neighbor.x - current.x).abs() + (neighbor.y - current.y).abs();
          
          final tentativeG = (gScore[current] ?? double.infinity) + edgeCost;
          
          if (tentativeG < (gScore[neighbor] ?? double.infinity)) {
            cameFrom[neighbor] = current;
            gScore[neighbor] = tentativeG;
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
      // If truck is idle, don't process movement - truck only moves when explicitly started via "Go Stock"
      if (truck.status == TruckStatus.idle) {
        return truck; // Return truck unchanged
      }
      
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
        
        // If already very close to warehouse, mark as Idle
        if (distanceToWarehouse < SimulationConstants.roadSnapThreshold) {
          return truck.copyWith(
            status: TruckStatus.idle,
            currentX: warehouseRoadX,
            currentY: warehouseRoadY,
            targetX: warehouseRoadX,
            targetY: warehouseRoadY,
            path: [],
            pathIndex: 0,
            currentRouteIndex: truck.route.length, 
          );
        }
        
        // Not at warehouse yet - calculate movement
        List<({double x, double y})> path = truck.path;
        int pathIndex = truck.pathIndex;
        
        // Recalculate path if needed
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

        // Process movement
        while (currentPathIndex < path.length) {
          final targetWaypoint = path[currentPathIndex];
          final dx = targetWaypoint.x - simX;
          final dy = targetWaypoint.y - simY;
          final distance = math.sqrt(dx * dx + dy * dy);
          
        if (distance < SimulationConstants.roadSnapThreshold) {
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
      
      final destinationId = truck.currentDestination;
      
      if (destinationId == null) {
        return truck.copyWith(status: TruckStatus.idle);
      }

      final destination = machines.firstWhere(
        (m) => m.id == destinationId,
        orElse: () => machines.first,
      );

      final machineX = destination.zone.x;
      final machineY = destination.zone.y;
      
      // Find the correct stopping point on the road for this machine
      final destPoint = _getNearestRoadPoint(machineX, machineY);
      final destRoadX = destPoint.x;
      final destRoadY = destPoint.y;
      
      // Calculate distance to destination road point
      final currentX = truck.currentX;
      final currentY = truck.currentY;
      final dxToRoad = destRoadX - currentX;
      final dyToRoad = destRoadY - currentY;
      final manhattanDistance = dxToRoad.abs() + dyToRoad.abs();

      // If truck is at the road stopping point, mark as arrived for restocking
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

      // Get or calculate path to destination road point
      List<({double x, double y})> path = truck.path;
      int pathIndex = truck.pathIndex;
      
      // Recalculate path if needed
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
        
        if (distance < SimulationConstants.roadSnapThreshold) {
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
            itemsToTransfer[product] = truckQuantity;
            continue;
          }

          // Check current stock of this product in machine
          final currentProductStock = machineInventory[product]?.quantity ?? 0;
          final availableSpaceForProduct = maxItemsPerProduct - currentProductStock;
          
          if (availableSpaceForProduct <= 0) {
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
            final remainingMachine = updatedMachines.firstWhere(
              (m) => m.id == remainingMachineId,
              orElse: () => updatedMachines.first, 
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

        // Update machine
        updatedMachines[machineIndex] = machine.copyWith(
          inventory: machineInventory,
          hoursSinceRestock: 0.0,
        );
      } else {
        // No items transferred (machine already full or truck empty)
        // Calculate target road coordinates for this machine
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
        final roadX = isCloseEnough ? targetRoadX : truck.currentX;
        final roadY = isCloseEnough ? targetRoadY : truck.currentY;
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
              orElse: () => updatedMachines.first, 
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
        final warehouseRoadX = state.warehouseRoadX ?? 4.0;
        final warehouseRoadY = state.warehouseRoadY ?? 4.0;
        
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
