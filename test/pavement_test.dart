import 'package:flutter_test/flutter_test.dart';
import 'package:vending_empire/ui/screens/tile_city_screen.dart';
import 'package:vending_empire/ui/three_d/city_scene_3d.dart';

void main() {
  // A horizontal road along row 1, with grass above and below it.
  final grid = List.generate(4, (y) => List.generate(4, (x) => y == 1 ? TileType.road : TileType.grass));

  test('the strip beside a road is pavement, and the middle of the road is not', () {
    // Walkers stand 0.1 in from the road's edge, on the grass-facing side.
    expect(isPavementAt(grid, 2.5, 1.1), isTrue, reason: 'the top pavement strip');
    expect(isPavementAt(grid, 2.5, 1.9), isTrue, reason: 'the bottom pavement strip');
    expect(isPavementAt(grid, 2.5, 1.5), isFalse, reason: 'the asphalt in the middle');
  });

  test('grass is never pavement', () {
    expect(isPavementAt(grid, 2.5, 0.5), isFalse);
    expect(isPavementAt(grid, 2.5, 2.5), isFalse);
  });

  test('the edge between two road tiles is asphalt, not pavement', () {
    final wide = [
      [TileType.road, TileType.road],
      [TileType.road, TileType.road],
    ];
    expect(isPavementAt(wide, 1.0, 0.5), isFalse, reason: 'joins two road tiles');
  });
}
