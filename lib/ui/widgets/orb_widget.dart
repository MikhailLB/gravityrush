import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/elements.dart';
import '../../engine/tile.dart';

/// Renders a single board tile: a plain essence orb, a forged special, or a
/// corruption hazard. Specials decorate the underlying essence sphere so the
/// player can still read their colour at a glance.
class OrbWidget extends StatelessWidget {
  final Tile tile;
  final double size;

  const OrbWidget({super.key, required this.tile, required this.size});

  @override
  Widget build(BuildContext context) {
    switch (tile.kind) {
      case TileKind.corruption:
        return _image(GameArt.corruption);
      case TileKind.prism:
        return _Prism(size: size);
      case TileKind.cross:
        return _decorated(_CrossMark(color: _glow));
      case TileKind.bloom:
        return _decorated(_BloomRing(color: _glow));
      case TileKind.volatileOrb:
        return _decorated(const _VolatileMark());
      case TileKind.orb:
        return _image(styleOf(tile.essence!).assetPath);
    }
  }

  Color get _glow =>
      tile.essence == null ? Colors.white : styleOf(tile.essence!).glow;

  Widget _image(String path) {
    return Padding(
      padding: EdgeInsets.all(size * 0.06),
      child: Image.asset(
        path,
        width: size,
        height: size,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stack) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _decorated(Widget overlay) {
    return Stack(
      alignment: Alignment.center,
      children: [
        _image(styleOf(tile.essence!).assetPath),
        SizedBox(width: size, height: size, child: overlay),
      ],
    );
  }
}

/// The "+" energy mark of a Nova Cross orb.
class _CrossMark extends StatelessWidget {
  final Color color;
  const _CrossMark({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _CrossPainter(color));
  }
}

class _CrossPainter extends CustomPainter {
  final Color color;
  _CrossPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = size.width * 0.07
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2);
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.30;
    canvas.drawLine(Offset(cx - r, cy), Offset(cx + r, cy), p);
    canvas.drawLine(Offset(cx, cy - r), Offset(cx, cy + r), p);
  }

  @override
  bool shouldRepaint(covariant _CrossPainter old) => old.color != color;
}

/// The pulsing ring of a Bloom orb.
class _BloomRing extends StatelessWidget {
  final Color color;
  const _BloomRing({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _RingPainter());
  }
}

class _RingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.06
      ..color = Colors.white.withValues(alpha: 0.85);
    canvas.drawCircle(center, size.width * 0.30, p);
    canvas.drawCircle(
      center,
      size.width * 0.18,
      Paint()..color = Colors.white.withValues(alpha: 0.5),
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => false;
}

/// The instability marker of a volatile orb: a hot core with radiating sparks.
class _VolatileMark extends StatelessWidget {
  const _VolatileMark();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _VolatilePainter());
  }
}

class _VolatilePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.width * 0.16;
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = Colors.white
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3),
    );
    canvas.drawCircle(
      center,
      r * 1.9,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.04
        ..color = const Color(0xFFFFD166),
    );
    final spark = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = size.width * 0.05
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final a = i * (pi / 2) + pi / 4;
      final inner = center + Offset(cos(a), sin(a)) * r * 2.4;
      final outer = center + Offset(cos(a), sin(a)) * r * 3.4;
      canvas.drawLine(inner, outer, spark);
    }
  }

  @override
  bool shouldRepaint(covariant _VolatilePainter old) => false;
}

/// The wild Prism orb: an animated rainbow sweep (no dedicated art asset).
class _Prism extends StatefulWidget {
  final double size;
  const _Prism({required this.size});

  @override
  State<_Prism> createState() => _PrismState();
}

class _PrismState extends State<_Prism> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size * 0.86;
    return Center(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) => Transform.rotate(
          angle: _ctrl.value * 2 * pi,
          child: Container(
            width: s,
            height: s,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const SweepGradient(
                colors: [
                  Color(0xFF4FC3F7),
                  Color(0xFF66BB6A),
                  Color(0xFFFFC107),
                  Color(0xFFEF5350),
                  Color(0xFFAB47BC),
                  Color(0xFF4FC3F7),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.5),
                  blurRadius: 14,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: s * 0.36,
                height: s * 0.36,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
