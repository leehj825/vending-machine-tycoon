import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_empire/simulation/models/machine.dart';
import 'package:vending_empire/simulation/models/product.dart';
import 'package:vending_empire/simulation/models/zone.dart';
import 'package:vending_empire/ui/screens/tile_city_screen.dart';
import 'package:vending_empire/ui/three_d/city_scene_3d.dart';
import 'package:vending_empire/ui/three_d/lowpoly_engine.dart';
import 'package:vending_empire/ui/three_d/vending_machine_3d.dart';

const int _size = 15;
const Size _viewport = Size(390, 700);

/// A small city: one road cross, and one building of each kind in its own tile.
List<List<TileType>> _testGrid() {
  final grid = List.generate(_size, (_) => List.filled(_size, TileType.grass));
  for (var i = 0; i < _size; i++) {
    grid[7][i] = TileType.road;
    grid[i][7] = TileType.road;
  }
  const buildings = {
    TileType.shop: (3, 3),
    TileType.office: (10, 3),
    TileType.park: (3, 10),
    TileType.hospital: (10, 10),
    TileType.house: (5, 12),
    TileType.gasStation: (12, 5),
    TileType.school: (2, 5),
    TileType.gym: (5, 2),
    TileType.university: (12, 12),
    TileType.warehouse: (1, 12),
    TileType.subway: (12, 1),
  };
  buildings.forEach((type, pos) {
    grid[pos.$2][pos.$1] = type;
  });
  return grid;
}

List<List<RoadDirection?>> _testRoads() {
  return List.generate(_size, (y) {
    return List.generate(_size, (x) {
      if (x == 7 && y == 7) return RoadDirection.intersection;
      if (y == 7) return RoadDirection.horizontal;
      if (x == 7) return RoadDirection.vertical;
      return null;
    });
  });
}

Machine _testMachine({
  required String id,
  required ZoneType type,
  required double zoneX,
  required double zoneY,
  required int stock,
}) {
  return Machine(
    id: id,
    name: 'Test machine',
    zone: Zone(id: 'z-$id', type: type, name: 'Zone', x: zoneX, y: zoneY),
    condition: MachineCondition.good,
    inventory: {
      if (stock > 0)
        Product.soda: InventoryItem(product: Product.soda, quantity: stock, dayAdded: 0),
    },
  );
}

List<LowPolyObject> _testScene({double brightness = 1.0}) {
  return buildCityScene(
    grid: _testGrid(),
    roadDirections: _testRoads(),
    machines: [
      _testMachine(id: 'm1', type: ZoneType.shop, zoneX: 4.5, zoneY: 4.5, stock: 12),
    ],
    brightness: brightness,
  );
}

void main() {
  testWidgets('city scene draws without errors', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: _viewport.width,
          height: _viewport.height,
          child: LowPolyView(
            objects: _testScene(),
            camera: defaultCityCamera(_size),
            background: cityDaySky,
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('night scene draws without errors', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: _viewport.width,
          height: _viewport.height,
          child: LowPolyView(
            objects: _testScene(brightness: cityNightBrightness),
            camera: defaultCityCamera(_size),
            background: cityNightSky,
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  test('tapping a building picks its cell', () {
    final camera = defaultCityCamera(_size);
    final scene = _testScene();
    final shopCenter = LowPolyProjector(camera, _viewport).project(const Vec3(3.5, 0.3, 3.5));
    expect(shopCenter, isNotNull);

    final picked = lowPolyPick(
      objects: scene,
      camera: camera,
      size: _viewport,
      at: shopCenter!,
    );
    expect(picked, isA<CityCell>());
    final cell = picked! as CityCell;
    expect(cell.x, 3);
    expect(cell.y, 3);
  });

  test('tapping empty grass picks nothing', () {
    final camera = defaultCityCamera(_size);
    final scene = _testScene();
    final grass = LowPolyProjector(camera, _viewport).project(const Vec3(0.5, 0, 0.5));
    expect(grass, isNotNull);

    expect(
      lowPolyPick(objects: scene, camera: camera, size: _viewport, at: grass!),
      isNull,
    );
  });

  testWidgets('vending machine renders empty and stocked', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 360,
          child: Column(
            children: [
              VendingMachine3DView(
                machine: _testMachine(
                  id: 'empty',
                  type: ZoneType.gym,
                  zoneX: 1,
                  zoneY: 1,
                  stock: 0,
                ),
              ),
              VendingMachine3DView(
                machine: _testMachine(
                  id: 'full',
                  type: ZoneType.hospital,
                  zoneX: 1,
                  zoneY: 1,
                  stock: 30,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
