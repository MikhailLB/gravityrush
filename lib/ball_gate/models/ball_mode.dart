enum BallMode {
  web,
  game,
  fresh;

  String toKey() {
    switch (this) {
      case BallMode.web:   return 'web';
      case BallMode.game:  return 'game';
      case BallMode.fresh: return 'fresh';
    }
  }

  static BallMode fromKey(String? raw) {
    switch (raw) {
      case 'web': case 'browser': return BallMode.web;
      case 'game': case 'arcade': return BallMode.game;
      default: return BallMode.fresh;
    }
  }
}
