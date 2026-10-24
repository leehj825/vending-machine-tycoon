import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../simulation/models/machine.dart' as sim;
import '../../simulation/models/truck.dart' as sim;
import '../screens/tile_city_screen.dart' show RoadDirection, TileType;
import '../theme/zone_ui.dart';
import 'lowpoly_engine.dart';
import 'vending_machine_3d.dart';

/// Tap target for one cell of the 3D city.
class CityCell {
  const CityCell(this.x, this.y, this.tileType);

  final int x;
  final int y;
  final TileType tileType;
}

/// Tap target for the marketing marker, which the screen handles itself.
const Object marketingTapTarget = Object();

const Color cityDaySky = Color(0xFFA7D8F2);
const Color cityNightSky = Color(0xFF0E1A2E);
const double cityNightBrightness = 0.55;

const Color _earth = Color(0xFF6B5B45);
const Color _grassA = Color(0xFF7CC26A);
const Color _grassB = Color(0xFF69B05A);
const Color _asphalt = Color(0xFF4A4F57);
const Color _lane = Color(0xFFF2F2F2);
const Color _pathStone = Color(0xFFD7CCC8);
const List<Color> _houseWalls = [
  Color(0xFFF6D7B0),
  Color(0xFFE8F1F5),
  Color(0xFFF2E0A8),
  Color(0xFFD9E8D0),
];
const List<Color> _houseRoofs = [
  Color(0xFFB23A48),
  Color(0xFF5D4037),
  Color(0xFF37474F),
  Color(0xFFBF5B2E),
];
const List<Color> _officeBodies = [
  Color(0xFF8FB8DE),
  Color(0xFFB0BEC5),
  Color(0xFF9FD3C7),
  Color(0xFFC9B6E4),
];
const List<Color> _awnings = [
  Color(0xFFE4572E),
  Color(0xFF2E7D32),
  Color(0xFF1565C0),
  Color(0xFFF9A825),
];

/// One colour from [palette], chosen by tile position, so neighbours differ.
Color _variant(List<Color> palette, int x, int y) =>
    palette[(x * 7 + y * 13 + x * y) % palette.length];

const Color _trim = Color(0xFF37474F);
const Color _plinthColor = Color(0xFF9E9E94);

/// Footprint and height of each building's main body, for its plinth and cornice.
const Map<TileType, (double, double, double, double, double)> _bodies = {
  TileType.shop: (0.1, 0.12, 0.9, 0.88, 0.55),
  TileType.gym: (0.08, 0.1, 0.92, 0.9, 0.7),
  TileType.office: (0.2, 0.2, 0.8, 0.8, 1.5),
  TileType.school: (0.1, 0.12, 0.9, 0.88, 0.5),
  TileType.house: (0.2, 0.25, 0.8, 0.8, 0.42),
  TileType.warehouse: (0.04, 0.12, 0.96, 0.9, 0.5),
  TileType.subway: (0.1, 0.14, 0.9, 0.86, 0.32),
  TileType.hospital: (0.1, 0.1, 0.9, 0.9, 0.9),
  TileType.university: (0.1, 0.14, 0.9, 0.86, 0.72),
};

const Color _pavement = Color(0xFFBDBDB5);
const double _pavementWidth = 0.2;
const Color _water = Color(0xFF4FC3F7);
const Color _benchWood = Color(0xFF8D6E63);
const Color _trunk = Color(0xFF7A5230);
const Color _foliage = Color(0xFF3F9142);
const Color _bush = Color(0xFF4CAF50);
const Color _glass = Color(0xFFBFE7F2);
const Color _glassDark = Color(0xFF2C3E50);
const Color _warm = Color(0xFFFFE9A8);
const Color _lampLight = Color(0xFFFFF59D);
const Color _white = Color(0xFFF5F7FA);
const Color _red = Color(0xFFE53935);
const Color _grey = Color(0xFF9AA5B1);
const Color _darkGrey = Color(0xFF4B5563);
const Color _brick = Color(0xFFB5523B);
const Color _brown = Color(0xFF6D4C41);

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
/// Buildings and vending machines are standing objects sorted by depth.
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
      objects.add(_groundTile(brightness, grid, x, y, type, road));
      final turns = _isBuilding(type) ? frontTurns(grid, x, y) ?? 0 : 0;
      for (final building in _buildingObjects(brightness, x, y, type)) {
        objects.add(_turnAbout(building, turns, x + 0.5, y + 0.5));
      }
      objects.addAll(_streetObjects(brightness, grid, x, y, type));
    }
  }

  for (final machine in machines) {
    final gx = math.min(math.max((machine.zone.x - 1).floor(), 0), size - 1);
    final gy = math.min(math.max((machine.zone.y - 1).floor(), 0), size - 1);
    final cell = CityCell(gx, gy, grid[gy][gx]);
    objects.addAll(_vendingMachineOnTile(brightness, machine, grid, gx, gy, cell));
  }

  return objects;
}

