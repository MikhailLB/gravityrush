import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/runtime_mode.dart';

class LocalStore {
  static const _runtimeModeKey = 'gr.runtime_mode';
  static const _urlSecretKey = 'gr.cached_target';
  static const _urlExpireKey = 'gr.target_ttl';
  static const _pushCooldownKey = 'gr.push_cooldown_until';
  static const _pushConsentKey = 'gr.push_consent';
  static const _pushPromptBlockedKey = 'gr.push_prompt_blocked';
  static const _pushTargetKey = 'gr.push_target';

  late SharedPreferences _plain;
  final FlutterSecureStorage _vault = const FlutterSecureStorage();

  Future<void> bootstrap() async {
    _plain = await SharedPreferences.getInstance();
  }

  RuntimeMode readRuntimeMode() =>
      RuntimeMode.parse(_plain.getString(_runtimeModeKey));

  Future<void> writeRuntimeMode(RuntimeMode mode) async {
    await _plain.setString(_runtimeModeKey, mode.toStoreString());
  }

  Future<String?> readCachedTarget() => _vault.read(key: _urlSecretKey);

  Future<void> writeCachedTarget(String url) =>
      _vault.write(key: _urlSecretKey, value: url);

  int? _readExpire() => _plain.getInt(_urlExpireKey);

  Future<void> writeTargetExpire(int epochSeconds) async {
    await _plain.setInt(_urlExpireKey, epochSeconds);
  }

  bool isCachedTargetStale() {
    final expires = _readExpire();
    if (expires == null) return true;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return now >= expires;
  }

  bool readPushConsent() => _plain.getBool(_pushConsentKey) ?? false;

  Future<void> writePushConsent(bool allowed) async {
    await _plain.setBool(_pushConsentKey, allowed);
  }

  bool readPushPromptBlocked() =>
      _plain.getBool(_pushPromptBlockedKey) ?? false;

  Future<void> writePushPromptBlocked(bool blocked) async {
    await _plain.setBool(_pushPromptBlockedKey, blocked);
  }

  int? readPushCooldown() => _plain.getInt(_pushCooldownKey);

  Future<void> writePushCooldown(int epochSeconds) async {
    await _plain.setInt(_pushCooldownKey, epochSeconds);
  }

  bool needsPushPrompt() {
    if (readPushConsent()) return false;
    if (readPushPromptBlocked()) return false;
    final cooldown = readPushCooldown();
    if (cooldown == null) return true;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return now >= cooldown;
  }

  Future<String?> peekPushTarget() => _vault.read(key: _pushTargetKey);

  Future<void> writePushTarget(String? url) async {
    if (url == null) {
      await _vault.delete(key: _pushTargetKey);
    } else {
      await _vault.write(key: _pushTargetKey, value: url);
    }
  }

  Future<String?> takePushTarget() async {
    final url = await _vault.read(key: _pushTargetKey);
    if (url != null) {
      await _vault.delete(key: _pushTargetKey);
    }
    return url;
  }
}
