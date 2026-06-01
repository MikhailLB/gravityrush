import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/elements.dart';
import '../core/haptics.dart';
import '../data/objective.dart';
import '../data/session_config.dart';
import '../engine/board.dart';

enum SessionStatus { ready, busy, won, lost }

/// Live progress toward a single [Goal].
class GoalProgress {
  final Goal goal;
  int current;
  GoalProgress(this.goal) : current = 0;
  bool get done => current >= goal.target;
  double get fraction => (current / goal.target).clamp(0.0, 1.0);
}

/// Drives one play session from a [SessionConfig]: owns the [Board], runs the
/// swap → match → react → fall → refill loop, and tracks score, moves, an
/// optional clock and objectives. Works for both campaign levels and the
/// procedurally built game modes (endless, time attack, inferno, zen).
class SessionController extends ChangeNotifier {
  static const int swapMs = 170;
  static const int clearMs = 220;
  static const int fallMs = 250;

  final SessionConfig cfg;
  late final Board board;

  int score = 0;
  int movesLeft;
  int combo = 0;
  int lastGain = 0;
  int coinsEarned = 0;
  double timeLeft;
  SessionStatus status = SessionStatus.ready;

  final List<GoalProgress> goals;
  final Map<Essence, int> _collected = {};
  int _cleansed = 0;

  /// Ids of tiles that are currently animating out of existence.
  final Set<int> clearing = {};

  Timer? _clock;
  bool _disposed = false;

  SessionController(this.cfg)
      : movesLeft = cfg.moves ?? 0,
        timeLeft = cfg.timeSeconds ?? 0,
        goals = cfg.goals.map(GoalProgress.new).toList() {
    board = Board(rows: cfg.rows, cols: cfg.cols, palette: cfg.palette);
    board.populate(cfg.corruption, volatileSeed: cfg.volatileSeed);
    if (!board.hasPossibleMove()) board.reshuffle();
    if (cfg.timed) _startClock();
  }

  bool get timed => cfg.timed;
  bool get endless => cfg.endless;
  bool get allGoalsDone => goals.isNotEmpty && goals.every((g) => g.done);

  int get stars {
    if (cfg.starScores.isEmpty) return 0;
    var s = 0;
    for (final t in cfg.starScores) {
      if (score >= t) s++;
    }
    return max(1, s.clamp(0, 3));
  }