/// Whether a tile holds a building, as opposed to grass, road or park.
bool _isBuilding(TileType type) =>
    type != TileType.grass && type != TileType.road && type != TileType.park;

/// Quarter turns that turn a building so its front faces a road next to it. The front
/// starts facing south, and each turn is a quarter turn. Taken in order south, east,
/// north, west, so a corner faces one of its roads. Null when no road touches the tile.
int? frontTurns(List<List<TileType>> grid, int x, int y) {
  if (isRoadTile(grid, x, y + 1)) return 0;
  if (isRoadTile(grid, x + 1, y)) return 3;
  if (isRoadTile(grid, x, y - 1)) return 2;
  if (isRoadTile(grid, x - 1, y)) return 1;
  return null;
}

/// The tile the front of the building on ([x], [y]) faces, or null when no road touches it.
(int, int)? frontTile(List<List<TileType>> grid, int x, int y) {
  final turns = frontTurns(grid, x, y);
  if (turns == null) return null;
  return switch (turns) {
    0 => (x, y + 1),
    3 => (x + 1, y),
    2 => (x, y - 1),
    _ => (x - 1, y),
  };
}

/// Turns the point ([dx], [dz]) about the origin by [turns] quarter turns.
(double, double) _turnPoint(double dx, double dz, int turns) {
  var x = dx;
  var z = dz;
  for (var i = 0; i < turns % 4; i++) {
    final t = x;
    x = -z;
    z = t;
  }
  return (x, z);
}

/// Where a machine stands on its tile once the building is turned: the front corner
/// on the road side. Returned as world (x, z).
(double, double) machineAnchor(List<List<TileType>> grid, int x, int y) {
  final turns = frontTurns(grid, x, y) ?? 0;
  final (dx, dz) = _turnPoint(0.8 - 0.5, 0.95 - 0.5, turns);
  return (x + 0.5 + dx, y + 0.5 + dz);
}

/// The object turned by [turns] quarter turns about the vertical axis through (cx, cz).
LowPolyObject _turnAbout(LowPolyObject object, int turns, double cx, double cz) {
  if (turns % 4 == 0) return object;
  Vec3 point(Vec3 v) {
    final (dx, dz) = _turnPoint(v.x - cx, v.z - cz, turns);
    return Vec3(cx + dx, v.y, cz + dz);
  }

  Vec3 direction(Vec3 v) {
    final (dx, dz) = _turnPoint(v.x, v.z, turns);
    return Vec3(dx, v.y, dz);
  }

  return LowPolyObject(
    triangles: [
      for (final t in object.triangles)
        LowPolyTriangle(point(t.a), point(t.b), point(t.c), direction(t.normal), t.color),
    ],
    center: point(object.center),
    onGround: object.onGround,
    payload: object.payload,
    drawn: object.drawn,
  );
}

/// Deterministic 0..1 value per cell, so grass varies without flickering.
double _cellNoise(int x, int y) => ((x * 73 + y * 151 + x * y * 31) % 97) / 96.0;

/// Whether the tile at ([x], [y]) is a road. Off the map counts as no road.
bool isRoadTile(List<List<TileType>> grid, int x, int y) {
  if (y < 0 || y >= grid.length || x < 0 || x >= grid[y].length) return false;
  return grid[y][x] == TileType.road;
}

/// Whether the point ([px], [pz]) is on a pavement strip. Pavement lies on the
/// edge of a road tile that faces a tile which is not road, so people can walk there.
bool isPavementAt(List<List<TileType>> grid, double px, double pz) {
  final tx = px.floor();
  final ty = pz.floor();
  if (!isRoadTile(grid, tx, ty)) return false;
  final lx = px - tx;
  final lz = pz - ty;
  if (lx < _pavementWidth && !isRoadTile(grid, tx - 1, ty)) return true;
  if (lx > 1 - _pavementWidth && !isRoadTile(grid, tx + 1, ty)) return true;
  if (lz < _pavementWidth && !isRoadTile(grid, tx, ty - 1)) return true;
  if (lz > 1 - _pavementWidth && !isRoadTile(grid, tx, ty + 1)) return true;
  return false;
}

