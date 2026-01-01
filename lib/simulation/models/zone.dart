import 'package:freezed_annotation/freezed_annotation.dart';
import 'product.dart';

part 'zone.freezed.dart';

/// Zone types in the city
enum ZoneType {
  shop,
  school,
  gym,
  office,
  subway,
  hospital,
  university,
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
      case ZoneType.subway:
        return [Product.coffee, Product.chips, Product.newspaper];
      case ZoneType.hospital:
        return [Product.coffee, Product.sandwich, Product.freshSalad];
      case ZoneType.university:
        return [Product.coffee, Product.energyDrink, Product.techGadget];
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

  static Zone createSubway({
    required String id,
    required String name,
    required double x,
    required double y,
  }) {
    return Zone(
      id: id,
      type: ZoneType.subway,
      name: name,
      x: x,
      y: y,
      demandCurve: {
        7: 3.0,   // 7 AM: Morning rush hour spike
        8: 3.5,   // 8 AM: Peak morning rush
        9: 3.0,   // 9 AM: End of morning rush
        17: 3.5,  // 5 PM: Peak evening rush
        18: 3.0,  // 6 PM: Evening rush
        19: 2.0,  // 7 PM: End of evening rush
        0: 0.1,   // Midnight: Dead silence
        1: 0.1,   // 1 AM: Dead silence
        2: 0.1,   // 2 AM: Dead silence
        3: 0.1,   // 3 AM: Dead silence
        4: 0.1,   // 4 AM: Dead silence
        5: 0.1,   // 5 AM: Dead silence
        6: 0.1,   // 6 AM: Dead silence
        10: 0.2,  // 10 AM: Dead silence
        11: 0.2,  // 11 AM: Dead silence
        12: 0.3,  // 12 PM: Minimal
        13: 0.2,  // 1 PM: Dead silence
        14: 0.2,  // 2 PM: Dead silence
        15: 0.2,  // 3 PM: Dead silence
        16: 0.2,  // 4 PM: Dead silence
        20: 0.2,  // 8 PM: Dead silence
        21: 0.1,  // 9 PM: Dead silence
        22: 0.1,  // 10 PM: Dead silence
        23: 0.1,  // 11 PM: Dead silence
      },
      trafficMultiplier: 1.5,
    );
  }

  static Zone createHospital({
    required String id,
    required String name,
    required double x,
    required double y,
  }) {
    // Flat demand curve: steady 0.8x - 1.0x demand 24 hours a day
    return Zone(
      id: id,
      type: ZoneType.hospital,
      name: name,
      x: x,
      y: y,
      demandCurve: {
        0: 0.9,   // Midnight: Steady
        1: 0.85,  // 1 AM: Steady
        2: 0.8,   // 2 AM: Steady
        3: 0.8,   // 3 AM: Steady
        4: 0.85,  // 4 AM: Steady
        5: 0.9,   // 5 AM: Steady
        6: 0.95,  // 6 AM: Steady
        7: 1.0,   // 7 AM: Steady
        8: 1.0,   // 8 AM: Steady
        9: 0.95,  // 9 AM: Steady
        10: 0.95, // 10 AM: Steady
        11: 0.95, // 11 AM: Steady
        12: 1.0,  // 12 PM: Steady
        13: 0.95, // 1 PM: Steady
        14: 0.95, // 2 PM: Steady
        15: 0.95, // 3 PM: Steady
        16: 0.95, // 4 PM: Steady
        17: 0.95, // 5 PM: Steady
        18: 0.95, // 6 PM: Steady
        19: 0.9,  // 7 PM: Steady
        20: 0.9,  // 8 PM: Steady
        21: 0.85, // 9 PM: Steady
        22: 0.85, // 10 PM: Steady
        23: 0.85, // 11 PM: Steady
      },
      trafficMultiplier: 1.0,
    );
  }

  static Zone createUniversity({
    required String id,
    required String name,
    required double x,
    required double y,
  }) {
    return Zone(
      id: id,
      type: ZoneType.university,
      name: name,
      x: x,
      y: y,
      demandCurve: {
        8: 1.8,   // 8 AM: Morning classes
        10: 1.5,  // 10 AM: Mid-morning
        12: 2.0,  // 12 PM: Lunch peak
        13: 1.8,  // 1 PM: Afternoon
        14: 1.8,  // 2 PM: Afternoon classes
        15: 1.6,  // 3 PM: Afternoon
        16: 1.4,  // 4 PM: Late afternoon
        17: 1.2,  // 5 PM: Evening
        18: 1.0,  // 6 PM: Evening
        19: 1.0,  // 7 PM: Evening
        20: 1.2,  // 8 PM: Study time
        21: 1.4,  // 9 PM: Study time
        22: 1.6,  // 10 PM: Study time
        23: 2.0,  // 11 PM: All-nighter spike (Exam Season)
        0: 2.2,   // Midnight: All-nighter peak
        1: 2.0,   // 1 AM: All-nighter
        2: 1.8,   // 2 AM: All-nighter
        3: 0.8,   // 3 AM: Winding down
        4: 0.5,   // 4 AM: Sleep
        5: 0.3,   // 5 AM: Sleep
        6: 0.5,   // 6 AM: Early morning
        7: 1.0,   // 7 AM: Morning
      },
      trafficMultiplier: 1.1,
    );
  }
}

