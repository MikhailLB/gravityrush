import 'package:flutter/material.dart';

import '../../core/palette.dart';

/// A tappable capsule with a soft outer glow. Two visual weights: filled
/// (primary call to action) and outlined (secondary).
class GlowButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final Color color;
  final bool filled;
  final double width;
  final double height;

  const GlowButton({
    super.key,
    required this.label,
    this.icon,
    required this.onTap,
    this.color = Palette.accent,
    this.filled = true,
    this.width = 240,
    this.height = 60,
  });

  @override
  State<GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<GlowButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final color = enabled ? widget.color : Palette.textMuted;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: Container(
          width: widget.width,
          height: widget.height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.filled
                ? color.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color, width: 1.8),
            boxShadow:
                enabled ? Palette.glow(color, blur: _down ? 8 : 18) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: color, size: 22),
                const SizedBox(width: 10),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  shadows: [Shadow(color: color, blurRadius: 12)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