/// Ground under one tile: asphalt with lane markings and kerbs on a road,
/// grass with a sidewalk strip beside a road, and a park's paths and pond.
LowPolyObject _groundTile(
  double brightness,
  List<List<TileType>> grid,
  int x,
  int y,
  TileType type,
  RoadDirection? road,
) {
  final m = LowPolyMeshBuilder(brightness: brightness);
  if (type == TileType.road) {
    // The asphalt stops short of any side that faces grass or a building. The strip left
    // behind is the pavement that people walk on.
    final leftOpen = !isRoadTile(grid, x - 1, y);
    final rightOpen = !isRoadTile(grid, x + 1, y);
    final backOpen = !isRoadTile(grid, x, y - 1);
    final frontOpen = !isRoadTile(grid, x, y + 1);
    final x0 = leftOpen ? _pavementWidth : 0.0;
    final x1 = rightOpen ? 1 - _pavementWidth : 1.0;
    final y0 = backOpen ? _pavementWidth : 0.0;
    final y1 = frontOpen ? 1 - _pavementWidth : 1.0;
    m.flat(x + x0, y + y0, x + x1, y + y1, 0.0, _asphalt);
    if (leftOpen) m.flat(x + 0.0, y + 0.0, x + _pavementWidth, y + 1.0, 0.005, _pavement);
    if (rightOpen) m.flat(x + 1.0 - _pavementWidth, y + 0.0, x + 1.0, y + 1.0, 0.005, _pavement);
    if (backOpen) m.flat(x + 0.0, y + 0.0, x + 1.0, y + _pavementWidth, 0.005, _pavement);
    if (frontOpen) m.flat(x + 0.0, y + 1.0 - _pavementWidth, x + 1.0, y + 1.0, 0.005, _pavement);
    if (road == RoadDirection.vertical) {
      m.flat(x + 0.47, y + 0.1, x + 0.53, y + 0.9, 0.004, _lane);
    } else if (road == RoadDirection.horizontal) {
      m.flat(x + 0.1, y + 0.47, x + 0.9, y + 0.53, 0.004, _lane);
    }
  } else {
    final grass = Color.lerp(_grassA, _grassB, _cellNoise(x, y)) ?? _grassA;
    m.flat(x + 0.0, y + 0.0, x + 1.0, y + 1.0, 0.0, grass);
    if (type == TileType.park) {
      // Paths cross the park, with a pond and a bench on the grass.
      m
        ..flat(x + 0.46, y + 0.0, x + 0.54, y + 1.0, 0.003, _pathStone)
        ..flat(x + 0.0, y + 0.46, x + 1.0, y + 0.54, 0.003, _pathStone)
        ..flat(x + 0.08, y + 0.6, x + 0.34, y + 0.9, 0.004, _water)
        ..box(x + 0.6, 0, y + 0.6, x + 0.74, 0.1, y + 0.66, _benchWood);
    }
  }
  return m.build(center: Vec3(x + 0.5, 0, y + 0.5), onGround: true, payload: GroundCell(x, y));
}

/// Street furniture on the pavement: lamp posts and street trees along roads.
/// They are spaced by position, so the pattern is the same on every load.
List<LowPolyObject> _streetObjects(
  double brightness,
  List<List<TileType>> grid,
  int x,
  int y,
  TileType type,
) {
  if (type == TileType.road || type == TileType.park) return const [];
  final objects = <LowPolyObject>[];
  final onRoad = isRoadTile(grid, x, y - 1) || isRoadTile(grid, x, y + 1) ||
      isRoadTile(grid, x - 1, y) || isRoadTile(grid, x + 1, y);
  if (!onRoad) return objects;

  final m = LowPolyMeshBuilder(brightness: brightness);
  // A lamp on every other tile at the kerb corner, and a tree on the rest.
  if ((x + y).isEven) {
    final px = x + 0.9;
    final pz = y + 0.1;
    m
      ..box(px - 0.02, 0, pz - 0.02, px + 0.02, 0.4, pz + 0.02, _darkGrey)
      ..box(px - 0.04, 0.4, pz - 0.04, px + 0.04, 0.44, pz + 0.04, _lampLight);
    objects.add(m.build(center: Vec3(px, 0.2, pz)));
  } else {
    final tx = x + 0.12;
    final tz = y + 0.12;
    m
      ..box(tx - 0.02, 0, tz - 0.02, tx + 0.02, 0.14, tz + 0.02, _trunk)
      ..cone(tx, tz, 0.1, 6, 0.12, 0.42, _foliage);
    objects.add(m.build(center: Vec3(tx, 0.2, tz)));
  }
  return objects;
}

