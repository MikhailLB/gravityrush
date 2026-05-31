import '../core/elements.dart';

enum GoalType {
  /// Reach a target score.
  score,

  /// Clear a number of orbs of a specific essence.
  collect,

  /// Cleanse a number of corruption tiles.
  cleanse,
}

/// A single win condition for a level. A level is won once every goal is met.
class Goal {
  final GoalType type;
  final int target;
  final Essence? essence;

  const Goal.score(this.target)
      : type = GoalType.score,
        essence = null;

  const Goal.collect(this.essence, this.target) : type = GoalType.collect;

  const Goal.cleanse(this.target)
      : type = GoalType.cleanse,
        essence = null;

  String describe() {
    switch (type) {
      case GoalType.score:
        return 'Score $target';
      case GoalType.collect:
        return 'Clear $target ${styleOf(essence!).label}';
      case GoalType.cleanse:
        return 'Cleanse $target corruption';
    }
  }
}
