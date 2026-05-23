// ignore_for_file: avoid_print
import 'dart:typed_data';

/// ════════════════════════════════════════════════════════════
/// BounceBall 2 (GravityRush) — credential encoder
/// ════════════════════════════════════════════════════════════
///
/// USAGE:
///   dart run tool/encode_creds.dart
///
/// ⚠️  Always run with `dart run`, NEVER PowerShell foreach loops.
/// PowerShell overflows 32-bit integers → wrong byte values.
///
/// The _seedBytes MUST match _seedBytes in lib/ball_vault/ball_cipher.dart.
/// ════════════════════════════════════════════════════════════

const _seedBytes = <int>[
  0x62, 0x62, 0x61, 0x6C, 0x6C, 0x32, 0x2E, 0x62,
  0x6F, 0x75, 0x6E, 0x63, 0x65, 0x2E, 0x76, 0x33,
];

Uint8List _buildKeyStream(int size) {
  var hash = 0x811C9DC5;
  for (final b in _seedBytes) {
    hash = ((hash ^ b) * 0x01000193) & 0xFFFFFFFF;
  }
  final out = Uint8List(size);
  var state = hash == 0 ? 0xC0DEBABE : hash;
  for (var i = 0; i < size; i++) {
    state = (state * 22695477 + 1) & 0x7FFFFFFF;
    out[i] = (state >> 11) & 0xFF;
  }
  return out;
}

final _stream = _buildKeyStream(64);

List<int> encode(String s) {
  final out = <int>[];
  for (var i = 0; i < s.length; i++) {
    out.add(s.codeUnitAt(i) ^ _stream[i % _stream.length]);
  }
  return out;
}

String fmt(List<int> v) => '[${v.join(', ')}]';

void main() {
  // ⚠️  FILL IN YOUR ACTUAL VALUES BELOW
  const configHost   = 'https://bounceball2.com';          // TODO: confirmed
  const configPath   = '/config.php';
  const gcdHost      = 'https://gcdsdk.appsflyer.com/install_data/v4.0/';
  const appsflyerKey = 'TODO_APPSFLYER_DEV_KEY';           // TODO: will be provided
  const firebaseProj = 'TODO_FIREBASE_PROJECT_NUMBER';     // TODO: will be provided
  const privacyUrl   = 'https://bounceball2.com/privacy-policy.html';
  const supportUrl   = 'https://bounceball2.com/support.html';

  print('// ── ball_endpoint.dart ──────────────────────────');
  print('const h = ${fmt(encode(configHost))};  // host');
  print('const p = ${fmt(encode(configPath))};  // path');
  print('');
  print('// ── ball_endpoint.dart — GCD ────────────────────');
  print('const _gcdMask = ${fmt(encode(gcdHost))};');
  print('');
  print('// ── signal_keys.dart — AppsFlyer key ────────────');
  print('const v = ${fmt(encode(appsflyerKey))};');
  print('');
  print('// ── signal_keys.dart — Firebase project number ──');
  print('const v = ${fmt(encode(firebaseProj))};');
  print('');
  print('// ── brand_links.dart — privacy URL ──────────────');
  print('const _privacyMask = ${fmt(encode(privacyUrl))};');
  print('');
  print('// ── brand_links.dart — support URL ──────────────');
  print('const _supportMask = ${fmt(encode(supportUrl))};');
  print('');
  print('// ── VERIFICATION ─────────────────────────────────');
  print('// configUrl  : $configHost$configPath');
  print('// afKey      : $appsflyerKey');
  print('// firebaseNum: $firebaseProj');
}