/// A small lamp post with a warm light, placed at a tile corner.
void _lamp(LowPolyMeshBuilder m, double px, double pz) {
  m
    ..box(px - 0.02, 0, pz - 0.02, px + 0.02, 0.42, pz + 0.02, _darkGrey)
    ..box(px - 0.05, 0.42, pz - 0.05, px + 0.05, 0.48, pz + 0.05, _lampLight);
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
        ..cone(x + tx, y + tz, 0.2, 6, 0.18, 0.62, _foliage)
        ..cone(x + tx, y + tz, 0.12, 6, 0.5, 0.78, _bush);
      objects.add(m.build(center: Vec3(x + tx, 0.35, y + tz), payload: cell));
    }
    return objects;
  }

  final m = LowPolyMeshBuilder(brightness: brightness);
  // The plinth goes in first. Parts are drawn in list order with no depth buffer, so
  // anything added later, like the walls and roof, covers it.
  final body = _bodies[type];
  if (body != null) {
    final (bx0, bz0, bx1, bz1, _) = body;
    m.box(x + bx0 - 0.015, 0, y + bz0 - 0.015, x + bx1 + 0.015, 0.06, y + bz1 + 0.015, _plinthColor);
  }
  switch (type) {
    case TileType.shop:
      m
        ..box(x + 0.1, 0, y + 0.12, x + 0.9, 0.55, y + 0.88, const Color(0xFFF2C14E),
            top: const Color(0xFF8D6E63))
        ..windows(x + 0.1, y + 0.12, x + 0.9, y + 0.88, 0.12, 0.42,
            cols: 3, rows: 1, glass: _glass, frame: _trim, lit: _warm)
        ..box(x + 0.44, 0, y + 0.88, x + 0.56, 0.34, y + 0.93, _brown)
        ..box(x + 0.06, 0.42, y + 0.84, x + 0.94, 0.52, y + 0.94, const Color(0xFFE4572E));
      // Awning stripes and a sign board above the door.
      for (final sx in [0.16, 0.44, 0.72]) {
        m.box(x + sx, 0.42, y + 0.94, x + sx + 0.1, 0.52, y + 0.955, _white);
      }
      m
        ..box(x + 0.3, 0.55, y + 0.84, x + 0.7, 0.66, y + 0.9, const Color(0xFFFFF176))
        ..box(x + 0.12, 0, y + 0.9, x + 0.22, 0.12, y + 0.98, _bush)
        ..box(x + 0.78, 0, y + 0.9, x + 0.88, 0.12, y + 0.98, _bush)
        ..box(x + 0.7, 0.55, y + 0.3, x + 0.84, 0.63, y + 0.46, _darkGrey);
      _lamp(m, x + 0.93, y + 0.93);
      break;
    case TileType.gym:
      // A wide brick hall with rooftop fans, and a tall steel front tower with a red sign.
      const hall = Color(0xFFC0543A);
      const steel = Color(0xFF37474F);
      m
        ..box(x + 0.06, 0, y + 0.12, x + 0.94, 0.5, y + 0.9, hall, top: const Color(0xFF6B7280))
        ..windows(x + 0.06, y + 0.12, x + 0.94, y + 0.9, 0.12, 0.34,
            cols: 5, rows: 1, glass: _glass, frame: _trim, lit: _warm)
        ..box(x + 0.3, 0, y + 0.62, x + 0.7, 0.86, y + 0.92, steel, top: const Color(0xFF263238))
        ..box(x + 0.36, 0.2, y + 0.92, x + 0.64, 0.7, y + 0.94, _glass)
        ..box(x + 0.3, 0.72, y + 0.6, x + 0.7, 0.84, y + 0.94, _red)
        ..box(x + 0.4, 0.76, y + 0.94, x + 0.6, 0.8, y + 0.96, _white)
        ..prism(x + 0.25, y + 0.35, 0.1, 6, 0.5, 0.62, const Color(0xFF90A4AE))
        ..prism(x + 0.7, y + 0.35, 0.1, 6, 0.5, 0.62, const Color(0xFF90A4AE));
      _lamp(m, x + 0.93, y + 0.93);
      break;
    case TileType.office:
      m
        ..box(x + 0.2, 0, y + 0.2, x + 0.8, 1.5, y + 0.8, _variant(_officeBodies, x, y),
            top: const Color(0xFF3D5A80))
        ..windows(x + 0.2, y + 0.2, x + 0.8, y + 0.8, 0.12, 1.42,
            cols: 3, rows: 6, glass: _glass, frame: _trim, lit: _warm)
        ..box(x + 0.3, 1.5, y + 0.3, x + 0.7, 1.62, y + 0.7, const Color(0xFF3D5A80))
        ..box(x + 0.32, 1.62, y + 0.32, x + 0.44, 1.7, y + 0.44, _grey)
        ..box(x + 0.56, 1.62, y + 0.56, x + 0.6, 1.95, y + 0.6, _grey)
        ..box(x + 0.42, 0, y + 0.8, x + 0.58, 0.24, y + 0.86, _glassDark)
        ..box(x + 0.36, 0.24, y + 0.78, x + 0.64, 0.28, y + 0.9, const Color(0xFF1F2A44));
      _lamp(m, x + 0.93, y + 0.93);
      break;
    case TileType.school:
      // A two-storey wing with a clock tower at the back, a flagpole, and a sign over the door.
      const cream = Color(0xFFF2D6A2);
      const creamTop = Color(0xFFE0BE85);
      const tower = Color(0xFFD9B77E);
      m
        ..box(x + 0.08, 0, y + 0.22, x + 0.92, 0.46, y + 0.88, cream, top: creamTop)
        ..windows(x + 0.08, y + 0.22, x + 0.92, y + 0.88, 0.1, 0.34,
            cols: 6, rows: 1, glass: _glass, frame: _trim, lit: _warm)
        ..box(x + 0.38, 0, y + 0.08, x + 0.62, 0.8, y + 0.32, tower, top: creamTop)
        ..windows(x + 0.38, y + 0.08, x + 0.62, y + 0.32, 0.5, 0.2,
            cols: 1, rows: 1, glass: _glass, frame: _trim)
        ..roof(x + 0.35, y + 0.05, x + 0.65, y + 0.35, 0.8, 1.0, const Color(0xFFC0392B))
        ..box(x + 0.44, 0, y + 0.88, x + 0.56, 0.26, y + 0.93, _brown)
        ..box(x + 0.34, 0.28, y + 0.88, x + 0.66, 0.36, y + 0.93, const Color(0xFFFFD54F))
        ..box(x + 0.2, 0.46, y + 0.5, x + 0.23, 0.9, y + 0.53, _grey)
        ..box(x + 0.23, 0.78, y + 0.5, x + 0.36, 0.86, y + 0.53, _red);
      _lamp(m, x + 0.07, y + 0.93);
      break;
    case TileType.gasStation:
      const pillar = Color(0xFFB0BEC5);
      const pump = Color(0xFF1E88E5);
      m
        ..box(x + 0.36, 0, y + 0.36, x + 0.64, 0.36, y + 0.64, _white)
        ..windows(x + 0.36, y + 0.36, x + 0.64, y + 0.64, 0.1, 0.3,
            cols: 2, rows: 1, glass: _glass, frame: _trim)
        ..box(x + 0.18, 0, y + 0.5, x + 0.26, 0.3, y + 0.6, pump)
        ..box(x + 0.74, 0, y + 0.5, x + 0.82, 0.3, y + 0.6, pump)
        ..box(x + 0.18, 0.3, y + 0.5, x + 0.26, 0.34, y + 0.6, const Color(0xFFFFEB3B))
        ..box(x + 0.74, 0.3, y + 0.5, x + 0.82, 0.34, y + 0.6, const Color(0xFFFFEB3B))
        ..box(x + 0.1, 0, y + 0.1, x + 0.16, 0.5, y + 0.16, pillar)
        ..box(x + 0.84, 0, y + 0.1, x + 0.9, 0.5, y + 0.16, pillar)
        ..box(x + 0.1, 0, y + 0.84, x + 0.16, 0.5, y + 0.9, pillar)
        ..box(x + 0.84, 0, y + 0.84, x + 0.9, 0.5, y + 0.9, pillar)
        ..box(x + 0.04, 0.5, y + 0.04, x + 0.96, 0.6, y + 0.96, _variant(_awnings, x, y),
            top: const Color(0xFFFF7043))
        ..box(x + 0.2, 0.6, y + 0.44, x + 0.8, 0.63, y + 0.5, _white)
        ..box(x + 0.93, 0, y + 0.1, x + 0.97, 0.9, y + 0.14, _grey)
        ..box(x + 0.8, 0.9, y + 0.1, x + 1.0, 1.04, y + 0.13, _red,
            top: const Color(0xFFFFEB3B));
      break;
    case TileType.house:
      m
        ..box(x + 0.2, 0, y + 0.25, x + 0.8, 0.42, y + 0.8, _variant(_houseWalls, x, y))
        ..windows(x + 0.2, y + 0.25, x + 0.8, y + 0.8, 0.1, 0.36,
            cols: 2, rows: 1, glass: _glass, frame: _trim, lit: _warm)
        ..box(x + 0.44, 0, y + 0.8, x + 0.56, 0.22, y + 0.84, _brown)
        ..roof(x + 0.14, y + 0.19, x + 0.86, y + 0.86, 0.42, 0.7, _variant(_houseRoofs, x, y))
        ..box(x + 0.62, 0.5, y + 0.3, x + 0.7, 0.86, y + 0.38, _brick)
        ..box(x + 0.1, 0, y + 0.84, x + 0.18, 0.12, y + 0.92, _bush)
        ..box(x + 0.82, 0, y + 0.84, x + 0.9, 0.12, y + 0.92, _bush);
      break;
    case TileType.warehouse:
      m
        ..box(x + 0.04, 0, y + 0.12, x + 0.96, 0.5, y + 0.9, _grey,
            top: const Color(0xFF6B7785))
        ..windows(x + 0.04, y + 0.12, x + 0.96, y + 0.9, 0.32, 0.44,
            cols: 6, rows: 1, glass: _glass, frame: _trim)
        ..box(x + 0.18, 0, y + 0.9, x + 0.44, 0.36, y + 0.93, _darkGrey)
        ..box(x + 0.56, 0, y + 0.9, x + 0.82, 0.36, y + 0.93, _darkGrey)
        ..box(x + 0.2, 0.5, y + 0.3, x + 0.36, 0.54, y + 0.44, _glass)
        ..box(x + 0.6, 0.5, y + 0.3, x + 0.76, 0.54, y + 0.44, _glass);
      // Roller-door slats.
      for (final dx in [0.18, 0.56]) {
        for (var i = 0; i < 3; i++) {
          final sy = 0.08 + i * 0.1;
          m.box(x + dx, sy, y + 0.93, x + dx + 0.26, sy + 0.025, y + 0.94, _grey);
        }
      }
      break;
    case TileType.subway:
      // A stair entrance with a canopy, and a tall roundel sign on a pole.
      const blue = Color(0xFF1565C0);
      m
        ..box(x + 0.1, 0, y + 0.1, x + 0.9, 0.04, y + 0.9, const Color(0xFFBDBDB5))
        ..box(x + 0.32, 0, y + 0.3, x + 0.68, 0.3, y + 0.7, const Color(0xFF2E5A80),
            top: const Color(0xFF1F3F5C))
        ..box(x + 0.36, 0.04, y + 0.66, x + 0.64, 0.1, y + 0.72, const Color(0xFF263238))
        ..box(x + 0.4, 0.1, y + 0.7, x + 0.6, 0.16, y + 0.76, const Color(0xFF263238))
        ..box(x + 0.28, 0.3, y + 0.26, x + 0.72, 0.34, y + 0.74, _grey, top: const Color(0xFF9AA5B1))
        ..box(x + 0.7, 0, y + 0.5, x + 0.74, 1.05, y + 0.54, _darkGrey)
        ..prism(x + 0.72, y + 0.52, 0.14, 14, 1.0, 1.12, const Color(0xFFE53935))
        ..box(x + 0.56, 1.04, y + 0.5, x + 0.88, 1.08, y + 0.56, blue);
      _lamp(m, x + 0.07, y + 0.93);
      break;
    case TileType.hospital:
      m
        ..box(x + 0.1, 0, y + 0.1, x + 0.9, 0.9, y + 0.9, _white,
            top: const Color(0xFFE3E8EF))
        ..windows(x + 0.1, y + 0.1, x + 0.9, y + 0.9, 0.3, 0.86,
            cols: 4, rows: 2, glass: _glass, frame: _trim, lit: _warm)
        ..box(x + 0.34, 0.24, y + 0.9, x + 0.66, 0.3, y + 0.99, const Color(0xFF26A69A))
        ..box(x + 0.42, 0, y + 0.9, x + 0.58, 0.24, y + 0.94, _glassDark)
        ..box(x + 0.42, 0.9, y + 0.28, x + 0.58, 0.94, y + 0.72, _red)
        ..box(x + 0.28, 0.9, y + 0.42, x + 0.72, 0.94, y + 0.58, _red);
      _lamp(m, x + 0.93, y + 0.93);
      break;
    case TileType.university:
      // Limestone block with a columned portico, a pediment, and a dome on the drum.
      const stone = Color(0xFFD8C3A5);
      const stoneTop = Color(0xFFB89F82);
      const dome = Color(0xFF3F51B5);
      m
        ..box(x + 0.1, 0, y + 0.16, x + 0.9, 0.7, y + 0.8, stone, top: stoneTop)
        ..windows(x + 0.1, y + 0.16, x + 0.9, y + 0.8, 0.12, 0.5,
            cols: 6, rows: 2, glass: _glass, frame: _trim, lit: _warm)
        ..box(x + 0.22, 0, y + 0.8, x + 0.78, 0.06, y + 0.95, const Color(0xFFEEE6D8))
        ..box(x + 0.24, 0.6, y + 0.78, x + 0.76, 0.68, y + 0.92, const Color(0xFFEEE6D8))
        ..roof(x + 0.22, y + 0.76, x + 0.78, y + 0.92, 0.68, 0.8, const Color(0xFFE8DCC8))
        ..box(x + 0.36, 0.7, y + 0.36, x + 0.64, 0.82, y + 0.64, stone, top: stoneTop)
        ..prism(x + 0.5, y + 0.5, 0.2, 10, 0.82, 0.92, dome)
        ..cone(x + 0.5, y + 0.5, 0.2, 10, 0.92, 1.08, dome);
      // Columns across the portico.
      for (final cx in [0.27, 0.4, 0.6, 0.73]) {
        m.box(x + cx - 0.03, 0.06, y + 0.82, x + cx + 0.03, 0.6, y + 0.88, _white);
      }
      _lamp(m, x + 0.07, y + 0.93);
      break;
    case TileType.grass:
    case TileType.road:
    case TileType.park:
      return [];
  }
  // A cornice rim under the roof. Only the outer ring is drawn, so the roof stays visible.
  if (body != null) {
    final (bx0, bz0, bx1, bz1, top) = body;
    m
      ..box(x + bx0 - 0.02, top, y + bz0 - 0.02, x + bx1 + 0.02, top + 0.04, y + bz0, _trim)
      ..box(x + bx0 - 0.02, top, y + bz1, x + bx1 + 0.02, top + 0.04, y + bz1 + 0.02, _trim)
      ..box(x + bx0 - 0.02, top, y + bz0, x + bx0, top + 0.04, y + bz1, _trim)
      ..box(x + bx1, top, y + bz0, x + bx1 + 0.02, top + 0.04, y + bz1, _trim);
    _facadeDetail(m, x, y, type, body);
  }
  return [
    m.build(center: Vec3(x + 0.5, 0.5, y + 0.5), payload: cell),
  ];
}

