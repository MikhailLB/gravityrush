import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

/// Reads the cold-start push URL that the native scene layer captured before
/// Dart code ran, via a SharedPreferences-readable UserDefaults key.
class BallTapBridge {
  static const String _key = 'vt9k_cold_tap';

  static Future<String?> consumeTapUrl() async {
    if (!Platform.isIOS) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.trim().isEmpty) return null;
      await prefs.remove(_key);
      return raw.trim();
    } catch (_) {
      return null;
    }
  }
}
