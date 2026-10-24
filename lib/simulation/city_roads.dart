import 'dart:math' as math;

/// Builds a varied road network on a square grid of [size] tiles.
///
/// The network has three parts. Avenues run across the whole map at
/// uneven spacing, so the blocks between them differ in size. Dead-end streets
/// poke into some blocks from an avenue. A loop street sits in one of the large
/// blocks and joins an avenue. Every road is linked to an avenue, so trucks and
/// pedestrians can reach all of them. Pass a bigger [size] to grow the city.
List<List<bool>> generateRoadMask(int size, math.Random random) {
  final road = List.generate(size, (_) => List.filled(size, false));
  final rows = _avenueLines(size, random);
  final cols = _avenueLines(size, random);

  for (final r in rows) {
    for (var x = 0; x < size; x++) {
      road[r][x] = true;
    }
  }
  for (final c in cols) {
    for (var y = 0; y < size; y++) {
      road[y][c] = true;
    }
  }

  _addDeadEnds(road, rows, cols, random);
  _addLoop(road, rows, cols, random);
  return road;
}

/// Positions of the avenues along one axis. Gaps between them are 3 to 7
/// tiles, so the blocks come in several sizes.
List<int> _avenueLines(int size, math.Random random) {
  final lines = <int>[];
  var pos = 1 + random.nextInt(2);
  while (pos <= size - 2) {
    lines.add(pos);
    pos += 3 + random.nextInt(5);
  }
  if (lines.length < 2) {
    return [size ~/ 3, (size * 2) ~/ 3];
  }
  return lines;
}

void _addDeadEnds(
  List<List<bool>> road,
  List<int> rows,
  List<int> cols,
  math.Random random,
) {
  final size = road.length;
  final count = 2 + random.nextInt(4);
  for (var i = 0; i < count; i++) {
    final length = 2 + random.nextInt(3);
    final side = random.nextBool() ? 1 : -1;
    if (random.nextBool()) {
      // A vertical stub off a horizontal avenue.
      final y = rows[random.nextInt(rows.length)];
      final x = random.nextInt(size);
      _carveStub(road, x, y, 0, side, length);
    } else {
      // A horizontal stub off a vertical avenue.
      final x = cols[random.nextInt(cols.length)];
      final y = random.nextInt(size);
      _carveStub(road, x, y, side, 0, length);
    }
  }
}

/// Carves a straight stub of [length] tiles from the avenue at ([x], [y]). It is
/// only carved where it stays clear of other roads, so it does not join a second
/// street by accident.
void _carveStub(
  List<List<bool>> road,
  int x,
  int y,
  int dx,
  int dy,
  int length,
) {
  final size = road.length;
  bool inside(int cx, int cy) => cx >= 0 && cy >= 0 && cx < size && cy < size;

  final cells = <(int, int)>[];
  for (var k = 1; k <= length; k++) {
    final cx = x + dx * k;
    final cy = y + dy * k;
    if (!inside(cx, cy) || road[cy][cx]) return;
    // The sides of the stub must stay clear of other roads.
    final sideA = dx == 0 ? (cx - 1, cy) : (cx, cy - 1);
    final sideB = dx == 0 ? (cx + 1, cy) : (cx, cy + 1);
    for (final s in [sideA, sideB]) {
      if (inside(s.$1, s.$2) && road[s.$2][s.$1]) return;
    }
    cells.add((cx, cy));
  }
  // The tile past the end must be clear, so the stub is a true dead end.
  final beyondX = x + dx * (length + 1);
  final beyondY = y + dy * (length + 1);
  if (inside(beyondX, beyondY) && road[beyondY][beyondX]) return;

  for (final c in cells) {
    road[c.$2][c.$1] = true;
  }
}

/// Adds a loop street inside one of the larger blocks, joined to the avenue above
/// it by a short connector.
void _addLoop(
  List<List<bool>> road,
  List<int> rows,
  List<int> cols,
  math.Random random,
) {
  final blocks = <(int, int, int, int)>[];
  for (var i = 0; i + 1 < rows.length; i++) {
    for (var j = 0; j + 1 < cols.length; j++) {
      final r1 = rows[i];
      final r2 = rows[i + 1];
      final c1 = cols[j];
      final c2 = cols[j + 1];
      if (r2 - r1 >= 6 && c2 - c1 >= 6) blocks.add((r1, r2, c1, c2));
    }
  }
  if (blocks.isEmpty) return;

  final (r1, r2, c1, c2) = blocks[random.nextInt(blocks.length)];
  final top = r1 + 2;
  final bottom = r2 - 2;
  final left = c1 + 2;
  final right = c2 - 2;
  for (var x = left; x <= right; x++) {
    road[top][x] = true;
    road[bottom][x] = true;
  }
  for (var y = top; y <= bottom; y++) {
    road[y][left] = true;
    road[y][right] = true;
  }
  // Connector from the avenue at r1 down to the top of the loop.
  final midX = (left + right) ~/ 2;
  road[r1 + 1][midX] = true;
}