/// Details common to every building: pillars at the corners, a rooftop unit on each
/// roof, and an antenna on the taller ones. The unit's place varies by tile, so the
/// roofs do not all look the same.
void _facadeDetail(
  LowPolyMeshBuilder m,
  int x,
  int y,
  TileType type,
  (double, double, double, double, double) body,
) {
  final (bx0, bz0, bx1, bz1, top) = body;
  const pillar = Color(0xFFD7DCE1);
  // Corner pillars stand just proud of the walls, from the plinth to the cornice.
  for (final (px, pz) in [(bx0, bz0), (bx1, bz0), (bx0, bz1), (bx1, bz1)]) {
    m.box(x + px - 0.03, 0.06, y + pz - 0.03, x + px + 0.03, top, y + pz + 0.03, pillar);
  }
  // A rooftop unit, set back from the front edge.
  final unitX = bx0 + (bx1 - bx0) * (0.2 + ((x * 3 + y * 5) % 4) * 0.12);
  final unitZ = bz0 + (bz1 - bz0) * 0.3;
  m.box(x + unitX, top + 0.04, y + unitZ, x + unitX + 0.16, top + 0.13, y + unitZ + 0.13, _darkGrey);
  if (top >= 0.9) {
    // Taller buildings carry an antenna with a red warning light.
    final ax = x + (bx0 + bx1) / 2;
    final az = y + (bz0 + bz1) / 2;
    m
      ..box(ax - 0.015, top + 0.04, az - 0.015, ax + 0.015, top + 0.4, az + 0.015, _grey)
      ..box(ax - 0.03, top + 0.4, az - 0.03, ax + 0.03, top + 0.43, az + 0.03, _red);
  }
}

