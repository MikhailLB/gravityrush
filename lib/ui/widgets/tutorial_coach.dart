import 'package:flutter/material.dart';

import '../../core/elements.dart';
import '../../core/palette.dart';
import 'glow_button.dart';

class CoachStep {
  final String title;
  final String body;
  final IconData icon;
  const CoachStep(this.title, this.body, this.icon);
}

/// First-run coaching shown on the tutorial level: a small stack of cards the
/// player swipes through before taking control.
class TutorialCoach extends StatefulWidget {
  final VoidCallback onDone;
  const TutorialCoach({super.key, required this.onDone});

  static const steps = <CoachStep>[
    CoachStep(
      'Align the Essences',
      'Swap two neighbouring orbs to line up three or more of the same '
          'essence. Matched orbs burst and the board refills from above.',
      Icons.swap_horiz_rounded,
    ),
    CoachStep(
      'Forge Reactions',
      'Line up FOUR to forge a Nova Cross that clears its whole row and '
          'column. Make an L or T shape for a 3x3 Bloom.',
      Icons.add_circle_outline_rounded,
    ),
    CoachStep(
      'Unleash the Prism',
      'Line up FIVE to forge a wild Prism. Swap it with any orb to vaporise '
          'every essence of that colour at once.',
      Icons.blur_on_rounded,
    ),
    CoachStep(
      'Cleanse Corruption',
      'The skull is corruption — it cannot be moved. Trigger a reaction right '
          'next to it to cleanse it. Clear your goals before moves run out!',
      Icons.dangerous_outlined,
    ),
  ];

  @override
  State<TutorialCoach> createState() => _TutorialCoachState();
}

class _TutorialCoachState extends State<TutorialCoach> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final step = TutorialCoach.steps[_i];
    final last = _i == TutorialCoach.steps.length - 1;

    return Container(
      color: Palette.voidDeep.withValues(alpha: 0.88),
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(GameArt.logo, width: 64, height: 64),
            const SizedBox(height: 8),
            Text('HOW TO PLAY', style: Palette.body(12, color: Palette.accentBright)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Palette.panel,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Palette.accent.withValues(alpha: 0.5)),
                boxShadow: Palette.glow(Palette.accent, blur: 26),
              ),
              child: Column(
                children: [
                  Icon(step.icon, size: 46, color: Palette.accentBright),
                  const SizedBox(height: 14),
                  Text(
                    step.title,
                    textAlign: TextAlign.center,
                    style: Palette.title(20, glowColor: Palette.accent),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    step.body,
                    textAlign: TextAlign.center,
                    style: Palette.body(15, color: Palette.textPrimary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                TutorialCoach.steps.length,
                (i) => Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _i ? Palette.accentBright : Palette.panelBorder,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            GlowButton(
              label: last ? 'START' : 'NEXT',
              icon: last ? Icons.play_arrow_rounded : Icons.arrow_forward_rounded,
              onTap: () {
                if (last) {
                  widget.onDone();
                } else {
                  setState(() => _i++);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
