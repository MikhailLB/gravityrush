import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reads the cold-start push URL that SceneDelegate captured before Dart code ran.
/// UserDefaults key: `flutter.bb2_gate_cold_url`
class BallTapBridge {
  static const String _key = 'bb2_gate_cold_url';

  static Future<String?> consumeTapUrl() async {
    if (!Platform.isIOS) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.trim().isEmpty) {
        debugPrint('[BB2.NATIVE] consumeTapUrl -> null');
        return null;
      }
      await prefs.remove(_key);
      debugPrint('[BB2.NATIVE] consumeTapUrl -> "$raw"');
      return raw.trim();
    } catch (err) {
      debugPrint('[BB2.NATIVE] consumeTapUrl failed: $err');
      return null;
    }
  }
}
