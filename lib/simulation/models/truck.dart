import 'package:freezed_annotation/freezed_annotation.dart';
import '../../config.dart';
import 'product.dart';

part 'truck.freezed.dart';

/// Truck status
enum TruckStatus {
  idle,
  traveling,
  restocking,
}

/// Represents a delivery truck
@freezed
abstract class Truck with _$Truck {
  const factory Truck({
    required String id,
    required String name,
    @Default(100.0) double fuel, // Percentage (0-100)
    @Default(AppConfig.truckMaxCapacity) int capacity, // Max items it can carry
    /// Current route: List of machine IDs to visit in order
    @Default([]) List<String> route,
    /// Pending route: Route changes saved while truck is moving (applied when truck becomes idle)
    @Default([]) List<String> pendingRoute,
    /// Current position in the route (index)
    @Default(0) int currentRouteIndex,
    @Default(TruckStatus.idle) TruckStatus status,
    /// Current position (x, y) on the grid
    @Default(0.0) double currentX,
    @Default(0.0) double currentY,
    /// Target position (x, y) when traveling
    @Default(0.0) double targetX,
    @Default(0.0) double targetY,
    /// Path waypoints for smooth movement (list of (x, y) positions)
    @Default([]) List<({double x, double y})> path,
    /// Current index in the path
    @Default(0) int pathIndex,
    @Default({}) Map<Product, int> inventory,
    @Default(false) bool hasDriver, // Whether truck has a driver for auto-restock
  }) = _Truck;

  const Truck._();

  /// Get current load (sum of inventory values)
  int get currentLoad {
    return inventory.values.fold<int>(0, (sum, quantity) => sum + quantity);
  }

  /// Check if truck has a route assigned
  bool get hasRoute => route.isNotEmpty;

  /// Get current destination machine ID
  String? get currentDestination {
    if (route.isEmpty || currentRouteIndex >= route.length) {
      return null;
    }
    return route[currentRouteIndex];
  }

  /// Check if truck has reached the end of its route
  bool get isRouteComplete {
    return route.isEmpty || currentRouteIndex >= route.length;
  }

  /// Calculate distance to target position
  double get distanceToTarget {
    final dx = targetX - currentX;
    final dy = targetY - currentY;
    return (dx * dx + dy * dy) * 0.5; // Euclidean distance
  }

  /// Check if truck has enough fuel for a distance
  bool hasEnoughFuel(double distance, double gasPrice) {
    final fuelNeeded = distance * gasPrice;
    return fuel >= fuelNeeded;
  }
}

