import 'dart:typed_data';

/// Position-aware XOR masking for values that must not sit in the binary as
/// plaintext. The scheme is intentionally bespoke to this build: a dual
/// accumulator digest of the seed feeds an xorshift32 keystream, and every
/// output byte is additionally folded with an index-derived value so the
/// stream never repeats verbatim. Byte arrays produced here are not portable
/// to any other build.
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

/// Restore a masked byte list back to its plaintext string.
/// Use `tool/encode_creds.dart` (identical scheme) to produce new arrays.
String unmask(List<int> raw) {
  if (raw.isEmpty) return '';
  final n = _stream.length;
  final out = Uint8List(raw.length);
  for (var i = 0; i < raw.length; i++) {
    out[i] = (raw[i] ^ _stream[i % n] ^ _fold(i)) & 0xFF;
  }
  return String.fromCharCodes(out);
}
