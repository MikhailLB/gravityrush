import '../../ball_vault/ball_cipher.dart';

// TODO: fill with dart run tool/encode_creds.dart output
String ballEndpointUrl() {
  const h = <int>[];
  const p = <int>[];
  if (h.isEmpty) return '';
  return reveal(h) + reveal(p);
}

const List<int> _gcdMask = <int>[];

String gcdUrl(String appId, String deviceId) {
  final host = reveal(_gcdMask);
  if (host.isEmpty) return '';
  final sep = host.contains('?') ? '&' : '?';
  return '$host${sep}app_id=$appId&device_id=$deviceId';
}

String uaChromeBuild() => '136.0.7103.125';
String uaSafariBuild() => '605.1.15';
