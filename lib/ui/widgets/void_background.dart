import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/palette.dart';

/// A slow, living "deep space" backdrop: a vertical void gradient with drifting
/// motes of light. Used behind every screen for a cohesive identity.
class VoidBackground extends StatefulWidget {
  final Widget child;
  const VoidBackground({super.key, required this.child});

  @override
  State<VoidBackground> createState() => _VoidBackgroundState();
}

class _VoidBackgroundState extends State<VoidBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_Mote> _motes;

  @override
  void initState() {
    super.initState();
    final rng = Random(7);
    _motes = List.generate(46, (i) {
      return _Mote(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        radius: 0.6 + rng.nextDouble() * 2.2,
        speed: 0.01 + rng.nextDouble() * 0.05,
        phase: rng.nextDouble() * pi * 2,
      );
    });
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: Palette.voidGradient),
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) => CustomPaint(
              painter: _MotePainter(_motes, _ctrl.value),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _Mote {
  final double x;
  final double y;
  final double radius;
  final double speed;
  final double phase;
  const _Mote({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.phase,
  });
}

class _MotePainter extends CustomPainter {
  final List<_Mote> motes;
  final double t;
  _MotePainter(this.motes, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..color = Palette.accent.withValues(alpha: 0.05)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60);
    canvas.drawCircle(
        Offset(size.width * 0.2, size.height * 0.25), 160, glow);
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.7),
      200,
      Paint()
        ..color = Palette.gold.withValues(alpha: 0.04)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80),
    );

    final paint = Paint();
    for (final m in motes) {
      final dy = (m.y - t * m.speed * 6) % 1.0;
      final twinkle = 0.4 + 0.6 * (0.5 + 0.5 * sin(t * pi * 2 + m.phase));
      paint.color = Colors.white.withValues(alpha: 0.18 * twinkle);
      canvas.drawCircle(
        Offset(m.x * size.width, dy * size.height),
        m.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MotePainter old) => old.t != t;
}