  void _startClock() {
    _clock = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_disposed) return;
      // Don't drain the clock while reactions are animating.
      if (status != SessionStatus.ready) return;
      timeLeft -= 0.1;
      if (timeLeft <= 0) {
        timeLeft = 0;
        _stopClock();
        _setTerminal(allGoalsDone ? SessionStatus.won : SessionStatus.lost);
      } else {
        _ping();
      }
    });
  }

  void _stopClock() {
    _clock?.cancel();
    _clock = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _stopClock();
    super.dispose();
  }

  void _ping() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _wait(int ms) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  /// Attempts to swap two adjacent cells. Invalid swaps animate back and cost
  /// nothing.
  Future<void> trySwap(Point<int> a, Point<int> b) async {
    if (status != SessionStatus.ready) return;
    if (!board.areAdjacent(a, b)) return;
    final ta = board.at(a);
    final tb = board.at(b);
    if (ta == null || tb == null || !ta.movable || !tb.movable) return;

    Haptics.light();
    status = SessionStatus.busy;
    board.swapCells(a, b);
    _ping();
    await _wait(swapMs);

    final outcome = _classifySwap(a, b);
    if (outcome == null) {
      board.swapCells(a, b);
      _ping();
      await _wait(swapMs);
      status = SessionStatus.ready;
      _ping();
      return;
    }

    if (cfg.moveLimited) movesLeft--;
    combo = 0;
    await _applyClear(outcome.cleared, outcome.spawns);
    await _cascade();
    await _settle();
    _finishMoveChecks();
  }

  _SwapPlan? _classifySwap(Point<int> a, Point<int> b) {
    final ta = board.at(a)!;
    final tb = board.at(b)!;

    if (ta.isPrism || tb.isPrism) {
      final prismCell = ta.isPrism ? a : b;
      final other = ta.isPrism ? b : a;
      final otherTile = board.at(other)!;
      final seed = <Point<int>>{prismCell, other};
      if (otherTile.isPrism) {
        for (var r = 0; r < board.rows; r++) {
          for (var c = 0; c < board.cols; c++) {
            seed.add(Point(r, c));
          }
        }
      } else if (otherTile.essence != null) {
        seed.addAll(board.cellsOfEssence(otherTile.essence!));
      }
      return _SwapPlan(board.expandDetonations(seed), const []);
    }

    final scan = board.scanMatches(preferred: {a, b});
    if (scan.isNotEmpty) {
      return _SwapPlan(board.expandDetonations(scan.cleared), scan.spawns);
    }

    if (ta.isSpecial || tb.isSpecial) {
      final seed = <Point<int>>{};
      if (ta.isSpecial) seed.add(a);
      if (tb.isSpecial) seed.add(b);
      return _SwapPlan(board.expandDetonations(seed), const []);
    }
    return null;
  }

  Future<void> _cascade() async {
    while (true) {
      final scan = board.scanMatches();
      if (scan.isEmpty) break;
      await _applyClear(board.expandDetonations(scan.cleared), scan.spawns);
    }
  }

  Future<void> _applyClear(
    Set<Point<int>> cleared,
    List<SpawnSpec> spawns,
  ) async {
    if (cleared.isEmpty && spawns.isEmpty) return;
    combo++;

    final cleansed = board.corruptionTouchedBy(cleared);
    final toRemove = {...cleared, ...cleansed};

    var orbCount = 0;
    var blast = false;
    for (final p in cleared) {
      final t = board.grid[p.x][p.y];
      if (t == null || t.isCorruption) continue;
      orbCount++;
      if (t.isVolatile || t.isSpecial) blast = true;
      if (t.essence != null) {
        _collected[t.essence!] = (_collected[t.essence!] ?? 0) + 1;
      }
    }
    _cleansed += cleansed.length;

    final gain = (orbCount * 20 + cleansed.length * 50) * combo;
    score += gain;
    lastGain = gain;

    if (cfg.timed && cfg.timeBonusPerLine > 0) {
      timeLeft += cfg.timeBonusPerLine;
    }

    // A meatier reaction earns a stronger pulse.
    if (blast || combo > 1 || orbCount >= 5) {
      Haptics.heavy();
    } else {
      Haptics.medium();
    }

    clearing.clear();
    for (final p in toRemove) {
      final t = board.grid[p.x][p.y];
      if (t != null) clearing.add(t.id);
    }
    _ping();
    await _wait(clearMs);

    clearing.clear();
    board.removeCells(toRemove);
    board.forge(spawns);
    board.applyGravity();
    board.refill(volatileChance: cfg.volatileChance);
    _refreshGoals();
    _ping();
    await _wait(fallMs);
  }

  Future<void> _settle() async {
    if (status == SessionStatus.busy && !board.hasPossibleMove()) {
      board.reshuffle();
      _ping();
      await _wait(fallMs);
    }
  }

  void _refreshGoals() {
    for (final g in goals) {
      switch (g.goal.type) {
        case GoalType.score:
          g.current = score;
          break;
        case GoalType.collect:
          g.current = _collected[g.goal.essence] ?? 0;
          break;
        case GoalType.cleanse:
          g.current = _cleansed;
          break;
      }
    }
  }

  void _finishMoveChecks() {
    if (allGoalsDone) {
      _setTerminal(SessionStatus.won);
    } else if (cfg.moveLimited && movesLeft <= 0) {
      _setTerminal(SessionStatus.lost);
    } else {
      status = SessionStatus.ready;
      _ping();
    }
  }

  void _setTerminal(SessionStatus s) {
    if (status == SessionStatus.won || status == SessionStatus.lost) return;
    status = s;
    _stopClock();
    coinsEarned = _computeCoins(s == SessionStatus.won);
    _ping();
  }

  int _computeCoins(bool won) {
    final base = score ~/ 50;
    final bonus = (won && cfg.goals.isNotEmpty) ? stars * 30 : 0;
    return max(0, base + bonus);
  }

  /// Returns a valid swap as `[from, to]`, or null if the board is stuck.
  List<Point<int>>? findHint() {
    for (var r = 0; r < board.rows; r++) {
      for (var c = 0; c < board.cols; c++) {
        final a = Point(r, c);
        for (final b in [Point(r, c + 1), Point(r + 1, c)]) {
          if (!board.inBounds(b.x, b.y)) continue;
          final ta = board.grid[a.x][a.y];
          final tb = board.grid[b.x][b.y];
          if (ta == null || tb == null || !ta.movable || !tb.movable) continue;
          board.swapCells(a, b);
          final hit = board.scanMatches().isNotEmpty || ta.isPrism || tb.isPrism;
          board.swapCells(a, b);
          if (hit) return [a, b];
        }
      }
    }
    return null;
  }
}

class _SwapPlan {
  final Set<Point<int>> cleared;
  final List<SpawnSpec> spawns;
  const _SwapPlan(this.cleared, this.spawns);
}
