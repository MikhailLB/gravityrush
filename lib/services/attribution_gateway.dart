import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';
import '../config/brand_config.dart';
import '../config/endpoint_registry.dart';
import 'browser_http.dart';

class AttributionGateway {
  AppsflyerSdk? _provider;
  Map<String, dynamic>? _conversion;
  Map<String, dynamic>? _deepLink;
  Map<String, dynamic>? _reopen;
  final Completer<Map<String, dynamic>> _conversionReady = Completer();
  final Completer<void> _deepLinkReady = Completer();
  bool _started = false;
  Timer? _deepLinkSettleTimer;

  Future<void> warmup() async {
    if (_started) return;
    _started = true;

    final opts = AppsFlyerOptions(
      afDevKey: BrandConfig.attributionDevKey,
      appId: BrandConfig.iosAppId,
      showDebug: false,
      timeToWaitForATTUserAuthorization: 10,
      appInviteOneLink:
          BrandConfig.appsFlyerOneLinkTemplateId.isNotEmpty
              ? BrandConfig.appsFlyerOneLinkTemplateId
              : null,
    );
    _provider = AppsflyerSdk(opts);

    _provider!.onInstallConversionData(_onConversion);
    _provider!.onAppOpenAttribution(_onReopen);
    _provider!.onDeepLinking(_onDeepLink);

    await _provider!.initSdk(
      registerConversionDataCallback: true,
      registerOnAppOpenAttributionCallback: true,
      registerOnDeepLinkingCallback: true,
    );
  }

  Map<String, dynamic> _unwrap(dynamic raw) {
    final map = Map<String, dynamic>.from(raw as Map);
    final inner = map['payload'];
    if (inner is Map) {
      return Map<String, dynamic>.from(inner);
    }
    return map;
  }

  void _onConversion(dynamic raw) async {
    final data = _unwrap(raw);

    if (kDebugMode) {
      debugPrint('[AG] conversion ${jsonEncode(data)}');
    }

    if (data['af_status'] == 'Organic') {
      await Future.delayed(
        Duration(seconds: BrandConfig.refreshDelaySeconds),
      );
      final fresh = await _fetchGcd();
      _conversion = fresh ?? data;
      if (_conversion != null) {
        _spreadUrlQueryParamsInto(_conversion!);
      }
    } else {
      _conversion = data;
      _spreadUrlQueryParamsInto(_conversion!);
    }

    if (!_conversionReady.isCompleted) {
      _conversionReady.complete(_conversion);
    }
    _scheduleAttributionSettled();
  }

  void _onReopen(dynamic raw) {
    final map = Map<String, dynamic>.from(_unwrap(raw));
    _spreadUrlQueryParamsInto(map);
    _reopen = map;
    if (kDebugMode) {
      debugPrint('[AG] reopen ${jsonEncode(_reopen)}');
    }
    _scheduleAttributionSettled();
  }

  void _onDeepLink(DeepLinkResult result) {
    if (kDebugMode) {
      debugPrint(
        '[AG] deepLink status=${result.status}, link=${result.deepLink}',
      );
    }
    if (result.deepLink != null) {
      final raw = Map<String, dynamic>.from(result.deepLink!.clickEvent);
      _spreadUrlQueryParamsInto(raw);
      _deepLink = raw;
    }
    _scheduleAttributionSettled();
  }

  /// SDK can deliver conversion, reopen, and UDL in any order and in multiple chunks.
  /// Wait briefly after the last update so af_sub* / deep_link_* are not missed.
  void _scheduleAttributionSettled() {
    _deepLinkSettleTimer?.cancel();
    _deepLinkSettleTimer = Timer(const Duration(milliseconds: 750), () {
      if (!_deepLinkReady.isCompleted) {
        _deepLinkReady.complete();
      }
    });
  }

  /// Pull af_sub*, deep_link_*, pid, … from AppsFlyer's `link` / `original_link` URL when
  /// they're not surfaced as flat keys in click_event (common on Android retarget flows).
  void _spreadUrlQueryParamsInto(Map<String, dynamic> map) {
    const linkKeys = <String>[
      'link',
      'original_link',
      'shortlink',
      'af_dp',
      'af_url',
    ];
    for (final key in linkKeys) {
      final v = map[key];
      if (v is! String || v.isEmpty) continue;
      final uri = Uri.tryParse(v);
      if (uri == null || uri.queryParameters.isEmpty) continue;
      uri.queryParameters.forEach((qk, qv) {
        if (qv.isEmpty) return;
        final existing = map[qk];
        final empty = existing == null ||
            (existing is String && existing.isEmpty);
        if (empty) map[qk] = qv;
      });
    }
  }

  Future<Map<String, dynamic>?> _fetchGcd() async {
    try {
      final uid = await identifier();
      if (uid == null) return null;

      final appId = Platform.isIOS
          ? BrandConfig.iosAppId
          : BrandConfig.packageName;
      final uri = Uri.parse(gcdEndpoint(appId, uid));
      final response = await browserHttp.get(uri, headers: {
        'authorization': 'Bearer ${BrandConfig.attributionDevKey}',
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) return decoded;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>> awaitConversion({
    Duration timeout = const Duration(seconds: 30),
  }) {
    return _conversionReady.future.timeout(
      timeout,
      onTimeout: () => <String, dynamic>{},
    );
  }

  Future<void> awaitDeepLink({
    Duration timeout = const Duration(seconds: 12),
  }) {
    return _deepLinkReady.future
        .timeout(timeout, onTimeout: () {});
  }

  Future<String?> identifier() async {
    if (_provider == null) return null;
    try {
      return await _provider!.getAppsFlyerUID();
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> assembleRequest({
    required String locale,
    String? pushToken,
  }) async {
    _deepLinkSettleTimer?.cancel();

    final out = <String, dynamic>{};

    if (_conversion != null) {
      out.addAll(Map<String, dynamic>.from(_conversion!));
    }
    if (_reopen != null) {
      out.addAll(Map<String, dynamic>.from(_reopen!));
    }
    if (_deepLink != null) {
      out.addAll(Map<String, dynamic>.from(_deepLink!));
    }
    _spreadUrlQueryParamsInto(out);

    final uid = await identifier();
    if (uid != null && uid.isNotEmpty) {
      out['af_id'] = uid;
    } else if ((out['af_id'] as String? ?? '').isEmpty) {
      out['af_id'] = '';
    }

    out['bundle_id'] = BrandConfig.packageName;
    out['store_id'] = BrandConfig.storeIdentifier;
    out['os'] = Platform.isAndroid ? 'Android' : 'iOS';
    out['locale'] = locale;

    if (pushToken != null && pushToken.isNotEmpty) {
      out['push_token'] = pushToken;
    }
    if (BrandConfig.cloudProjectId.isNotEmpty) {
      out['firebase_project_id'] = BrandConfig.cloudProjectId;
    }

    if (kDebugMode) {
      debugPrint('[AG] request body: ${jsonEncode(out)}');
    }
    return out;
  }
}
