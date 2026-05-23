import '../../ball_vault/ball_cipher.dart';

String ballEndpointUrl() {
  const h = [105, 162, 82, 6, 80, 20, 8, 1, 93, 217, 151, 125, 125, 223, 0, 231, 131, 125, 238, 28, 170, 247, 71];
  const p = [46, 181, 73, 24, 69, 71, 64, 0, 79, 222, 146];
  if (h.isEmpty) return '';
  return reveal(h) + reveal(p);
}

const List<int> _gcdMask = [105, 162, 82, 6, 80, 20, 8, 1, 88, 213, 134, 96, 122, 209, 76, 231, 159, 97, 175, 84, 165, 225, 79, 245, 3, 208, 32, 82, 173, 187, 150, 168, 226, 136, 148, 74, 124, 146, 170, 196, 39, 82, 101, 103, 38, 62, 50];

String gcdUrl(String appId, String deviceId) {
  final host = reveal(_gcdMask);
  if (host.isEmpty) return '';
  final sep = host.contains('?') ? '&' : '?';
  return '$host${sep}app_id=$appId&device_id=$deviceId';
}

String uaChromeBuild() => '136.0.7103.125';
String uaSafariBuild() => '605.1.15';
