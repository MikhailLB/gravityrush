import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists campaign progress, coins, unlocked modes and settings.
///
/// It is a [ChangeNotifier]: every mutation fires [notifyListeners] so any menu
/// listening to it (level map, mode shop, home badges) refreshes immediately —
/// even when it was off-screen during a `pushReplacement` chain.
class ProgressStore extends ChangeNotifier {
  static const _kUnlocked = 'em.unlocked';
  static const _kTutorial = 'em.tutorial_done';
  static const _kStarPrefix = 'em.stars.';
  static const _kCoins = 'em.coins';
  static const _kModePrefix = 'em.mode.';
  static const _kHaptics = 'em.haptics';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ---- Coins -------------------------------------------------------------

  int get coins => _prefs.getInt(_kCoins) ?? 0;

  Future<void> addCoins(int amount) async {
    if (amount <= 0) return;
    await _prefs.setInt(_kCoins, coins + amount);
    notifyListeners();
  }

  /// Spends coins if affordable. Returns whether the purchase succeeded.
  Future<bool> spendCoins(int amount) async {
    if (coins < amount) return false;
    await _prefs.setInt(_kCoins, coins - amount);
    notifyListeners();
    return true;
  }

  // ---- Mode unlocks ------------------------------------------------------

  bool isModeUnlocked(String modeId) =>
      _prefs.getBool('$_kModePrefix$modeId') ?? false;

  Future<void> unlockMode(String modeId) async {
    await _prefs.setBool('$_kModePrefix$modeId', true);
    notifyListeners();
  }

  // ---- Settings ----------------------------------------------------------

  bool get hapticsEnabled => _prefs.getBool(_kHaptics) ?? true;

  Future<void> setHaptics(bool value) async {
    await _prefs.setBool(_kHaptics, value);
    notifyListeners();
  }

  // ---- Campaign ----------------------------------------------------------

  int get unlockedLevel => _prefs.getInt(_kUnlocked) ?? 1;

  bool get tutorialDone => _prefs.getBool(_kTutorial) ?? false;

  Future<void> markTutorialDone() async {
    await _prefs.setBool(_kTutorial, true);
    notifyListeners();
  }

  int starsFor(int level) => _prefs.getInt('$_kStarPrefix$level') ?? 0;

  bool isUnlocked(int level) => level <= unlockedLevel;

  int get totalStars {
    var sum = 0;
    for (var i = 1; i <= 64; i++) {
      sum += starsFor(i);
    }
    return sum;
  }

  /// Records the result of a completed level. Keeps the best star count and
  /// unlocks the next level.
  Future<void> recordWin(int level, int stars) async {
    final prev = starsFor(level);
    if (stars > prev) {
      await _prefs.setInt('$_kStarPrefix$level', stars);
    }
    if (level + 1 > unlockedLevel) {
      await _prefs.setInt(_kUnlocked, level + 1);
    }
    notifyListeners();
  }
}
