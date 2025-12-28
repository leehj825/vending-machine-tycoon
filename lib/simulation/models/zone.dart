import 'package:freezed_annotation/freezed_annotation.dart';
import 'product.dart';

part 'zone.freezed.dart';

/// Zone types in the city
enum ZoneType {
  shop,
  school,
  gym,
  office,
}

/// Represents a location zone with demand multipliers
@freezed
abstract class Zone with _$Zone {
  const factory Zone({
    required String id,
    required ZoneType type,
    required String name,
    required double x, // Grid position X
    required double y, // Grid position Y
    /// Demand curve: Map of hour (0-23) to multiplier
    /// Example: {8: 2.0, 14: 1.5, 20: 0.1} means 2.0x at 8 AM, 1.5x at 2 PM, 0.1x at 8 PM
    @Default({}) Map<int, double> demandCurve,
    /// Base traffic multiplier (0.5 to 2.0)
    @Default(1.0) double trafficMultiplier,
  }) = _Zone;

  const Zone._();

  /// Get allowed products for a zone type
  static List<Product> getAllowedProducts(ZoneType type) {
    switch (type) {
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

  /// Get demand multiplier for a specific hour
  /// Interpolates between defined hours in the demand curve
  double getDemandMultiplier(int hour) {
    if (demandCurve.isEmpty) return 1.0;
    
    // Exact match
    if (demandCurve.containsKey(hour)) {
      return demandCurve[hour]!;
    }
    
    // Find nearest hours for interpolation
    int? lowerHour;
    int? upperHour;
    
    for (final key in demandCurve.keys) {
      if (key < hour && (lowerHour == null || key > lowerHour)) {
        lowerHour = key;
      }
      if (key > hour && (upperHour == null || key < upperHour)) {
        upperHour = key;
      }
    }
    
    // If only one side exists, use that value
    if (lowerHour != null && upperHour == null) {
      return demandCurve[lowerHour]!;
    }
    if (upperHour != null && lowerHour == null) {
      return demandCurve[upperHour]!;
    }
    
    // Interpolate between two points
    if (lowerHour != null && upperHour != null) {
      final lowerValue = demandCurve[lowerHour]!;
      final upperValue = demandCurve[upperHour]!;
      final ratio = (hour - lowerHour) / (upperHour - lowerHour);
      return lowerValue + (upperValue - lowerValue) * ratio;
    }
    
    // Default fallback
    return 1.0;
  }
}

/// Factory functions for common zone types
class ZoneFactory {
  static Zone createOffice({
    required String id,
    required String name,
    required double x,
    required double y,
  }) {
    return Zone(
      id: id,
      type: ZoneType.office,
      name: name,
      x: x,
      y: y,
      demandCurve: {
        8: 2.0,   // 8 AM: Peak coffee demand
        10: 1.2,  // 10 AM: Still high
        12: 1.5,  // 12 PM: Lunch rush
        14: 1.5,  // 2 PM: Post-lunch coffee
        16: 1.0,  // 4 PM: Normal
        18: 0.5,  // 6 PM: Winding down
        20: 0.1,  // 8 PM: Dead
      },
      trafficMultiplier: 1.2,
    );
  }

  static Zone createSchool({
    required String id,
    required String name,
    required double x,
    required double y,
  }) {
    return Zone(
      id: id,
      type: ZoneType.school,
      name: name,
      x: x,
      y: y,
      demandCurve: {
        7: 1.8,   // 7 AM: Before school
        12: 2.0,  // 12 PM: Lunch peak
        15: 1.5,  // 3 PM: After school
        18: 0.3,  // 6 PM: Empty
      },
      trafficMultiplier: 1.0,
    );
  }

  static Zone createGym({
    required String id,
    required String name,
    required double x,
    required double y,
  }) {
    return Zone(
      id: id,
      type: ZoneType.gym,
      name: name,
      x: x,
      y: y,
      demandCurve: {
        6: 1.5,   // 6 AM: Morning workout
        12: 1.2,  // 12 PM: Lunch workout
        18: 2.0,  // 6 PM: Evening peak
        21: 1.5,  // 9 PM: Late evening
      },
      trafficMultiplier: 0.9,
    );
  }

  static Zone createShop({
    required String id,
    required String name,
    required double x,
    required double y,
  }) {
    return Zone(
      id: id,
      type: ZoneType.shop,
      name: name,
      x: x,
      y: y,
      demandCurve: {
        10: 1.5,  // 10 AM: Morning shoppers
        12: 2.0,  // 12 PM: Lunch rush
        15: 1.8,  // 3 PM: Afternoon shopping
        18: 1.5,  // 6 PM: Evening shoppers
        20: 1.0,  // 8 PM: Normal
        22: 0.5,  // 10 PM: Late night
      },
      trafficMultiplier: 1.2,
    );
  }
}

