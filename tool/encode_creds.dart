// ignore_for_file: avoid_print
import 'dart:typed_data';

/// ════════════════════════════════════════════════════════════
/// BounceBall 2 — credential encoder
/// ════════════════════════════════════════════════════════════
///
/// USAGE:
///   dart run tool/encode_creds.dart
///
/// The masking scheme MUST stay byte-for-byte identical to
/// lib/mask/byte_mask.dart (seed, stream length, digest, keystream,
/// index fold). If you change one, change both.
/// ════════════════════════════════════════════════════════════

const _seedBytes = <int>[
  0x9E, 0x37, 0x79, 0xB9, 0x15, 0xC2, 0x6A, 0x4F,
  0x83, 0x2D, 0xD1, 0x07, 0xBE, 0x52, 0xA8, 0x6C,
  0x31, 0xF0, 0x4D, 0x99,
];

const int _streamLen = 80;

int _digest() {
  var a = 0x1F3D5B79;
  var b = 0x6A09E667;
  for (final c in _seedBytes) {
    a = ((a + c) * 0x27D4EB2F) & 0xFFFFFFFF;
    a = ((a << 13) | (a >> 19)) & 0xFFFFFFFF;
    b ^= a;
    b = (b * 0x85EBCA6B) & 0xFFFFFFFF;
  }
  return (a ^ b) & 0xFFFFFFFF;
}

Uint8List _buildStream(int size) {
  var x = _digest();
  if (x == 0) x = 0x9E3779B9;
  final out = Uint8List(size);
  for (var i = 0; i < size; i++) {
    x ^= (x << 13) & 0xFFFFFFFF;
    x ^= x >> 17;
    x ^= (x << 5) & 0xFFFFFFFF;
    x &= 0xFFFFFFFF;
    out[i] = (x >> 3) & 0xFF;
  }
  return out;
}

final _stream = _buildStream(_streamLen);

int _fold(int i) => (i * 0x9E + 0x37) & 0xFF;

List<int> encode(String s) {
  final out = <int>[];
  for (var i = 0; i < s.length; i++) {
    out.add((s.codeUnitAt(i) ^ _stream[i % _stream.length] ^ _fold(i)) & 0xFF);
  }
  return out;
}

String fmt(List<int> v) => '[${v.join(', ')}]';

void main() {
  const configHost   = 'https://bounceball2.com';
  const configPath   = '/config.php';
  const gcdHost      = 'https://gcdsdk.appsflyer.com/install_data/v4.0/';
  const appsflyerKey = 'CxSYrWEffvrqpPCDTAmBU5';
  const firebaseProj = '640771992930';
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
}
