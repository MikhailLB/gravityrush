import 'dart:math';

import '../core/elements.dart';
import 'tile.dart';

/// A request to forge a special tile at a given cell after a reaction.
class SpawnSpec {
  final Point<int> cell;
  final TileKind kind;
  final Essence? essence;
  const SpawnSpec(this.cell, this.kind, this.essence);
}

/// The outcome of scanning the board for matched lines.
class MatchScan {
  /// Cells whose orbs should be cleared.
  final Set<Point<int>> cleared;

  /// Special tiles to forge once the clear is applied.
  final List<SpawnSpec> spawns;

  const MatchScan(this.cleared, this.spawns);

  bool get isEmpty => cleared.isEmpty && spawns.isEmpty;
  bool get isNotEmpty => !isEmpty;
}

/// Pure logical model of the elemental grid.
///
/// The board knows nothing about animation or rendering; it only mutates its
/// own [grid] and answers questions about matches and reactions. The session
/// controller drives it and decides how to present each step.
class Board {
  final int rows;
  final int cols;
  final List<Essence> palette;
  final Random _rng;

  late final List<List<Tile?>> grid;
  int _idSeq = 0;

  Board({
    required this.rows,
    required this.cols,
    required this.palette,
    Random? rng,
  }) : _rng = rng ?? Random() {
    grid = List.generate(rows, (_) => List<Tile?>.filled(cols, null));
  }

  int _nextId() => ++_idSeq;

  bool inBounds(int r, int c) => r >= 0 && r < rows && c >= 0 && c < cols;
  Tile? at(Point<int> p) => grid[p.x][p.y];

  Essence _randomEssence() => palette[_rng.nextInt(palette.length)];

  Tile _newOrb(Essence e) => Tile(id: _nextId(), kind: TileKind.orb, essence: e);

