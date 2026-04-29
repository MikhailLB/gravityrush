import 'dart:math' show sin;
import 'dart:ui' show Canvas, Color, Offset, FontWeight, Paint;
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter/painting.dart' show TextStyle, Shadow;
import '../models/skin_data.dart';
import '../utils/constants.dart';
import 'components/peg_board.dart';
import 'components/plinko_ball.dart';
import 'managers/difficulty_manager.dart';
import 'managers/score_manager.dart';
import 'sprite_cache.dart';

enum GameEndReason { died, collected, won }

class GravityRushGame extends FlameGame with PanDetector {
  final SkinData skin;
  final ScoreManager scoreManager = ScoreManager();
  final DifficultyManager difficultyManager = DifficultyManager();
  final SpriteCache spriteCache = SpriteCache();

  late PegBoard _board;
  PegBoard get board => _board;
  PlinkoBall? _activeBall;
  _BallTrail? _trail;

  bool _isGameOver = false;
  bool _waitingForTap = true;
  double _cooldownTimer = 0;
  bool _inCooldown = false;

  GameEndReason? endReason;
  int lastAmount = 0;

  /// Flutter UI listens to this to show/hide the COLLECT button.
  final ValueNotifier<bool> collectAvailable = ValueNotifier(false);

  GravityRushGame({required this.skin}) {
    images.prefix = 'assets/';
  }

  @override
  Color backgroundColor() => const Color(0xFF080818);

  @override
  Future<void> onLoad() async {
    await spriteCache.loadAll(this);
    await scoreManager.loadBalance();
    await _startGame();
  }

  Future<void> _startGame() async {
    _isGameOver = false;
    _waitingForTap = true;
    _inCooldown = false;
    endReason = null;
    lastAmount = 0;
    scoreManager.resetForNewGame();
    difficultyManager.reset();

    _board = PegBoard();
    add(_board);

    _trail = _BallTrail(skin: skin);
    add(_trail!);

    add(_CoinsDisplay());
    add(_PegCounter());
    add(_HintText());
    _updateCollect();
  }

  void _updateCollect() {
    collectAvailable.value =
        _waitingForTap && scoreManager.pendingCoins > 0 && !_isGameOver;
  }

  // --- PanDetector: touch to drop, drag to steer ---

  @override
  void onPanDown(DragDownInfo info) {
    if (_isGameOver || !_waitingForTap || _inCooldown || paused) return;

    _waitingForTap = false;
    collectAvailable.value = false;

    final tapX = info.eventPosition.widget.x;
    final margin = size.x * GameConstants.boardMarginFraction;
    final dropX = tapX.clamp(
      margin + GameConstants.ballRadius,
      size.x - margin - GameConstants.ballRadius,
    );

    scoreManager.resetForNewDrop();
    _board.prepareForDrop(
      moveChance: difficultyManager.movingPegChance,
      moveAmplitude: difficultyManager.movingPegAmplitude,
    );
    _dropBall(dropX);
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    if (_activeBall != null && !_isGameOver && !paused) {
      _activeBall!.applyNudge(info.delta.global.x);
    }
  }

  // --- Ball lifecycle ---

  void _dropBall(double x) {
    final dropY =
        size.y * GameConstants.boardTopFraction - GameConstants.ballRadius;
    _activeBall = PlinkoBall(
      sprite: spriteCache.getSphere(skin.id),
      startPosition: Vector2(x, dropY),
      pegs: _board.pegs,
      pegRadius: _board.actualPegRadius,
      onLanded: _onBallLanded,
      onPegHit: _onPegHit,
      slotsY: _board.slotsY,
      screenWidth: size.x,
    );
    add(_activeBall!);
    _trail?.ball = _activeBall;
    _trail?.clearTrail();
  }

  void _onPegHit(int pegIndex) {
    final bonus = _board.onPegHit(pegIndex);
    if (bonus > 0) {
      scoreManager.onGoldPegHit();
      add(_ScorePopup(
        text: '+$bonus',
        position: _board.pegs[pegIndex].clone(),
        color: const Color(0xFFFFD700),
      ));
    }
  }

  void _onBallLanded(double x) {
    _trail?.ball = null;
    _activeBall?.removeFromParent();
    _activeBall = null;

    final slotIndex = _board.getSlotIndex(x);

    if (_board.isSkullSlot(slotIndex)) {
      _die();
      return;
    }

    final multi = _board.getMultiplier(slotIndex);
    scoreManager.processLanding(multi);

    add(_ScorePopup(
      text: '×$multi',
      position: Vector2(x, _board.slotsY - 20),
      color: const Color(0xFF00FF88),
    ));

    difficultyManager.onDrop();
    _board.generateSlots();

    if (_board.allWhitePegsHit) {
      _win();
      return;
    }

    _inCooldown = true;
    _cooldownTimer = 0.5;
  }

  // --- End conditions ---