/// What a tap on a ground tile reports: the tile, so the player can walk there.
class GroundCell {
  const GroundCell(this.x, this.y);

  final int x;
  final int y;
}

/// What a tap on a machine's cash coin collects.
class CollectTarget {
  const CollectTarget(this.machineId);

  final String machineId;
}

/// Height markers float at over a tile of [type]: just above its roof.
double markerHeight(TileType type) => (_bodies[type]?.$5 ?? 0.6) + 0.45;

/// A downward arrow over a building that can be bought: green when the cash covers it,
/// grey when it does not. A tap on it works like a tap on the building.
LowPolyObject buildPurchaseMarker({
  required int x,
  required int y,
  required TileType type,
  required bool affordable,
  required double bob,
  required double brightness,
}) {
  final h = markerHeight(type) + bob;
  final m = LowPolyMeshBuilder(brightness: brightness)
    ..cone(x + 0.5, y + 0.5, 0.22, 6, h + 0.3, h,
        affordable ? const Color(0xFF43A047) : const Color(0xFFFFC107));
  return m.build(center: Vec3(x + 0.5, h, y + 0.5), payload: CityCell(x, y, type));
}

/// A small blue plate over a building the player has bought.
LowPolyObject buildOwnedMarker({
  required int x,
  required int y,
  required TileType type,
  required double bob,
  required double brightness,
}) {
  final h = markerHeight(type) + bob;
  final m = LowPolyMeshBuilder(brightness: brightness)
    ..box(x + 0.4, h, y + 0.46, x + 0.6, h + 0.06, y + 0.54, const Color(0xFF1E88E5))
    ..box(x + 0.44, h + 0.06, y + 0.48, x + 0.56, h + 0.07, y + 0.52, const Color(0xFFFFFFFF));
  return m.build(center: Vec3(x + 0.5, h, y + 0.5));
}

