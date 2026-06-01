import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

class NetProbe {
  final Connectivity _conn = Connectivity();

  static const _probeHosts = ['apple.com', 'icloud.com'];

  Future<bool> isOnline() async {
    try {
      final results = await _conn.checkConnectivity();
      if (results.every((r) => r == ConnectivityResult.none)) return false;
    } catch (_) { return false; }
    for (final host in _probeHosts) {
      try {
        final lookup = await InternetAddress.lookup(host)
            .timeout(const Duration(seconds: 4));
        if (lookup.isNotEmpty && lookup.first.rawAddress.isNotEmpty) return true;
      } on SocketException { continue; }
      catch (_) { continue; }
    }
    return false;
  }

  Stream<List<ConnectivityResult>> get onChange => _conn.onConnectivityChanged;
}
