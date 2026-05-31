import 'package:flutter/material.dart';

import '../../core/palette.dart';
import 'glow_button.dart';

/// Full-screen summary shown when a session ends — for both campaign levels
/// (stars + next) and replayable modes (run score + coins + play again).
class ResultOverlay extends StatelessWidget {
  final bool won;
  final bool endless;
  final int stars;
  final int score;
  final int coins;
  final bool hasNext;
  final VoidCallback onRetry;
  final VoidCallback onMenu;
  final VoidCallback? onNext;

  const ResultOverlay({
    super.key,
    required this.won,
    this.endless = false,
    required this.stars,
    required this.score,
    required this.coins,
    required this.hasNext,
    required this.onRetry,
    required this.onMenu,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final String title;
    final Color color;
    if (endless) {
      title = 'RUN OVER';
      color = Palette.gold;
    } else if (won) {
      title = 'LEVEL CLEARED';
      color = Palette.success;
    } else {
      title = 'OUT OF MOVES';
      color = Palette.danger;
    }

    return Container(
      color: Palette.voidDeep.withValues(alpha: 0.85),
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                textAlign: TextAlign.center,
                style: Palette.title(30, color: color, glowColor: color)),
            const SizedBox(height: 24),
            if (!endless && won) _Stars(stars: stars),
            if (!endless && won) const SizedBox(height: 20),
            Text('SCORE', style: Palette.body(13)),
            Text(
              '$score',
              style: TextStyle(
                color: Palette.gold,
                fontSize: 40,
                fontWeight: FontWeight.w900,
                shadows: [Shadow(color: Palette.gold, blurRadius: 16)],
              ),
            ),
            const SizedBox(height: 12),
            _coinPill(),
            const SizedBox(height: 30),
            if (!endless && won && hasNext && onNext != null) ...[
              GlowButton(
                label: 'NEXT LEVEL',
                icon: Icons.arrow_forward_rounded,
                color: Palette.success,
                onTap: onNext,
              ),
              const SizedBox(height: 14),
            ],
            GlowButton(
              label: endless ? 'PLAY AGAIN' : 'RETRY',
              icon: Icons.refresh_rounded,
              color: Palette.accent,
              filled: endless,
              onTap: onRetry,
            ),
            const SizedBox(height: 14),
            GlowButton(
              label: endless ? 'MODES' : 'MAP',
              icon: Icons.grid_view_rounded,
              color: Palette.textMuted,
              filled: false,
              onTap: onMenu,
            ),
          ],
        ),
      ),
    );
  }

  Widget _coinPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: Palette.gold.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Palette.gold.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.monetization_on_rounded,
              color: Palette.gold, size: 22),
          const SizedBox(width: 8),
          Text(
            '+$coins coins',
            style: Palette.body(16, color: Palette.gold, weight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  final int stars;
  const _Stars({required this.stars});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final filled = i < stars;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: filled ? 1 : 0.35),
            duration: Duration(milliseconds: 300 + i * 180),
            curve: Curves.easeOutBack,
            builder: (context, v, _) => Transform.scale(
              scale: 0.7 + v * 0.5,
              child: Icon(
                filled ? Icons.star_rounded : Icons.star_border_rounded,
                size: 56,
                color: filled
                    ? Palette.gold
                    : Palette.textMuted.withValues(alpha: 0.5),
                shadows:
                    filled ? [const Shadow(color: Palette.gold, blurRadius: 18)] : null,
              ),
            ),
          ),
        );
      }),
    );
  }
}
