import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../simulation/models/machine.dart' as sim;
import '../screens/tile_city_screen.dart' show RoadDirection, TileType;
import '../theme/zone_ui.dart';
import 'lowpoly_engine.dart';

/// Tap target for one cell of the 3D city.
class CityCell {
  const CityCell(this.x, this.y, this.tileType);

  final int x;
  final int y;
  final TileType tileType;
}

const Color cityDaySky = Color(0xFFA7D8F2);
const Color cityNightSky = Color(0xFF0E1A2E);
const double cityNightBrightness = 0.55;

const Color _earth = Color(0xFF6B5B45);
const Color _grassA = Color(0xFF7CC26A);
const Color _grassB = Color(0xFF69B05A);
const Color _asphalt = Color(0xFF4A4F57);
const Color _lane = Color(0xFFF2F2F2);
const Color _trunk = Color(0xFF7A5230);
const Color _foliage = Color(0xFF3F9142);
const Color _glass = Color(0xFFBFE7F2);
const Color _white = Color(0xFFF5F7FA);
const Color _red = Color(0xFFE53935);
const Color _grey = Color(0xFF9AA5B1);
const Color _darkGrey = Color(0xFF4B5563);

/// Default camera: a three-quarter view looking down on the whole grid.
LowPolyCamera defaultCityCamera(int gridSize) => LowPolyCamera(
      target: Vec3(gridSize / 2, 0, gridSize / 2),
      yaw: math.pi / 4,
      pitch: 0.85,
      distance: gridSize * 1.1,
    );

/// Builds the lowpoly city from the same grid the 2D map uses.
///
/// Ground tiles come first in list order, so their flat pieces never sort.
/// Buildings, trees and vending machines are standing objects sorted by depth.
List<LowPolyObject> buildCityScene({
  required List<List<TileType>> grid,
  required List<List<RoadDirection?>> roadDirections,
  required List<sim.Machine> machines,
  required double brightness,
}) {
  final size = grid.length;
  final objects = <LowPolyObject>[];

  final slab = LowPolyMeshBuilder(brightness: brightness)
    ..flat(-0.4, -0.4, size + 0.4, size + 0.4, -0.05, _earth);
  objects.add(slab.build(center: Vec3(size / 2, -0.05, size / 2), onGround: true));

  for (var y = 0; y < size; y++) {
    final row = grid[y];
    for (var x = 0; x < row.length; x++) {
      final type = row[x];
      final road = y < roadDirections.length && x < roadDirections[y].length
          ? roadDirections[y][x]
          : null;
      objects.add(_groundTile(brightness, x, y, type, road));
      objects.addAll(_buildingObjects(brightness, x, y, type));
    }
  }

  for (final machine in machines) {
    final gx = math.min(math.max((machine.zone.x - 1).floor(), 0), size - 1);
    final gy = math.min(math.max((machine.zone.y - 1).floor(), 0), size - 1);
    final cell = CityCell(gx, gy, grid[gy][gx]);
    objects.add(_vendingMachineOnTile(brightness, machine, gx, gy, cell));
  }

  return objects;
}

/// Deterministic 0..1 value per cell, so grass varies without flickering.
double _cellNoise(int x, int y) => ((x * 73 + y * 151 + x * y * 31) % 97) / 96.0;

LowPolyObject _groundTile(
  double brightness,
  int x,
  int y,
  TileType type,
  RoadDirection? road,
) {
  final m = LowPolyMeshBuilder(brightness: brightness);
  if (type == TileType.road) {
    m.flat(x + 0.0, y + 0.0, x + 1.0, y + 1.0, 0.0, _asphalt);
    if (road == RoadDirection.vertical) {
      m.flat(x + 0.47, y + 0.1, x + 0.53, y + 0.9, 0.004, _lane);
    } else if (road == RoadDirection.horizontal) {
      m.flat(x + 0.1, y + 0.47, x + 0.9, y + 0.53, 0.004, _lane);
    }
  } else {
    final grass = Color.lerp(_grassA, _grassB, _cellNoise(x, y)) ?? _grassA;
    m.flat(x + 0.0, y + 0.0, x + 1.0, y + 1.0, 0.0, grass);
  }
  return m.build(center: Vec3(x + 0.5, 0, y + 0.5), onGround: true);
}

