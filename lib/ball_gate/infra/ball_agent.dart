import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import '../config/ball_endpoint.dart';

String _androidUa({required int sdk, required String brand,
    required String model, required String build}) =>
    'Mozilla/5.0 (Linux; Android $sdk; $brand $model Build/$build) '
    'AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/${uaChromeBuild()} Mobile Safari/537.36';

String _iosUa(String ver) {
  final d = ver.replaceAll('.', '_');
  return 'Mozilla/5.0 (iPhone; CPU iPhone OS $d like Mac OS X) '
      'AppleWebKit/${uaSafariBuild()} (KHTML, like Gecko) '
      'Version/$ver Mobile/15E148 Safari/${uaSafariBuild()}';
}

String _fallback() => Platform.isAndroid
    ? _androidUa(sdk: 35, brand: 'Samsung', model: 'SM-S928B', build: 'AP3A.240905.015')
    : _iosUa('18.3.2');

class BallAgent extends http.BaseClient {
  final http.Client _inner = http.Client();
  String _ua = '';

  Future<void> warmup() async {
    try {
      final p = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final i = await p.androidInfo;
        _ua = _androidUa(sdk: i.version.sdkInt, brand: i.brand,
            model: i.model, build: i.display.isNotEmpty ? i.display : i.id);
      } else if (Platform.isIOS) {
        final i = await p.iosInfo;
        _ua = _iosUa(i.systemVersion);
      } else { _ua = _fallback(); }
    } catch (_) { _ua = _fallback(); }
  }

  String get userAgent => _ua.isNotEmpty ? _ua : _fallback();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (!request.headers.containsKey('User-Agent') &&
        !request.headers.containsKey('user-agent')) {
      request.headers['User-Agent'] = userAgent;
    }
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

final ballAgent = BallAgent();
