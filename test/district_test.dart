import 'package:flutter_test/flutter_test.dart';
import 'package:vending_empire/config.dart';
import 'package:vending_empire/simulation/models/district.dart';

void main() {
  group('DistrictData', () {
    test('the core district is always free', () {
      final core = DistrictData.getById(DistrictId.core);
      expect(core.unlockCost, 0.0);
    });

    test('outer districts cost more than the core and have a traffic bonus', () {
      final core = DistrictData.getById(DistrictId.core);
      final suburban = DistrictData.getById(DistrictId.suburban);
      final outer = DistrictData.getById(DistrictId.outer);

      expect(suburban.unlockCost, greaterThan(core.unlockCost));
      expect(outer.unlockCost, greaterThan(suburban.unlockCost));
      expect(suburban.trafficBonusMultiplier, greaterThan(1.0));
      expect(outer.trafficBonusMultiplier, greaterThan(suburban.trafficBonusMultiplier));
    });

    test('every DistrictId has exactly one entry', () {
      for (final id in DistrictId.values) {
        expect(() => DistrictData.getById(id), returnsNormally);
      }
      expect(DistrictData.all.length, DistrictId.values.length);
    });
  });

  group('DistrictMath.districtForGridPosition', () {
    const gridSize = AppConfig.cityGridSize; // 15
    const center = (gridSize - 1) ~/ 2; // 7

    test('the exact center is core', () {
      expect(
        DistrictMath.districtForGridPosition(gridX: center, gridY: center, gridSize: gridSize),
        DistrictId.core,
      );
    });

    test('the four corners are outer', () {
      for (final corner in [
        (0, 0),
        (0, gridSize - 1),
        (gridSize - 1, 0),
        (gridSize - 1, gridSize - 1),
      ]) {
        expect(
          DistrictMath.districtForGridPosition(gridX: corner.$1, gridY: corner.$2, gridSize: gridSize),
          DistrictId.outer,
          reason: 'corner $corner should be outer',
        );
      }
    });

    test('district assignment is symmetric across the grid', () {
      // A cell and its mirror image (reflected through the center) must land
      // in the same district - the rings have no preferred direction.
      for (final offset in [1, 2, 3, 4, 5, 6, 7]) {
        final a = DistrictMath.districtForGridPosition(
          gridX: center + offset,
          gridY: center,
          gridSize: gridSize,
        );
        final b = DistrictMath.districtForGridPosition(
          gridX: center - offset,
          gridY: center,
          gridSize: gridSize,
        );
        expect(a, b, reason: 'offset $offset should be symmetric');
      }
    });

    test('districts widen outward with no gaps: core, then suburban, then outer', () {
      DistrictId? previous;
      final order = [DistrictId.core, DistrictId.suburban, DistrictId.outer];
      for (var x = center; x < gridSize; x++) {
        final district = DistrictMath.districtForGridPosition(gridX: x, gridY: center, gridSize: gridSize);
        if (previous != null && previous != district) {
          // Must move strictly forward through core -> suburban -> outer,
          // never skip backward
          expect(order.indexOf(district), greaterThan(order.indexOf(previous!)));
        }
        previous = district;
      }
    });
  });

  group('DistrictMath.districtForZonePosition', () {
    const gridSize = AppConfig.cityGridSize;

    test('matches districtForGridPosition through the zone coordinate offset', () {
      // zoneX = gridX + 1.5, zoneY = gridY + 1.5 (see tile_city_screen.dart)
      for (final grid in [(0, 0), (7, 7), (14, 14), (3, 11)]) {
        final fromGrid = DistrictMath.districtForGridPosition(
          gridX: grid.$1,
          gridY: grid.$2,
          gridSize: gridSize,
        );
        final fromZone = DistrictMath.districtForZonePosition(
          zoneX: grid.$1 + 1.5,
          zoneY: grid.$2 + 1.5,
          gridSize: gridSize,
        );
        expect(fromZone, fromGrid, reason: 'grid $grid');
      }
    });
  });
}
