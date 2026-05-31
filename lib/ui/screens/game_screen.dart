import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/palette.dart';
import '../../data/level.dart';
import '../../data/level_library.dart';
import '../../data/progress_store.dart';
import '../../data/session_config.dart';
import '../../game/session_controller.dart';
import '../widgets/board_view.dart';
import '../widgets/game_hud.dart';
import '../widgets/result_overlay.dart';
import '../widgets/tutorial_coach.dart';
import '../widgets/void_background.dart';

/// Single play surface used by both the campaign and the replayable modes.
///
/// Pass [campaignLevel] for a campaign realm (enables stars, next-level and the
/// first-run tutorial); pass [modeConfigBuilder] for a mode so each retry
/// rebuilds a fresh procedural board.
class GameScreen extends StatefulWidget {
  final ProgressStore progress;
  final Level? campaignLevel;
  final SessionConfig Function() configBuilder;

  const GameScreen({
    super.key,
    required this.progress,
    required this.configBuilder,
    this.campaignLevel,
  });

  /// Convenience constructor for a campaign level.
  factory GameScreen.campaign({
    Key? key,
    required Level level,
    required ProgressStore progress,
  }) {
    return GameScreen(
      key: key,
      progress: progress,
      campaignLevel: level,
      configBuilder: level.buildConfig,
    );
  }

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late SessionController _c;
  late bool _showCoach;
  bool _recorded = false;

  bool get _isCampaign => widget.campaignLevel != null;
  Level? get _level => widget.campaignLevel;

  @override
  void initState() {
    super.initState();
    _showCoach =
        (_level?.tutorial ?? false) && !widget.progress.tutorialDone;
    _start();
  }

  void _start() {
    _c = SessionController(widget.configBuilder())..addListener(_onSession);
    _recorded = false;
  }

  void _onSession() {
    final ended = _c.status == SessionStatus.won || _c.status == SessionStatus.lost;
    if (ended && !_recorded) {
      _recorded = true;
      widget.progress.addCoins(_c.coinsEarned);
      if (_isCampaign && _c.status == SessionStatus.won) {
        widget.progress.recordWin(_level!.index, _c.stars);
        if (_level!.tutorial) widget.progress.markTutorialDone();
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _c.removeListener(_onSession);
    _c.dispose();
    super.dispose();
  }

  void _retry() {
    _c.removeListener(_onSession);
    _c.dispose();
    setState(_start);
  }

  void _next() {
    final nextIndex = (_level?.index ?? 0) + 1;
    if (nextIndex > LevelLibrary.count) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => GameScreen.campaign(
          level: LevelLibrary.byIndex(nextIndex),
          progress: widget.progress,
        ),
      ),
    );
  }

  Set<Point<int>> _hintCells() {
    final l = _level;
    if (l == null) return {};
    final firstMovePending =
        _c.movesLeft == l.moves && _c.status == SessionStatus.ready;
    if (!l.tutorial || !firstMovePending || _showCoach) return {};
    final hint = _c.findHint();
    return hint == null ? {} : hint.toSet();
  }

  @override
  Widget build(BuildContext context) {
    final showResult =
        _c.status == SessionStatus.won || _c.status == SessionStatus.lost;
    final endless = !_isCampaign;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: VoidBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _topBar(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: GameHud(controller: _c),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: BoardView(controller: _c, hintCells: _hintCells()),
                    ),
                  ),
                ],
              ),
              if (_showCoach)
                TutorialCoach(onDone: () => setState(() => _showCoach = false)),
              if (showResult)
                ResultOverlay(
                  won: _c.status == SessionStatus.won,
                  endless: endless,
                  stars: _c.stars,
                  score: _c.score,
                  coins: _c.coinsEarned,
                  hasNext:
                      _isCampaign && (_level!.index < LevelLibrary.count),
                  onRetry: _retry,
                  onMenu: () => Navigator.of(context).pop(),
                  onNext: _isCampaign ? _next : null,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded,
                color: Palette.textPrimary),
            onPressed: () => Navigator.of(context).pop(),
          ),
          if (_isCampaign)
            Text('REALM ${_level!.index}', style: Palette.title(16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _c.cfg.title,
              overflow: TextOverflow.ellipsis,
              style: Palette.body(13, color: Palette.textMuted),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Palette.textMuted),
            onPressed: _retry,
          ),
        ],
      ),
    );
  }
}
