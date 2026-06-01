import 'dart:math';

import '../core/elements.dart';
import 'level.dart';
import 'objective.dart';

/// The hand-tuned campaign. Difficulty ramps by widening the essence palette,
/// adding corruption hazards and stacking objectives.
class LevelLibrary {
  LevelLibrary._();

  static const List<Essence> _four = [
    Essence.frost,
    Essence.nature,
    Essence.solar,
    Essence.ember,
  ];

  static const List<Essence> _five = [
    Essence.frost,
    Essence.nature,
    Essence.solar,
    Essence.ember,
    Essence.arcane,
  ];

  static final List<Level> levels = [
    Level(
      index: 1,
      name: 'First Light',
      rows: 7,
      cols: 7,
      palette: _four,
      moves: 25,
      goals: const [Goal.score(700)],
      starScores: const [700, 1400, 2200],
      tutorial: true,
    ),
    Level(
      index: 2,
      name: 'Tidal Step',
      rows: 7,
      cols: 7,
      palette: _four,
      moves: 24,
      goals: const [Goal.score(1600)],
      starScores: const [1600, 2600, 3800],
    ),
    Level(
      index: 3,
      name: 'Solar Harvest',
      rows: 8,
      cols: 7,
      palette: _four,
      moves: 24,
      goals: const [Goal.collect(Essence.solar, 22)],
      volatileSeed: 1,
      starScores: const [1800, 3000, 4400],
    ),
    Level(
      index: 4,
      name: 'Five Winds',
      rows: 8,
      cols: 8,
      palette: _five,
      moves: 26,
      goals: const [Goal.score(3200)],
      volatileSeed: 2,
      starScores: const [3200, 4800, 6800],
    ),
    Level(
      index: 5,
      name: 'Creeping Rot',
      rows: 8,
      cols: 8,
      palette: _five,
      moves: 24,
      goals: const [Goal.cleanse(3)],
      corruption: const [Point(3, 3), Point(3, 4), Point(4, 3)],
      volatileSeed: 2,
      starScores: const [1600, 2800, 4200],
    ),
    Level(
      index: 6,
      name: 'Emberfall',
      rows: 8,
      cols: 8,
      palette: _five,
      moves: 26,
      goals: const [Goal.collect(Essence.ember, 26), Goal.score(2400)],
      volatileSeed: 3,
      starScores: const [2400, 3800, 5400],
    ),
    Level(
      index: 7,
      name: 'Quarantine',
      rows: 8,
      cols: 8,
      palette: _five,
      moves: 26,
      goals: const [Goal.cleanse(5), Goal.score(2600)],
      corruption: const [
        Point(2, 2),
        Point(2, 5),
        Point(5, 2),
        Point(5, 5),
        Point(4, 4),
      ],
      volatileSeed: 3,
      starScores: const [2600, 4200, 6000],
    ),
    Level(
      index: 8,
      name: 'Deep Current',
      rows: 9,
      cols: 8,
      palette: _five,
      moves: 28,
      goals: const [Goal.score(5200)],
      volatileSeed: 4,
      starScores: const [5200, 7400, 9800],
    ),
    Level(
      index: 9,
      name: 'Arcane Bloom',
      rows: 9,
      cols: 8,
      palette: _five,
      moves: 28,
      goals: const [Goal.collect(Essence.arcane, 30), Goal.cleanse(4)],
      corruption: const [Point(0, 3), Point(0, 4), Point(8, 3), Point(8, 4)],
      volatileSeed: 4,
      starScores: const [3000, 5000, 7200],
    ),
    Level(
      index: 10,
      name: 'Containment',
      rows: 9,
      cols: 8,
      palette: _five,
      moves: 28,
      goals: const [Goal.cleanse(6), Goal.score(4000)],
      corruption: const [
        Point(3, 1),
        Point(3, 6),
        Point(4, 0),
        Point(4, 7),
        Point(5, 1),
        Point(5, 6),
      ],
      volatileSeed: 5,
      starScores: const [4000, 6000, 8400],
    ),
    Level(
      index: 11,
      name: 'Twin Storms',
      rows: 9,
      cols: 8,
      palette: _five,
      moves: 30,
      goals: const [
        Goal.collect(Essence.frost, 28),
        Goal.collect(Essence.ember, 28),
      ],
      volatileSeed: 5,
      starScores: const [3600, 5600, 8000],
    ),
    Level(
      index: 12,
      name: 'The Convergence',
      rows: 9,
      cols: 8,
      palette: _five,
      moves: 32,
      goals: const [Goal.score(8000), Goal.cleanse(5)],
      corruption: const [
        Point(2, 3),
        Point(2, 4),
        Point(6, 3),
        Point(6, 4),
        Point(4, 1),
        Point(4, 6),
      ],
      volatileSeed: 7,
      starScores: const [8000, 11000, 14000],
    ),
  ];

  static int get count => levels.length;

  static Level byIndex(int index) =>
      levels.firstWhere((l) => l.index == index, orElse: () => levels.first);
}
