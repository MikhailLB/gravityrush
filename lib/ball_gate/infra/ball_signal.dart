import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../config/ball_endpoint.dart';
import '../config/ball_config.dart';
import 'ball_agent.dart';

class BallSignal {
  AppsflyerSdk? _sdk;
  Map<String, dynamic>? _conversion;
  Map<String, dynamic>? _deepLink;
  Map<String, dynamic>? _reopen;

  final Completer<Map<String, dynamic>> _conversionDone = Completer();
  final Completer<void> _deepLinkDone = Completer();

  bool _started = false;
  Future<void>? _warmupFuture;

  bool get started => _started;
  Future<void> warmup() => _warmupFuture ??= _doWarmup();

  Future<void> _doWarmup() async {
    if (_started) return;
    final devKey = BallConfig.installKey;
    debugPrint('[BB2.BS] warmup devKeyLen=${devKey.length}');
    if (devKey.isEmpty) {
      _started = true;
      if (!_conversionDone.isCompleted) _conversionDone.complete({});
      if (!_deepLinkDone.isCompleted) _deepLinkDone.complete();
      return;
    }
    _started = true;
    try {
      if (Platform.isIOS) await _requestAtt();
      final opts = AppsFlyerOptions(
        afDevKey: devKey,
        appId: BallConfig.analyticsAppId,
        showDebug: kDebugMode,
        timeToWaitForATTUserAuthorization: 4,
      );
      _sdk = AppsflyerSdk(opts);
      _sdk!.onInstallConversionData(_onConversion);
      _sdk!.onAppOpenAttribution(_onReopen);
      _sdk!.onDeepLinking(_onDeepLink);
      await _sdk!.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: true,
        registerOnDeepLinkingCallback: true,
      );
      debugPrint('[BB2.BS] initSdk OK');
    } catch (err) {
      debugPrint('[BB2.BS] warmup error: $err');
      if (!_conversionDone.isCompleted) _conversionDone.complete({});
      if (!_deepLinkDone.isCompleted) _deepLinkDone.complete();
    }
  }

  Future<void> _requestAtt() async {
    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status != TrackingStatus.notDetermined) return;
      await WidgetsBinding.instance.endOfFrame;
      await Future.delayed(const Duration(milliseconds: 300));
      await AppTrackingTransparency.requestTrackingAuthorization();
    } catch (err) { debugPrint('[BB2.BS] ATT skipped: $err'); }
  }

  Map<String, dynamic> _flatten(dynamic raw) {
    final m = Map<String, dynamic>.from(raw as Map);
    final inner = m['payload'];
    if (inner is Map) return Map<String, dynamic>.from(inner);
    return m;
  }

  void _onConversion(dynamic raw) async {
    final data = _flatten(raw);
    debugPrint('[BB2.BS] conversion ${jsonEncode(data)}');
    if (data['af_status'] == 'Organic') {
      await Future.delayed(Duration(seconds: BallConfig.organicRetrySeconds));
      final retry = await _refreshGcd();
      _conversion = retry ?? data;
    } else { _conversion = data; }
    if (!_conversionDone.isCompleted) _conversionDone.complete(_conversion);
  }

  void _onReopen(dynamic raw) => _reopen = _flatten(raw);

  void _onDeepLink(DeepLinkResult r) {
    if (r.deepLink != null) _deepLink = r.deepLink!.clickEvent;
    if (!_deepLinkDone.isCompleted) _deepLinkDone.complete();
  }

  Future<Map<String, dynamic>?> _refreshGcd() async {
    try {
      final uid = await deviceId();
      if (uid == null) return null;
      final appId = Platform.isIOS ? BallConfig.analyticsAppId : BallConfig.bundleId;
      final url = gcdUrl(appId, uid);
      if (url.isEmpty) return null;
      final resp = await ballAgent.get(
        Uri.parse(url),
        headers: {'authorization': 'Bearer ${BallConfig.installKey}'},
      ).timeout(const Duration(seconds: 12));
      if (resp.statusCode == 200) {
        final d = jsonDecode(resp.body);
        if (d is Map<String, dynamic>) return d;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>> awaitConversion({
    Duration timeout = const Duration(seconds: 7),
  }) => _conversionDone.future.timeout(timeout, onTimeout: () => {});

  Future<void> awaitDeepLink({
    Duration timeout = const Duration(seconds: 5),
  }) => _deepLinkDone.future.timeout(timeout, onTimeout: () {});

  Future<String?> deviceId() async {
    if (_sdk == null) return null;
    try { return await _sdk!.getAppsFlyerUID(); } catch (_) { return null; }
  }

  Future<Map<String, dynamic>> buildPayload({
    required String locale,
    String? pushToken,
  }) async {
    final body = <String, dynamic>{};
    if (_conversion != null) body.addAll(_conversion!);
    if (_deepLink != null) _deepLink!.forEach((k, v) => body.putIfAbsent(k, () => v));
    if (_reopen != null) _reopen!.forEach((k, v) => body.putIfAbsent(k, () => v));

    final uid = await deviceId();
    body['af_id'] = uid ?? '';

    if (Platform.isIOS) {
      try {
        final status = await AppTrackingTransparency.trackingAuthorizationStatus;
        if (status == TrackingStatus.authorized) {
          final idfa = await AppTrackingTransparency.getAdvertisingIdentifier();
          if (idfa.isNotEmpty && !idfa.startsWith('00000000-')) {
            body.putIfAbsent('sub_id_10', () => idfa);
          }
        }
      } catch (_) {}
    }

    body['bundle_id'] = BallConfig.bundleId;
    body['store_id']  = BallConfig.platformStoreId;
    body['os']        = Platform.isAndroid ? 'Android' : 'iOS';
    body['locale']    = locale;
    if (pushToken != null && pushToken.isNotEmpty) body['push_token'] = pushToken;
    if (BallConfig.firebaseNumber.isNotEmpty) {
      body['firebase_project_id'] = BallConfig.firebaseNumber;
    }

    debugPrint('[BB2.BS] payload keys=${body.keys.toList()}');
    return body;
  }
}
