import 'dart:typed_data';

/// XOR-based string obfuscation for secrets stored as byte arrays.
///
/// Seed `bball2.bounce.v3` is unique to BounceBall 2 — byte arrays
/// produced here are NOT interchangeable with any other project.
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

final _keyStream = _buildKeyStream(64);

/// Decode an XOR-encoded byte list back to its plaintext string.
/// Use `tool/encode_creds.dart` to produce byte arrays for new values.
String reveal(List<int> raw) {
  if (raw.isEmpty) return '';
  final n = _keyStream.length;
  final out = Uint8List(raw.length);
  for (var i = 0; i < raw.length; i++) {
    out[i] = raw[i] ^ _keyStream[i % n];
  }
  return String.fromCharCodes(out);
}
