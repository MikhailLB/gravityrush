import 'dart:math';

import '../core/elements.dart';
import 'objective.dart';
import 'session_config.dart';

/// Static definition of a single playable campaign level.
class Level {
  final int index; // 1-based
  final String name;
  final int rows;
  final int cols;
  final List<Essence> palette;
  final int moves;
  final List<Goal> goals;
  final List<Point<int>> corruption;

  /// Unstable orbs seeded at start. Climbs across the campaign so later realms
  /// crackle with chain explosions.
  final int volatileSeed;

  /// Score thresholds for 1, 2 and 3 stars.
  final List<int> starScores;

  /// First level is a guided tutorial.
  final bool tutorial;

  const Level({
    required this.index,
    required this.name,
    required this.rows,
    required this.cols,
    required this.palette,
    required this.moves,
    required this.goals,
    this.corruption = const [],
    this.volatileSeed = 0,
    required this.starScores,
    this.tutorial = false,
  });

  int starsForScore(int score) {
    var stars = 0;
    for (final s in starScores) {
      if (score >= s) stars++;
    }
    return stars.clamp(0, 3);
  }

  SessionConfig buildConfig() {
    return SessionConfig(
      title: name,
      rows: rows,
      cols: cols,
      palette: palette,
      moves: moves,
      goals: goals,
      corruption: corruption,
      volatileSeed: volatileSeed,
      starScores: starScores,
    );
  }
}
