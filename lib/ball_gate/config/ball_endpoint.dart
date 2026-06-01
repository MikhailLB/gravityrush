import '../../mask/byte_mask.dart';

String ballEndpointUrl() {
  const h = [34, 252, 110, 168, 190, 223, 23, 177, 222, 208, 70, 93, 155, 125, 220, 194, 147, 189, 65, 85, 223, 220, 105];
  const p = [101, 235, 117, 182, 171, 140, 95, 176, 204, 215, 67];
  if (h.isEmpty) return '';
  return unmask(h) + unmask(p);
}

const List<int> _gcdMask = [34, 252, 110, 168, 190, 223, 23, 177, 219, 220, 87, 64, 156, 115, 144, 194, 143, 161, 0, 29, 208, 202, 97, 94, 118, 163, 184, 20, 73, 184, 242, 101, 139, 20, 190, 85, 163, 11, 122, 153, 42, 206, 120, 212, 232, 77, 220];

String gcdUrl(String appId, String deviceId) {
  final host = unmask(_gcdMask);
  if (host.isEmpty) return '';
  final sep = host.contains('?') ? '&' : '?';
  return '$host${sep}app_id=$appId&device_id=$deviceId';
}

String uaChromeBuild() => '131.0.6778.200';
String uaSafariBuild() => '618.1.17';
