import 'package:flutter/services.dart';

/// Thin wrapper around the platform haptic engine so the whole app can fire
/// vibrations through one switch. [enabled] is synced from the player's setting
/// at start-up.
class Haptics {
  Haptics._();

  static bool enabled = true;

  static void light() {
    if (enabled) HapticFeedback.lightImpact();
  }

  static void medium() {
    if (enabled) HapticFeedback.mediumImpact();
  }

  static void heavy() {
    if (enabled) HapticFeedback.heavyImpact();
  }

  static void select() {
    if (enabled) HapticFeedback.selectionClick();
  }
}
