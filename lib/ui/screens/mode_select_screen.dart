import 'package:flutter/material.dart';

import '../../core/haptics.dart';
import '../../core/palette.dart';
import '../../data/game_mode.dart';
import '../../data/progress_store.dart';
import '../widgets/glow_button.dart';
import '../widgets/void_background.dart';
import 'game_screen.dart';

/// Lists the unlockable game modes and handles purchasing them with coins.
class ModeSelectScreen extends StatefulWidget {
  final ProgressStore progress;
  const ModeSelectScreen({super.key, required this.progress});

  @override
  State<ModeSelectScreen> createState() => _ModeSelectScreenState();
}

class _ModeSelectScreenState extends State<ModeSelectScreen> {
  @override
  void initState() {
    super.initState();
    widget.progress.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.progress.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _play(GameMode mode) async {
    Haptics.select();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          progress: widget.progress,
          configBuilder: mode.build,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _unlock(GameMode mode) async {
    final ok = await widget.progress.spendCoins(mode.price);
    if (!mounted) return;
    if (ok) {
      await widget.progress.unlockMode(mode.id);
      Haptics.heavy();
      if (mounted) setState(() {});
    } else {
      Haptics.light();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Palette.danger.withValues(alpha: 0.9),
          duration: const Duration(milliseconds: 1400),
          content: Text(
            'Not enough coins — earn more by playing!',
            style: Palette.body(14, color: Colors.white),
          ),
        ),
      );
    }
  }

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
                    Text('GAME MODES', style: Palette.title(20)),
                    const Spacer(),
                    _coinBadge(),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    for (final mode in GameMode.all) _modeCard(mode),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _coinBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Palette.gold.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.gold.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.monetization_on_rounded,
              color: Palette.gold, size: 18),
          const SizedBox(width: 6),
          Text('${widget.progress.coins}',
              style: Palette.body(15, color: Palette.gold, weight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _modeCard(GameMode mode) {
    final unlocked = widget.progress.isModeUnlocked(mode.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            mode.color.withValues(alpha: 0.18),
            Palette.panel.withValues(alpha: 0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: mode.color.withValues(alpha: 0.6), width: 1.5),
        boxShadow: unlocked ? Palette.glow(mode.color, blur: 16) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: mode.color.withValues(alpha: 0.2),
                  border: Border.all(color: mode.color),
                ),
                child: Icon(mode.icon, color: mode.color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mode.name, style: Palette.title(18)),
                    const SizedBox(height: 4),
                    Text(mode.tagline,
                        style: Palette.body(12, color: Palette.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (unlocked)
            GlowButton(
              label: 'PLAY',
              icon: Icons.play_arrow_rounded,
              color: mode.color,
              width: double.infinity,
              height: 50,
              onTap: () => _play(mode),
            )
          else
            GlowButton(
              label: 'UNLOCK  ${mode.price}',
              icon: Icons.lock_open_rounded,
              color: Palette.gold,
              filled: false,
              width: double.infinity,
              height: 50,
              onTap: () => _unlock(mode),
            ),
        ],
      ),
    );
  }
}
