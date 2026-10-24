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
      expect(curMachines.first.totalSales, greaterThan(0), reason: 'seed $seed: first stop never restocked');
    }
  });
}
