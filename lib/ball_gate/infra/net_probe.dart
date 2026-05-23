import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

class NetProbe {
  final Connectivity _conn = Connectivity();

  Future<bool> isOnline() async {
    try {
      final results = await _conn.checkConnectivity();
      if (results.every((r) => r == ConnectivityResult.none)) return false;
    } catch (_) { return false; }
    try {
      final lookup = await InternetAddress.lookup('cloudflare.com')
          .timeout(const Duration(seconds: 4));
      return lookup.isNotEmpty && lookup.first.rawAddress.isNotEmpty;
    } on SocketException { return false; }
    catch (_) { return false; }
  }

  Stream<List<ConnectivityResult>> get onChange => _conn.onConnectivityChanged;
}
