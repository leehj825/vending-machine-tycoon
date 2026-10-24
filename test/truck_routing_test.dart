import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vending_empire/simulation/city_roads.dart';
import 'package:vending_empire/simulation/engine.dart';
import 'package:vending_empire/simulation/models/machine.dart';
import 'package:vending_empire/simulation/models/product.dart';
import 'package:vending_empire/simulation/models/truck.dart';
import 'package:vending_empire/simulation/models/zone.dart';

void main() {
  test('a truck drives on asphalt, serves its stops and returns to the warehouse', () {
    for (var seed = 0; seed < 10; seed++) {
      final random = math.Random(seed);
      const size = 15;
      final road = generateRoadMask(size, random);
      bool isRoad(int gx, int gy) =>
          gx >= 0 && gy >= 0 && gx < size && gy < size && road[gy][gx];

      final roadTiles = <({double x, double y})>[];
      for (var y = 0; y < size; y++) {
        for (var x = 0; x < size; x++) {
          if (road[y][x]) roadTiles.add((x: x + 1.0, y: y + 1.0));
        }
      }

      // Machines on non-road tiles beside a road.
      final spots = <(int, int)>[];
      for (var y = 0; y < size; y++) {
        for (var x = 0; x < size; x++) {
          if (road[y][x]) continue;
          if (isRoad(x + 1, y) || isRoad(x - 1, y) || isRoad(x, y + 1) || isRoad(x, y - 1)) {
            spots.add((x, y));
          }
        }
      }
      spots.shuffle(random);
      final picks = spots.take(4).toList();
      final machines = [
        for (var i = 0; i < picks.length; i++)
          Machine(
            id: 'm$i',
            name: 'M$i',
            zone: Zone(
              id: 'z$i',
              type: ZoneType.shop,
              name: 'Z',
              x: picks[i].$1 + 1.5,
              y: picks[i].$2 + 1.5,
            ),
            condition: MachineCondition.good,
            inventory: {
              Product.soda: const InventoryItem(
                product: Product.soda,
                quantity: 0,
                dayAdded: 0,
                allocation: 20,
              ),
            },
          ),
      ];

      final wx = roadTiles.first.x;
      final wy = roadTiles.first.y;
      final truck = Truck(
        id: 't',
        name: 'T',
        currentX: wx,
        currentY: wy,
        targetX: wx,
        targetY: wy,
        status: TruckStatus.traveling,
        route: [for (final m in machines) m.id],
        inventory: const {Product.soda: 40},
      );

      final engine = SimulationEngine(initialMachines: machines, initialTrucks: [truck]);
      engine.setMapLayout(roadTiles);
      engine.updateWarehouseRoadPosition(wx, wy);

      var curMachines = machines;
      var curTrucks = [truck];
      var offAsphalt = 0;
      for (var t = 0; t < 6000; t++) {
        final r = engine.tick(curMachines, curTrucks);
        curMachines = r.machines;
        curTrucks = r.trucks;
        final tr = curTrucks.first;
        // A road tile is a full tile wide, so a truck within half a tile of
        // its centre is on the asphalt.
        final rx = tr.currentX.round();
        final ry = tr.currentY.round();
        final onAsphalt = isRoad(rx - 1, ry - 1) &&
            (tr.currentX - rx).abs() <= 0.5 &&
            (tr.currentY - ry).abs() <= 0.5;
        if (!onAsphalt) offAsphalt++;
      }

      expect(offAsphalt, 0, reason: 'seed $seed: truck left the road');
      expect(curTrucks.first.isRouteComplete, isTrue, reason: 'seed $seed: route not finished');
      // 40 units cover two stops of 20 each. The other two stop on the next run.
      expect(curTrucks.first.route, ['m2', 'm3'], reason: 'seed $seed: unserved stops not kept');
      expect(curMachines.first.totalSales, greaterThan(0), reason: 'seed $seed: first stop never restocked');
    }
  });

  test('a stop with no road route is skipped, and the rest of the route is served', () {
    // Two road islands: the truck starts on the first and cannot reach the second.
    final roadTiles = <({double x, double y})>[
      (x: 2.0, y: 1.0),
      (x: 3.0, y: 1.0),
      (x: 4.0, y: 1.0),
      (x: 11.0, y: 10.0),
      (x: 12.0, y: 10.0),
    ];
    Machine at(String id, double x, double y) => Machine(
          id: id,
          name: id,
          zone: Zone(id: 'z$id', type: ZoneType.shop, name: 'Z', x: x, y: y),
          condition: MachineCondition.good,
          inventory: {
            Product.soda: const InventoryItem(
              product: Product.soda,
              quantity: 0,
              dayAdded: 0,
              allocation: 20,
            ),
          },
        );
    final machines = [at('far', 11.5, 9.5), at('near', 3.5, 0.5)];
    final truck = Truck(
      id: 't',
      name: 'T',
      currentX: 2.0,
      currentY: 1.0,
      targetX: 2.0,
      targetY: 1.0,
      status: TruckStatus.traveling,
      route: const ['far', 'near'],
      inventory: const {Product.soda: 40},
    );
    final engine = SimulationEngine(initialMachines: machines, initialTrucks: [truck]);
    engine.setMapLayout(roadTiles);
    engine.updateWarehouseRoadPosition(2.0, 1.0);

    var curMachines = machines;
    var curTrucks = [truck];
    for (var t = 0; t < 3000; t++) {
      final r = engine.tick(curMachines, curTrucks);
      curMachines = r.machines;
      curTrucks = r.trucks;
      // The truck never leaves the first island.
      expect(curTrucks.first.currentX, lessThanOrEqualTo(4.01), reason: 'tick $t: truck crossed to the other island');
    }
    expect(curTrucks.first.isRouteComplete, isTrue);
    expect(curMachines.firstWhere((m) => m.id == 'near').totalSales, greaterThan(0));
  });
}
