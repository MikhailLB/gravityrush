import 'package:flutter/material.dart';

import '../../core/elements.dart';
import '../../core/palette.dart';
import '../widgets/void_background.dart';

class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: VoidBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: Palette.textPrimary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Text('HOW TO PLAY', style: Palette.title(20)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _section(
                      icon: Icons.swap_horiz_rounded,
                      title: 'Match Essences',
                      body: 'Swipe an orb toward a neighbour, or tap two '
                          'adjacent orbs, to swap them. Line up three or more '
                          'of the same essence to clear them and score.',
                    ),
                    _essenceRow(),
                    _section(
                      icon: Icons.add_circle_outline_rounded,
                      title: 'Nova Cross',
                      body: 'Match FOUR in a line to forge a Nova Cross. '
                          'Trigger it to detonate its entire row and column.',
                    ),
                    _section(
                      icon: Icons.grain_rounded,
                      title: 'Bloom',
                      body: 'Match an L or T shape to forge a Bloom that '
                          'detonates a 3x3 area around it.',
                    ),
                    _section(
                      icon: Icons.blur_on_rounded,
                      title: 'Prism',
                      body: 'Match FIVE to forge a wild Prism. Swap it with any '
                          'orb to vaporise every essence of that colour. Two '
                          'Prisms together clear the whole board.',
                    ),
                    _corruptionSection(),
                    _section(
                      icon: Icons.flag_rounded,
                      title: 'Reach Your Goals',
                      body: 'Each realm has objectives — a target score, '
                          'essences to collect, or corruption to cleanse. '
                          'Complete them before your moves run out to earn up '
                          'to three stars. Chain reactions for big combos!',
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section({
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Palette.panel.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Palette.panelBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Palette.accentBright, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Palette.title(17)),
                const SizedBox(height: 6),
                Text(body, style: Palette.body(14, color: Palette.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _essenceRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final e in Essence.values)
            Column(
              children: [
                Image.asset(styleOf(e).assetPath, width: 44, height: 44),
                const SizedBox(height: 4),
                Text(styleOf(e).label,
                    style: Palette.body(11, color: Palette.textMuted)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _corruptionSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Palette.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Palette.danger.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(GameArt.corruption, width: 40, height: 40),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cleanse Corruption', style: Palette.title(17)),
                const SizedBox(height: 6),
                Text(
                  'Corruption tiles cannot be moved or matched. Trigger a '
                  'reaction in an orb directly next to them to cleanse them.',
                  style: Palette.body(14, color: Palette.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