/// Standing geometry for a tile. Parks return one object per tree, and every
/// other building returns one object with its parts listed back to front.
List<LowPolyObject> _buildingObjects(
  double brightness,
  int x,
  int y,
  TileType type,
) {
  if (type == TileType.grass || type == TileType.road) return [];

  final cell = CityCell(x, y, type);

  if (type == TileType.park) {
    const trees = [
      (0.28, 0.3),
      (0.72, 0.34),
      (0.5, 0.72),
    ];
    final objects = <LowPolyObject>[];
    for (final (tx, tz) in trees) {
      final m = LowPolyMeshBuilder(brightness: brightness)
        ..box(x + tx - 0.04, 0, y + tz - 0.04, x + tx + 0.04, 0.22, y + tz + 0.04, _trunk)
        ..cone(x + tx, y + tz, 0.2, 6, 0.18, 0.62, _foliage);
      objects.add(m.build(center: Vec3(x + tx, 0.35, y + tz), payload: cell));
    }
    return objects;
  }

  final m = LowPolyMeshBuilder(brightness: brightness);
  switch (type) {
    case TileType.shop:
      m
        ..box(x + 0.1, 0, y + 0.12, x + 0.9, 0.55, y + 0.88, const Color(0xFFF2C14E),
            top: const Color(0xFF8D6E63))
        ..box(x + 0.25, 0.18, y + 0.86, x + 0.75, 0.36, y + 0.9, _glass)
        ..box(x + 0.06, 0.42, y + 0.84, x + 0.94, 0.52, y + 0.94, const Color(0xFFE4572E));
      break;
    case TileType.gym:
      m
        ..box(x + 0.08, 0, y + 0.1, x + 0.92, 0.7, y + 0.9, const Color(0xFFB5523B),
            top: const Color(0xFF6B7280))
        ..box(x + 0.2, 0.42, y + 0.9, x + 0.8, 0.52, y + 0.93, _glass)
        ..box(x + 0.35, 0.7, y + 0.35, x + 0.65, 0.8, y + 0.65, _darkGrey);
      break;
    case TileType.office:
      m
        ..box(x + 0.2, 0, y + 0.2, x + 0.8, 1.5, y + 0.8, const Color(0xFF8FB8DE),
            top: const Color(0xFF3D5A80))
        ..box(x + 0.18, 0.45, y + 0.18, x + 0.82, 0.5, y + 0.82, const Color(0xFFE0ECF7))
        ..box(x + 0.18, 0.95, y + 0.18, x + 0.82, 1.0, y + 0.82, const Color(0xFFE0ECF7))
        ..box(x + 0.3, 1.5, y + 0.3, x + 0.7, 1.62, y + 0.7, const Color(0xFF3D5A80));
      break;
    case TileType.school:
      m
        ..box(x + 0.1, 0, y + 0.12, x + 0.9, 0.5, y + 0.88, const Color(0xFFF4E3B5))
        ..box(x + 0.4, 0, y + 0.86, x + 0.6, 0.22, y + 0.9, const Color(0xFF6D4C41))
        ..roof(x + 0.08, y + 0.1, x + 0.92, y + 0.9, 0.5, 0.8, const Color(0xFFC0392B));
      break;
    case TileType.gasStation:
      const pillar = Color(0xFFB0BEC5);
      m
        ..box(x + 0.36, 0, y + 0.36, x + 0.64, 0.36, y + 0.64, _white)
        ..box(x + 0.1, 0, y + 0.1, x + 0.16, 0.5, y + 0.16, pillar)
        ..box(x + 0.84, 0, y + 0.1, x + 0.9, 0.5, y + 0.16, pillar)
        ..box(x + 0.1, 0, y + 0.84, x + 0.16, 0.5, y + 0.9, pillar)
        ..box(x + 0.84, 0, y + 0.84, x + 0.9, 0.5, y + 0.9, pillar)
        ..box(x + 0.04, 0.5, y + 0.04, x + 0.96, 0.6, y + 0.96, const Color(0xFFE53935),
            top: const Color(0xFFFF7043));
      break;
    case TileType.house:
      m
        ..box(x + 0.2, 0, y + 0.25, x + 0.8, 0.42, y + 0.8, const Color(0xFFF6D7B0))
        ..box(x + 0.44, 0, y + 0.8, x + 0.56, 0.22, y + 0.84, const Color(0xFF6D4C41))
        ..roof(x + 0.14, y + 0.19, x + 0.86, y + 0.86, 0.42, 0.7, const Color(0xFFB23A48));
      break;
    case TileType.warehouse:
      m
        ..box(x + 0.04, 0, y + 0.12, x + 0.96, 0.5, y + 0.9, _grey, top: const Color(0xFF6B7785))
        ..box(x + 0.28, 0, y + 0.9, x + 0.72, 0.36, y + 0.94, _darkGrey);
      break;
    case TileType.subway:
      m
        ..box(x + 0.1, 0, y + 0.14, x + 0.9, 0.32, y + 0.86, const Color(0xFF3F6E9A),
            top: const Color(0xFF2E5A80))
        ..box(x + 0.36, 0.32, y + 0.6, x + 0.64, 0.56, y + 0.86, const Color(0xFFA7D8F0))
        ..box(x + 0.4, 0.56, y + 0.62, x + 0.6, 0.6, y + 0.84, const Color(0xFFFFD54F));
      break;
    case TileType.hospital:
      m
        ..box(x + 0.1, 0, y + 0.1, x + 0.9, 0.9, y + 0.9, _white, top: const Color(0xFFE3E8EF))
        ..box(x + 0.42, 0.9, y + 0.28, x + 0.58, 0.94, y + 0.72, _red)
        ..box(x + 0.28, 0.9, y + 0.42, x + 0.72, 0.94, y + 0.58, _red);
      break;
    case TileType.university:
      const dome = Color(0xFF3F51B5);
      m
        ..box(x + 0.1, 0, y + 0.14, x + 0.9, 0.72, y + 0.86, const Color(0xFFD8C3A5),
            top: const Color(0xFFB89F82))
        ..prism(x + 0.5, y + 0.5, 0.24, 8, 0.72, 0.84, dome)
        ..cone(x + 0.5, y + 0.5, 0.24, 8, 0.84, 1.02, dome);
      break;
    case TileType.grass:
    case TileType.road:
    case TileType.park:
      return [];
  }
  return [
    m.build(center: Vec3(x + 0.5, 0.5, y + 0.5), payload: cell),
  ];
}

/// A small vending machine standing on the front of its building tile.
LowPolyObject _vendingMachineOnTile(
  double brightness,
  sim.Machine machine,
  int gx,
  int gy,
  CityCell cell,
) {
  final cx = gx + 0.5;
  final cz = gy + 0.92;
  final statusColor = machine.isBroken || machine.totalInventory == 0
      ? _red
      : machine.needsRestock()
          ? const Color(0xFFFFB300)
          : const Color(0xFF43A047);

  final m = LowPolyMeshBuilder(brightness: brightness)
    ..box(cx - 0.14, 0, cz - 0.09, cx + 0.14, 0.36, cz + 0.09, machine.zone.type.color)
    ..box(cx - 0.11, 0.1, cz + 0.09, cx + 0.11, 0.28, cz + 0.11, _glass)
    ..box(cx - 0.03, 0.36, cz - 0.02, cx + 0.03, 0.4, cz + 0.04, statusColor);
  return m.build(center: Vec3(cx, 0.2, cz), payload: cell);
}
