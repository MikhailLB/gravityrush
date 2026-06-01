import 'package:flutter/material.dart';

import '../../core/elements.dart';
import '../../core/palette.dart';
import '../../data/objective.dart';
import '../../game/session_controller.dart';

/// Top bar for the game screen: level name, moves remaining, score and a row of
/// live objective chips.
class GameHud extends StatelessWidget {
  final SessionController controller;
  const GameHud({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Palette.panel.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Palette.panelBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (controller.timed)
                _stat('TIME', _fmtTime(controller.timeLeft),
                    _timeColor(controller.timeLeft))
              else if (controller.cfg.moveLimited)
                _stat('MOVES', '${controller.movesLeft}', Palette.accentBright)
              else
                _stat('MODE', controller.cfg.title.toUpperCase(),
                    Palette.accentBright),
              const Spacer(),
              _stat('SCORE', '${controller.score}', Palette.gold),
            ],
          ),
          if (controller.goals.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final g in controller.goals) _GoalChip(progress: g),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _fmtTime(double seconds) {
    final s = seconds.ceil().clamp(0, 5999);
    final m = s ~/ 60;
    final r = s % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
  }

  Color _timeColor(double seconds) =>
      seconds <= 10 ? Palette.danger : Palette.accentBright;

  Widget _stat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Palette.body(11, color: Palette.textMuted)),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
            shadows: [Shadow(color: color, blurRadius: 12)],
          ),
        ),
      ],
    );
  }
}

class _GoalChip extends StatelessWidget {
  final GoalProgress progress;
  const _GoalChip({required this.progress});

  @override
  Widget build(BuildContext context) {
    final goal = progress.goal;
    final done = progress.done;
    final color = done ? Palette.success : Palette.textPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: done
            ? Palette.success.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: done ? Palette.success : Palette.panelBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _icon(),
          const SizedBox(width: 6),
          if (done)
            const Icon(Icons.check_circle, color: Palette.success, size: 18)
          else
            Text(
              '${progress.current}/${goal.target}',
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }

  Widget _icon() {
    switch (progress.goal.type) {
      case GoalType.score:
        return const Icon(Icons.auto_awesome, color: Palette.gold, size: 18);
      case GoalType.cleanse:
        return Image.asset(GameArt.corruption, width: 20, height: 20);
      case GoalType.collect:
        return Image.asset(
          styleOf(progress.goal.essence!).assetPath,
          width: 20,
          height: 20,
        );
    }
  }
}