/// A gold coin floating above a machine that has cash to collect. Tapping it collects.
LowPolyObject buildCollectCoin({
  required String machineId,
  required double x,
  required double z,
  required double height,
  required double bob,
  required double brightness,
}) {
  final h = height + bob;
  const gold = Color(0xFFF2C94C);
  final m = LowPolyMeshBuilder(brightness: brightness)
    ..prism(x, z, 0.12, 12, h, h + 0.05, const Color(0xFFC9963A), top: gold);
  return m.build(center: Vec3(x, h, z), payload: CollectTarget(machineId));
}

/// Scale from the machine model's own size (about 2 units tall) to a tile. At this
/// size it is as tall as a person.
const double _machineScale = 0.13;

/// The real vending machine, standing at the front corner of its building on the
/// pavement and turned to face the street. Tapping it opens its details.
List<LowPolyObject> _vendingMachineOnTile(
  double brightness,
  sim.Machine machine,
  List<List<TileType>> grid,
  int gx,
  int gy,
  CityCell cell,
) {
  final model = buildVendingMachineScene(machine, brightness: brightness).single;
  final (ax, az) = machineAnchor(grid, gx, gy);
  final turns = frontTurns(grid, gx, gy) ?? 0;
  final placed = placeObject(
    model,
    at: Vec3(ax, 0, az),
    scale: _machineScale,
    // placeObject turns the other way from the tile turns, so the angle is negated.
    yaw: -turns * math.pi / 2,
    payload: cell,
  );
  // A bigger, invisible pad, so a finger can hit the machine.
  final pad = LowPolyMeshBuilder(brightness: brightness)
    ..flat(ax - 0.2, az - 0.13, ax + 0.2, az + 0.13, 0.01, _pavement);
  return [
    placed,
    pad.build(center: Vec3(ax, 0.01, az), payload: cell, drawn: false),
  ];
}

