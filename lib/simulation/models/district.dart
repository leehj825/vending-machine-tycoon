import 'dart:math' as math;

import '../../config.dart';

/// A ring of the city, unlocked outward from the center.
///
/// The city map itself never changes shape or grows new tiles - all three
/// districts sit on the same fixed grid that already exists. What "expanding"
/// means here is unlocking the ability to buy a new machine at a build spot
/// that falls in an outer ring; any machine already standing there (e.g. from
/// a save made before this feature existed) keeps working regardless of
/// unlock state - only new purchases are gated.
enum DistrictId {
  core,
  suburban,
  outer,
}

/// Static data for a district: what it costs to unlock and what it's worth.
class DistrictData {
  final DistrictId id;
  final String name;
  final String description;
  final double unlockCost;

  /// Extra traffic multiplier applied on top of a zone's own traffic
  /// multiplier for every machine standing in this district - representing a
  /// growth market with less competition than the crowded city core.
  final double trafficBonusMultiplier;

  const DistrictData({
    required this.id,
    required this.name,
    required this.description,
    required this.unlockCost,
    required this.trafficBonusMultiplier,
  });

  static const List<DistrictData> all = [
    DistrictData(
      id: DistrictId.core,
      name: 'Downtown Core',
      description: 'The original city blocks around your warehouse. Free to build in from day one.',
      unlockCost: 0.0,
      trafficBonusMultiplier: 1.0,
    ),
    DistrictData(
      id: DistrictId.suburban,
      name: 'Suburban Expansion',
      description: 'The ring of blocks just outside downtown - less crowded, a little more foot traffic per machine.',
      unlockCost: AppConfig.districtSuburbanUnlockCost,
      trafficBonusMultiplier: AppConfig.districtSuburbanTrafficBonus,
    ),
    DistrictData(
      id: DistrictId.outer,
      name: 'Outer Limits',
      description: 'The edge of the map. Expensive to break into, but a wide open market once you do.',
      unlockCost: AppConfig.districtOuterUnlockCost,
      trafficBonusMultiplier: AppConfig.districtOuterTrafficBonus,
    ),
  ];

  static DistrictData getById(DistrictId id) {
    return all.firstWhere((d) => d.id == id);
  }
}

/// Pure district geometry, kept separate from the UI/engine so it can be unit
/// tested without a running game.
class DistrictMath {
  const DistrictMath._();

  /// Which district a grid cell belongs to, based on Chebyshev (chessboard)
  /// distance from the center of a [gridSize] x [gridSize] grid. Chebyshev
  /// distance keeps the rings square, matching the square grid the city
  /// already renders on.
  static DistrictId districtForGridPosition({
    required int gridX,
    required int gridY,
    required int gridSize,
  }) {
    final center = (gridSize - 1) / 2.0;
    final distance = math.max(
      (gridX - center).abs(),
      (gridY - center).abs(),
    );

    if (distance <= AppConfig.districtCoreRadius) return DistrictId.core;
    if (distance <= AppConfig.districtSuburbanRadius) return DistrictId.suburban;
    return DistrictId.outer;
  }

  /// Same lookup, but from the zone coordinates a [Machine] actually stores
  /// (zoneX = gridX + 1.5, zoneY = gridY + 1.5 - see tile_city_screen.dart's
  /// _handleBuildingTap/_zoneToGrid for the canonical conversion).
  static DistrictId districtForZonePosition({
    required double zoneX,
    required double zoneY,
    required int gridSize,
  }) {
    return districtForGridPosition(
      gridX: (zoneX - 1.5).round(),
      gridY: (zoneY - 1.5).round(),
      gridSize: gridSize,
    );
  }
}