  void _die() {
    endReason = GameEndReason.died;
    lastAmount = scoreManager.burn();
    _isGameOver = true;
    collectAvailable.value = false;
    pauseEngine();
    overlays.add('GameOver');
  }

  void _win() {
    endReason = GameEndReason.won;
    lastAmount = scoreManager.collectWithBonus();
    _isGameOver = true;
    collectAvailable.value = false;
    pauseEngine();
    overlays.add('GameOver');
  }

  void collectCoins() {
    if (_isGameOver || scoreManager.pendingCoins <= 0) return;
    endReason = GameEndReason.collected;
    lastAmount = scoreManager.collect();
    _isGameOver = true;
    collectAvailable.value = false;
    pauseEngine();
    overlays.add('GameOver');
  }

  void restart() {
    overlays.remove('GameOver');
    overlays.remove('Pause');
    removeAll(children);
    resumeEngine();
    _startGame();
  }

  void togglePause() {
    if (_isGameOver) return;
    if (paused) {
      resumeEngine();
      overlays.remove('Pause');
    } else {
      pauseEngine();
      overlays.add('Pause');
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_isGameOver) return;

    if (_inCooldown) {
      _cooldownTimer -= dt;
      if (_cooldownTimer <= 0) {
        _inCooldown = false;
        _waitingForTap = true;
        _updateCollect();
      }
    }
  }
}

// ----- Private helper components -----

class _BallTrail extends Component with HasGameReference<GravityRushGame> {
  PlinkoBall? ball;
  final SkinData skin;
  final List<Vector2> _positions = [];
  final Paint _paint = Paint();
  static const int _maxLength = 12;

  _BallTrail({required this.skin}) {
    priority = 5;
  }

  void clearTrail() => _positions.clear();

  @override
  void update(double dt) {
    if (ball == null || !ball!.isMounted) {
      _positions.clear();
      return;
    }
    _positions.add(ball!.position.clone());
    while (_positions.length > _maxLength) {
      _positions.removeAt(0);
    }
  }

  @override
  void render(Canvas canvas) {
    for (int i = 0; i < _positions.length; i++) {
      final t = i / _positions.length;
      _paint.color = skin.primaryColor.withValues(alpha: t * 0.25);
      final r = GameConstants.ballRadius * t * 0.4;
      canvas.drawCircle(Offset(_positions[i].x, _positions[i].y), r, _paint);
    }
  }
}

class _CoinsDisplay extends TextComponent
    with HasGameReference<GravityRushGame> {
  _CoinsDisplay()
      : super(
          anchor: Anchor.topCenter,
          priority: 100,
          textRenderer: TextPaint(
            style: const TextStyle(
              color: Color(0xFFFFFFFF),
              fontSize: 30,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                    color: Color(0xFF000000),
                    blurRadius: 8,
                    offset: Offset(2, 2)),
              ],
            ),
          ),
        );

  @override
  void onLoad() {
    position = Vector2(game.size.x / 2, 32);
  }

  @override
  void update(double dt) {
    super.update(dt);
    text = 'COINS: ${game.scoreManager.pendingCoins}';
  }
}

class _PegCounter extends TextComponent
    with HasGameReference<GravityRushGame> {
  _PegCounter()
      : super(
          anchor: Anchor.topCenter,
          priority: 100,
          textRenderer: TextPaint(
            style: const TextStyle(
              color: Color(0xAAFFFFFF),
              fontSize: 14,
            ),
          ),
        );

  @override
  void onLoad() {
    position = Vector2(game.size.x / 2, 66);
  }

  @override
  void update(double dt) {
    super.update(dt);
    text = 'PEGS: ${game.board.hitWhitePegs}/${game.board.totalWhitePegs}';
  }
}

class _HintText extends TextComponent with HasGameReference<GravityRushGame> {
  double _t = 0;
  late final double _baseX;

  _HintText()
      : super(
          text: '● HIT ALL WHITE PEGS ● DRAG TO STEER ●',
          anchor: Anchor.center,
          priority: 100,
          textRenderer: TextPaint(
            style: const TextStyle(
              color: Color(0x77FFFFFF),
              fontSize: 11,
              letterSpacing: 1.5,
            ),
          ),
        );

  @override
  void onLoad() {
    _baseX = game.size.x / 2;
    position = Vector2(_baseX, 88);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    position.x = _baseX + sin(_t * 1.5) * 12;
  }
}

class _ScorePopup extends TextComponent {
  double _lifetime = 0;

  _ScorePopup({
    required String text,
    required Vector2 position,
    Color color = const Color(0xFF00FF00),
  }) : super(
          text: text,
          position: position,
          anchor: Anchor.center,
          priority: 50,
          textRenderer: TextPaint(
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(color: color, blurRadius: 10)],
            ),
          ),
        );

  @override
  void update(double dt) {
    super.update(dt);
    _lifetime += dt;
    position.y -= 60 * dt;
    if (_lifetime >= 0.8) removeFromParent();
  }
}
