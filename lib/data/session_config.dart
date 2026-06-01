import 'dart:math';

import '../core/elements.dart';
import 'objective.dart';

/// Everything the [SessionController] needs to run a single play session,
/// whether it comes from a campaign [Level] or a procedurally built game mode.
class SessionConfig {
  final String title;
  final int rows;
  final int cols;
  final List<Essence> palette;

  /// Move budget; `null` means unlimited moves.
  final int? moves;

  /// Starting time in seconds; `null` means untimed.
  final double? timeSeconds;

  /// Seconds added to the clock for every cleared line (used by timed modes).
  final double timeBonusPerLine;

  /// Win conditions. Empty means a score / endless session with no goals.
  final List<Goal> goals;

  final List<Point<int>> corruption;

  /// Number of unstable orbs seeded at start.
  final int volatileSeed;

  /// Per-refill chance to drop an unstable orb (keeps timed modes spicy).
  final double volatileChance;

  /// Score thresholds for 1/2/3 stars (campaign only).
  final List<int> starScores;

  /// When true the session never auto-wins; it runs until time or moves end.
  final bool endless;

  const SessionConfig({
    required this.title,
    required this.rows,
    required this.cols,
    required this.palette,
    this.moves,
    this.timeSeconds,
    this.timeBonusPerLine = 0,
    this.goals = const [],
    this.corruption = const [],
    this.volatileSeed = 0,
    this.volatileChance = 0,
    this.starScores = const [],
    this.endless = false,
  });

  bool get timed => timeSeconds != null;
  bool get moveLimited => moves != null;
}
