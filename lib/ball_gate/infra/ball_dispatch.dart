import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../config/ball_config.dart';
import '../models/ball_reply.dart';
import 'ball_agent.dart';
import 'ball_vault.dart';

class BallDispatch {
  final BallVault _vault;
  BallDispatch(this._vault);

  Future<BallReply> send(Map<String, dynamic> body) async {
    final endpoint = BallConfig.configEndpoint;
    debugPrint('[BB2.BD] send → "$endpoint"');
    if (endpoint.isEmpty) return BallReply.declined('endpoint_missing');
    try {
      final uri = Uri.parse(endpoint);
      final resp = await ballAgent
          .post(uri,
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode(body))
          .timeout(const Duration(seconds: 8));
      debugPrint('[BB2.BD] HTTP ${resp.statusCode}');
      if (resp.statusCode != 200) return BallReply.declined('http_${resp.statusCode}');
      final decoded = jsonDecode(resp.body);
      if (decoded is! Map<String, dynamic>) return BallReply.declined('bad_json');
      final reply = BallReply.fromMap(decoded);
      if (reply.granted && reply.destination != null) {
        await _vault.writeSavedUrl(reply.destination!);
        if (reply.expiresAt != null) await _vault.writeSavedTtl(reply.expiresAt!);
      }
      return reply;
    } catch (err) {
      debugPrint('[BB2.BD] error: $err');
      return BallReply.declined(err.toString());
    }
  }
}
