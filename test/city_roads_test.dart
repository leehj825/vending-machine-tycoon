import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vending_empire/simulation/city_roads.dart';

/// Number of road tiles reachable from the first road tile, by walking
/// orthogonal neighbours.
int _reachableRoads(List<List<bool>> road) {
  final size = road.length;
  int? sx, sy;
  var total = 0;
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      if (road[y][x]) {
        total++;
        sx ??= x;
        sy ??= y;
      }
    }
  }
  if (sx == null) return 0;
  final seen = List.generate(size, (_) => List.filled(size, false));
  final queue = Queue<(int, int)>()..add((sx, sy!));
  seen[sy][sx] = true;
  var count = 0;
  while (queue.isNotEmpty) {
    final (x, y) = queue.removeFirst();
    count++;
    for (final (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
      final nx = x + dx;
      final ny = y + dy;
      if (nx < 0 || ny < 0 || nx >= size || ny >= size) continue;
      if (!road[ny][nx] || seen[ny][nx]) continue;
      seen[ny][nx] = true;
      queue.add((nx, ny));
    }
  }
  return count == total ? total : -count;
}

void main() {
  test('every road is connected, for many random layouts', () {
    for (var seed = 0; seed < 300; seed++) {
      final road = generateRoadMask(15, math.Random(seed));
      final total = road.expand((r) => r).where((v) => v).length;
      expect(_reachableRoads(road), total, reason: 'seed $seed');
    }
  });

  test('layouts vary from seed to seed', () {
    final layouts = {
      for (var seed = 0; seed < 20; seed++)
        generateRoadMask(15, math.Random(seed)).map((r) => r.map((v) => v ? '1' : '0').join()).join('\n'),
    };
    expect(layouts.length, greaterThan(15));
  });

  test('a bigger grid still gives a connected network', () {
    final road = generateRoadMask(21, math.Random(7));
    final total = road.expand((r) => r).where((v) => v).length;
    expect(_reachableRoads(road), total);
  });
}
