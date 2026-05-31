import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:bounce_ball_two/core/elements.dart';
import 'package:bounce_ball_two/engine/board.dart';
import 'package:bounce_ball_two/engine/tile.dart';

Board _board(List<List<Essence>> layout) {
  final rows = layout.length;
  final cols = layout.first.length;
  final b = Board(rows: rows, cols: cols, palette: Essence.values);
  var id = 0;
  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < cols; c++) {
      b.grid[r][c] =
          Tile(id: ++id, kind: TileKind.orb, essence: layout[r][c]);
    }
  }
  return b;
}

void main() {
  const f = Essence.frost;
  const n = Essence.nature;
  const s = Essence.solar;
  const e = Essence.ember;

  test('detects a horizontal three-in-a-row', () {
    final b = _board([
      [f, f, f],
      [n, s, e],
      [s, e, n],
    ]);
    final scan = b.scanMatches();
    expect(scan.cleared, containsAll([Point(0, 0), Point(0, 1), Point(0, 2)]));
    expect(scan.spawns, isEmpty);
  });

  test('a line of four forges a cross', () {
    final b = _board([
      [f, f, f, f],
      [n, s, e, n],
      [s, e, n, s],
    ]);
    final scan = b.scanMatches();
    expect(scan.spawns.length, 1);
    expect(scan.spawns.first.kind, TileKind.cross);
    // The forged cell is reserved (not cleared) so the special survives.
    expect(scan.cleared.length, 3);
  });

  test('gravity collapses columns downward', () {
    final b = _board([
      [f, n, s],
      [n, s, e],
      [s, e, n],
    ]);
    b.removeCells({Point(2, 0), Point(2, 1), Point(2, 2)});
    b.applyGravity();
    expect(b.grid[2][0], isNotNull);
    expect(b.grid[0][0], isNull);
  });

  test('refill fills every empty cell', () {
    final b = _board([
      [f, n],
      [n, s],
    ]);
    b.removeCells({Point(0, 0), Point(0, 1)});
    final fresh = b.refill();
    expect(fresh.length, 2);
    expect(b.grid[0][0], isNotNull);
    expect(b.grid[0][1], isNotNull);
  });

  test('corruption is cleansed when a match clears next to it', () {
    final b = _board([
      [f, f, f],
      [n, s, e],
      [s, e, n],
    ]);
    b.grid[1][0] = Tile(id: 999, kind: TileKind.corruption);
    final scan = b.scanMatches();
    final cleansed = b.corruptionTouchedBy(scan.cleared);
    expect(cleansed, contains(Point(1, 0)));
  });
}