  /// Fills the board with orbs that contain no pre-existing matches, then
  /// stamps the requested corruption cells and seeds [volatileSeed] unstable
  /// orbs at random movable positions.
  void populate(List<Point<int>> corruption, {int volatileSeed = 0}) {
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        Essence e;
        var guard = 0;
        do {
          e = _randomEssence();
          guard++;
        } while (guard < 24 && _wouldStartLine(r, c, e));
        grid[r][c] = _newOrb(e);
      }
    }
    for (final cell in corruption) {
      if (inBounds(cell.x, cell.y)) {
        grid[cell.x][cell.y] =
            Tile(id: _nextId(), kind: TileKind.corruption);
      }
    }
    var seeded = 0;
    var guard = 0;
    while (seeded < volatileSeed && guard < volatileSeed * 30 + 50) {
      guard++;
      final r = _rng.nextInt(rows);
      final c = _rng.nextInt(cols);
      final t = grid[r][c];
      if (t != null && t.isOrb) {
        t.kind = TileKind.volatileOrb;
        seeded++;
      }
    }
  }

  bool _wouldStartLine(int r, int c, Essence e) {
    if (c >= 2) {
      final a = grid[r][c - 1];
      final b = grid[r][c - 2];
      if (a?.essence == e && b?.essence == e) return true;
    }
    if (r >= 2) {
      final a = grid[r - 1][c];
      final b = grid[r - 2][c];
      if (a?.essence == e && b?.essence == e) return true;
    }
    return false;
  }

  bool areAdjacent(Point<int> a, Point<int> b) {
    final dr = (a.x - b.x).abs();
    final dc = (a.y - b.y).abs();
    return dr + dc == 1;
  }

  void swapCells(Point<int> a, Point<int> b) {
    final tmp = grid[a.x][a.y];
    grid[a.x][a.y] = grid[b.x][b.y];
    grid[b.x][b.y] = tmp;
  }

  /// Scans every row and column for runs of 3+ identical essences and decides
  /// which special tiles (if any) each connected group forges.
  MatchScan scanMatches({Set<Point<int>>? preferred}) {
    final hRuns = <List<Point<int>>>[];
    final vRuns = <List<Point<int>>>[];

    for (var r = 0; r < rows; r++) {
      var c = 0;
      while (c < cols) {
        final run = _runFrom(r, c, dr: 0, dc: 1);
        if (run.length >= 3) hRuns.add(run);
        c += run.isEmpty ? 1 : run.length;
      }
    }
    for (var c = 0; c < cols; c++) {
      var r = 0;
      while (r < rows) {
        final run = _runFrom(r, c, dr: 1, dc: 0);
        if (run.length >= 3) vRuns.add(run);
        r += run.isEmpty ? 1 : run.length;
      }
    }

    final matched = <Point<int>>{};
    for (final run in hRuns) {
      matched.addAll(run);
    }
    for (final run in vRuns) {
      matched.addAll(run);
    }
    if (matched.isEmpty) return const MatchScan({}, []);

    // Cells that sit at the crossing of a horizontal and a vertical line.
    final hCells = <Point<int>>{for (final run in hRuns) ...run};
    final vCells = <Point<int>>{for (final run in vRuns) ...run};
    final intersections = hCells.intersection(vCells);

    // Group matched cells into connected components (4-adjacency, same essence).
    final groups = _connectedGroups(matched);

    final spawns = <SpawnSpec>[];
    final reserved = <Point<int>>{};

    for (final group in groups) {
      final groupSet = group.toSet();
      final cross = intersections.where(groupSet.contains).toList();

      Point<int>? spawnAt;
      TileKind? kind;

      if (cross.isNotEmpty) {
        spawnAt = _pick(cross, preferred);
        kind = TileKind.bloom;
      } else {
        final longest = _longestRunIn(groupSet, hRuns, vRuns);
        if (longest.length >= 5) {
          spawnAt = _pick(longest, preferred);
          kind = TileKind.prism;
        } else if (longest.length == 4) {
          spawnAt = _pick(longest, preferred);
          kind = TileKind.cross;
        }
      }

      if (spawnAt != null && kind != null) {
        reserved.add(spawnAt);
        final essence = kind == TileKind.prism ? null : at(spawnAt)?.essence;
        spawns.add(SpawnSpec(spawnAt, kind, essence));
      }
    }

    matched.removeAll(reserved);
    return MatchScan(matched, spawns);
  }

  List<Point<int>> _runFrom(int r, int c, {required int dr, required int dc}) {
    final first = grid[r][c];
    if (first == null || !first.matchable) return const [];
    final essence = first.essence;
    final run = <Point<int>>[Point(r, c)];
    var rr = r + dr;
    var cc = c + dc;
    while (inBounds(rr, cc)) {
      final t = grid[rr][cc];
      if (t == null || !t.matchable || t.essence != essence) break;
      run.add(Point(rr, cc));
      rr += dr;
      cc += dc;
    }
    return run;
  }

  List<List<Point<int>>> _connectedGroups(Set<Point<int>> cells) {
    final remaining = cells.toSet();
    final groups = <List<Point<int>>>[];
    while (remaining.isNotEmpty) {
      final seed = remaining.first;
      final essence = at(seed)?.essence;
      final stack = <Point<int>>[seed];
      final group = <Point<int>>[];
      remaining.remove(seed);
      while (stack.isNotEmpty) {
        final p = stack.removeLast();
        group.add(p);
        for (final n in _orthogonal(p)) {
          if (remaining.contains(n) && at(n)?.essence == essence) {
            remaining.remove(n);
            stack.add(n);
          }
        }
      }
      groups.add(group);
    }
    return groups;
  }

  List<Point<int>> _longestRunIn(
    Set<Point<int>> group,
    List<List<Point<int>>> hRuns,
    List<List<Point<int>>> vRuns,
  ) {
    var best = <Point<int>>[];
    for (final run in [...hRuns, ...vRuns]) {
      if (run.length > best.length && group.contains(run.first)) {
        best = run;
      }
    }
    return best;
  }

  Point<int> _pick(List<Point<int>> options, Set<Point<int>>? preferred) {
    if (preferred != null) {
      for (final p in options) {
        if (preferred.contains(p)) return p;
      }
    }
    return options[options.length ~/ 2];
  }

  List<Point<int>> _orthogonal(Point<int> p) {
    final out = <Point<int>>[];
    if (p.x > 0) out.add(Point(p.x - 1, p.y));
    if (p.x < rows - 1) out.add(Point(p.x + 1, p.y));
    if (p.y > 0) out.add(Point(p.x, p.y - 1));
    if (p.y < cols - 1) out.add(Point(p.x, p.y + 1));
    return out;
  }

  /// Expands a seed set so that any special tile inside it detonates, possibly
  /// chaining into further specials.
  Set<Point<int>> expandDetonations(Set<Point<int>> seed) {
    final result = <Point<int>>{};
    final stack = seed.toList();
    while (stack.isNotEmpty) {
      final p = stack.removeLast();
      if (!inBounds(p.x, p.y) || result.contains(p)) continue;
      result.add(p);
      final t = grid[p.x][p.y];
      if (t == null) continue;
      switch (t.kind) {
        case TileKind.cross:
          for (var c = 0; c < cols; c++) {
            stack.add(Point(p.x, c));
          }
          for (var r = 0; r < rows; r++) {
            stack.add(Point(r, p.y));
          }
          break;
        case TileKind.bloom:
        case TileKind.prism:
        case TileKind.volatileOrb:
          for (var dr = -1; dr <= 1; dr++) {
            for (var dc = -1; dc <= 1; dc++) {
              stack.add(Point(p.x + dr, p.y + dc));
            }
          }
          break;
        default:
          break;
      }
    }
    return result;
  }

  Set<Point<int>> cellsOfEssence(Essence essence) {
    final out = <Point<int>>{};
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (grid[r][c]?.essence == essence) out.add(Point(r, c));
      }
    }
    return out;
  }

  /// Corruption cells orthogonally adjacent to any cell in [near], or directly
  /// inside [near].
  Set<Point<int>> corruptionTouchedBy(Set<Point<int>> near) {
    final out = <Point<int>>{};
    for (final p in near) {
      if (grid[p.x][p.y]?.isCorruption ?? false) out.add(p);
      for (final n in _orthogonal(p)) {
        if (grid[n.x][n.y]?.isCorruption ?? false) out.add(n);
      }
    }
    return out;
  }

  void forge(List<SpawnSpec> spawns) {
    for (final s in spawns) {
      final existing = grid[s.cell.x][s.cell.y];
      if (existing != null) {
        existing.kind = s.kind;
        existing.essence = s.essence;
      } else {
        grid[s.cell.x][s.cell.y] =
            Tile(id: _nextId(), kind: s.kind, essence: s.essence);
      }
    }
  }

  void removeCells(Set<Point<int>> cells) {
    for (final p in cells) {
      grid[p.x][p.y] = null;
    }
  }

  /// Compacts every column so tiles rest on the bottom (or on corruption,
  /// which also falls). Returns true if anything moved.
  bool applyGravity() {
    var moved = false;
    for (var c = 0; c < cols; c++) {
      var write = rows - 1;
      for (var r = rows - 1; r >= 0; r--) {
        final t = grid[r][c];
        if (t != null) {
          if (write != r) {
            grid[write][c] = t;
            grid[r][c] = null;
            moved = true;
          }
          write--;
        }
      }
    }
    return moved;
  }

  /// Drops fresh orbs into the empty cells at the top of each column. With
  /// probability [volatileChance] a fresh orb spawns unstable instead.
  /// Returns the ids of the newly created tiles.
  Set<int> refill({double volatileChance = 0}) {
    final fresh = <int>{};
    for (var c = 0; c < cols; c++) {
      for (var r = 0; r < rows; r++) {
        if (grid[r][c] == null) {
          final orb = _newOrb(_randomEssence());
          if (volatileChance > 0 && _rng.nextDouble() < volatileChance) {
            orb.kind = TileKind.volatileOrb;
          }
          grid[r][c] = orb;
          fresh.add(orb.id);
        }
      }
    }
    return fresh;
  }

  /// Whether any legal swap exists that would create a match. Used to detect
  /// dead boards and reshuffle.
  bool hasPossibleMove() {
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        for (final n in [Point(r, c + 1), Point(r + 1, c)]) {
          if (!inBounds(n.x, n.y)) continue;
          final a = Point(r, c);
          if (!(grid[r][c]?.movable ?? false)) continue;
          if (!(grid[n.x][n.y]?.movable ?? false)) continue;
          swapCells(a, n);
          final hit = scanMatches().isNotEmpty;
          swapCells(a, n);
          if (hit) return true;
        }
      }
    }
    return false;
  }

  /// Shuffles all movable orbs in place (keeps corruption where it is) until a
  /// move exists and no immediate match is present.
  void reshuffle() {
    final movable = <Tile>[];
    final slots = <Point<int>>[];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final t = grid[r][c];
        if (t != null && t.movable) {
          movable.add(t);
          slots.add(Point(r, c));
        }
      }
    }
    var attempts = 0;
    do {
      movable.shuffle(_rng);
      for (var i = 0; i < slots.length; i++) {
        grid[slots[i].x][slots[i].y] = movable[i];
      }
      attempts++;
    } while (attempts < 40 &&
        (scanMatches().isNotEmpty || !hasPossibleMove()));
  }
}