/// A delivery truck on its road tile, turned to face the way it is driving.
LowPolyObject buildTruckObject(sim.Truck truck, double brightness) {
  final baseX = truck.currentX - 0.5;
  final baseZ = truck.currentY - 0.5;
  var dx = truck.targetX - truck.currentX;
  var dy = truck.targetY - truck.currentY;
  if (truck.path.isNotEmpty && truck.pathIndex < truck.path.length) {
    final next = truck.path[truck.pathIndex];
    dx = next.x - truck.currentX;
    dy = next.y - truck.currentY;
  }
  final alongX = dx.abs() > dy.abs();
  final forward = (alongX ? dx : dy) < 0 ? -1.0 : 1.0;
  // Drive on the right: the truck sits 0.15 to the right of its heading. Looking down on
  // the map, the right of heading (fx, fz) is (-fz, fx).
  const laneOffset = 0.15;
  final cx = alongX ? baseX : baseX - laneOffset * forward;
  final cz = alongX ? baseZ + laneOffset * forward : baseZ;

  // Local coordinates: u runs along the direction of travel, v across it.
  double px(double u, double v) => alongX ? cx + u * forward : cx + v;
  double pz(double u, double v) => alongX ? cz + v : cz + u * forward;

  final m = LowPolyMeshBuilder(brightness: brightness);
  void part(double u0, double u1, double v0, double v1, double y0, double y1, Color color,
      {Color? top}) {
    m.box(
      math.min(px(u0, v0), px(u1, v1)),
      y0,
      math.min(pz(u0, v0), pz(u1, v1)),
      math.max(px(u0, v0), px(u1, v1)),
      y1,
      math.max(pz(u0, v0), pz(u1, v1)),
      color,
      top: top,
    );
  }

  part(-0.3, 0.08, -0.12, 0.12, 0.08, 0.36, _white, top: const Color(0xFFDCE6F0));
  part(0.08, 0.3, -0.11, 0.11, 0.06, 0.26, const Color(0xFFD32F2F));
  part(0.27, 0.31, -0.09, 0.09, 0.14, 0.22, _glass);
  part(-0.22, -0.12, 0.1, 0.14, 0, 0.06, _darkGrey);
  part(-0.22, -0.12, -0.14, -0.1, 0, 0.06, _darkGrey);
  part(0.14, 0.24, 0.1, 0.14, 0, 0.06, _darkGrey);
  part(0.14, 0.24, -0.14, -0.1, 0, 0.06, _darkGrey);
  return m.build(center: Vec3(cx, 0.2, cz));
}

/// A pulsing marketing marker on a tile. It turns orange during rush hour.
/// A larger invisible pad under it makes it easy to tap.
List<LowPolyObject> buildMarketingMarker({
  required int gridX,
  required int gridY,
  required bool rushHour,
  required double brightness,
}) {
  final cx = gridX + 0.5;
  final cz = gridY + 0.5;
  final color = rushHour ? const Color(0xFFFB8C00) : const Color(0xFF1E88E5);
  final sign = LowPolyMeshBuilder(brightness: brightness)
    ..box(cx - 0.02, 0, cz - 0.02, cx + 0.02, 0.5, cz + 0.02, _darkGrey)
    ..box(cx - 0.16, 0.5, cz - 0.16, cx + 0.16, 0.74, cz + 0.16, color,
        top: const Color(0xFFFFFFFF));
  final pad = LowPolyMeshBuilder(brightness: brightness)
    ..flat(cx - 0.35, cz - 0.35, cx + 0.35, cz + 0.35, 0.01, color);
  return [
    sign.build(center: Vec3(cx, 0.4, cz), payload: marketingTapTarget),
    pad.build(center: Vec3(cx, 0.01, cz), payload: marketingTapTarget, drawn: false),
  ];
}
