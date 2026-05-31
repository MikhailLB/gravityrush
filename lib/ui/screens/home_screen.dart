import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/elements.dart';
import '../../core/palette.dart';
import '../../data/progress_store.dart';
import '../widgets/glow_button.dart';
import '../widgets/void_background.dart';
import 'how_to_play_screen.dart';
import 'legal_screen.dart';
import 'level_select_screen.dart';
import 'mode_select_screen.dart';

/// Vibrant title screen: a logo orbited by the five essence orbs beneath a
/// shimmering animated title, with quick access to the campaign and modes.
class HomeScreen extends StatefulWidget {
  final ProgressStore progress;
  const HomeScreen({super.key, required this.progress});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late final AnimationController _orbit;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _orbit = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    widget.progress.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.progress.removeListener(_refresh);
    _orbit.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: VoidBackground(
        child: SafeArea(
          child: Column(
            children: [
              _topStrip(),
              const Spacer(flex: 2),
              _orbitingCrest(),
              const SizedBox(height: 28),
              _shimmerTitle(),
              const SizedBox(height: 8),
              Text('MATCH · REACT · EXPLODE',
                  style: Palette.body(13, color: Palette.accentBright)),
              const Spacer(flex: 2),
              _pulsingPlay(),
              const SizedBox(height: 16),
              GlowButton(
                label: 'GAME MODES',
                icon: Icons.dashboard_customize_rounded,
                color: Palette.gold,
                filled: false,
                onTap: () =>
                    _open(ModeSelectScreen(progress: widget.progress)),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _miniButton(Icons.menu_book_rounded, 'How to Play',
                      () => _open(const HowToPlayScreen())),
                  const SizedBox(width: 14),
                  _miniButton(Icons.settings_rounded, 'Settings',
                      () => _open(LegalScreen(progress: widget.progress))),
                ],
              ),
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topStrip() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          _badge(Icons.star_rounded, '${widget.progress.totalStars}',
              Palette.gold),
          const Spacer(),
          _badge(Icons.monetization_on_rounded, '${widget.progress.coins}',
              Palette.gold),
        ],
      ),
    );
  }

  Widget _badge(IconData icon, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Palette.panel.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Palette.panelBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 7),
          Text(value,
              style: Palette.body(15, color: color, weight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _orbitingCrest() {
    const box = 260.0;
    const radius = 104.0;
    const orbSize = 46.0;
    final essences = Essence.values;

    return SizedBox(
      width: box,
      height: box,
      child: AnimatedBuilder(
        animation: _orbit,
        builder: (context, child) {
          final orbs = <Widget>[];
          for (var i = 0; i < essences.length; i++) {
            final angle =
                _orbit.value * 2 * pi + i * (2 * pi / essences.length);
            final cx = box / 2 + cos(angle) * radius - orbSize / 2;
            final cy = box / 2 + sin(angle) * radius - orbSize / 2;
            final depth = 0.7 + 0.3 * sin(angle);
            orbs.add(Positioned(
              left: cx,
              top: cy,
              child: Opacity(
                opacity: depth,
                child: Image.asset(styleOf(essences[i]).assetPath,
                    width: orbSize * depth, height: orbSize * depth),
              ),
            ));
          }
          return Stack(alignment: Alignment.center, children: [...orbs, child!]);
        },
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) => Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: Palette.glow(Palette.accent,
                  blur: 40 + _pulse.value * 30, spread: 4),
            ),
            child: child,
          ),
          child: ClipOval(
            child: Image.asset(GameArt.logo, width: 132, height: 132),
          ),
        ),
      ),
    );
  }

  Widget _shimmerTitle() {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final t = _pulse.value;
        return ShaderMask(
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment(-1 + t * 2, 0),
            end: Alignment(1 + t * 2, 0),
            colors: const [
              Palette.accentBright,
              Palette.gold,
              Color(0xFF4FC3F7),
              Palette.accentBright,
            ],
          ).createShader(rect),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'BOUNCE BALL 2',
                maxLines: 1,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                  shadows: [Shadow(color: Palette.accent, blurRadius: 24)],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _pulsingPlay() {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => Transform.scale(
        scale: 1 + _pulse.value * 0.05,
        child: child,
      ),
      child: GlowButton(
        label: 'PLAY',
        icon: Icons.play_arrow_rounded,
        width: 260,
        height: 66,
        onTap: () => _open(LevelSelectScreen(progress: widget.progress)),
      ),
    );
  }

  Widget _miniButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Palette.panel.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Palette.panelBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Palette.accentBright, size: 18),
            const SizedBox(width: 8),
            Text(label,
                style: Palette.body(13, color: Palette.textPrimary)),
          ],
        ),
      ),
    );
  }
}
