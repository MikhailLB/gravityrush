import 'package:flutter/material.dart';

/// Central colour + typography palette for the whole app.
///
/// The game's identity is a deep "void" backdrop with luminous elemental
/// accents, so most surfaces are very dark and text leans on soft glows.
class Palette {
  Palette._();

  static const Color voidTop = Color(0xFF1A1140);
  static const Color voidMid = Color(0xFF0C0A24);
  static const Color voidDeep = Color(0xFF050410);

  static const Color panel = Color(0xFF161334);
  static const Color panelBorder = Color(0xFF2E2A5A);

  static const Color accent = Color(0xFF8E7BFF);
  static const Color accentBright = Color(0xFFB9A8FF);
  static const Color gold = Color(0xFFFFC94D);
  static const Color danger = Color(0xFFFF4D6D);
  static const Color success = Color(0xFF5BE6A8);

  static const Color textPrimary = Color(0xFFF2EEFF);
  static const Color textMuted = Color(0xFF9A93C9);

  static const LinearGradient voidGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [voidTop, voidMid, voidDeep],
  );

  static List<BoxShadow> glow(Color color, {double blur = 18, double spread = 0}) {
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.55),
        blurRadius: blur,
        spreadRadius: spread,
      ),
    ];
  }

  static TextStyle title(double size, {Color color = textPrimary, Color? glowColor}) {
    return TextStyle(
      color: color,
      fontSize: size,
      fontWeight: FontWeight.w800,
      letterSpacing: 2,
      shadows: glowColor == null
          ? null
          : [Shadow(color: glowColor, blurRadius: 16)],
    );
  }

  static TextStyle body(double size, {Color color = textMuted, FontWeight weight = FontWeight.w500}) {
    return TextStyle(
      color: color,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: 0.4,
      height: 1.35,
    );
  }
}
