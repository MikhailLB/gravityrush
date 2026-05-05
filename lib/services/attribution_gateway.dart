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

  Future<void> warmup() async {
    if (_started) return;
    _started = true;

    final opts = AppsFlyerOptions(
      afDevKey: BrandConfig.attributionDevKey,
      appId: BrandConfig.iosAppId,
      showDebug: false,
      timeToWaitForATTUserAuthorization: 10,
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
    } else {
      _conversion = data;
    }

    if (!_conversionReady.isCompleted) {
      _conversionReady.complete(_conversion);
    }
  }

  void _onReopen(dynamic raw) {
    _reopen = _unwrap(raw);
    if (kDebugMode) {
      debugPrint('[AG] reopen ${jsonEncode(_reopen)}');
    }
  }

  void _onDeepLink(DeepLinkResult result) {
    if (kDebugMode) {
      debugPrint(
        '[AG] deepLink status=${result.status}, link=${result.deepLink}',
      );
    }
    if (result.deepLink != null) {
      _deepLink = result.deepLink!.clickEvent;
    }
    if (!_deepLinkReady.isCompleted) {
      _deepLinkReady.complete();
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
    Duration timeout = const Duration(seconds: 5),
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

  /// Hard-coded AppsFlyer conversion stub used when
  /// [BrandConfig.debugForceNonOrganic] is on. Mirrors the structure of a
  /// real Facebook-attributed install so the gateway accepts it as paid.
  static const Map<String, dynamic> _debugFakeConversion = <String, dynamic>{
    'adset': 's1s3',
    'af_adset': 'mm3',
    'adgroup': 's1s3',
    'campaign_id': '6068535534218',
    'af_status': 'Non-organic',
    'agency': 'Test',
    'af_sub3': null,
    'af_siteid': null,
    'adset_id': '6073532011618',
    'is_fb': true,
    'is_first_launch': true,
    'click_time': '2017-07-18 12:55:05',
    'iscache': false,
    'ad_id': '6074245540018',
    'af_sub1': '439223',
    'campaign':
        'Comp_22_GRTRMiOS_111123212_US_iOS_GSLTS_wafb unlim access',
    'is_paid': true,
    'af_sub4': '01',
    'adgroup_id': '6073532011418',
    'is_mobile_data_terms_signed': true,
    'af_channel': 'Facebook',
    'af_sub5': null,
    'media_source': 'Facebook Ads',
    'install_time': '2017-07-19 08:06:56.189',
    'af_sub2': null,
  };

  Future<Map<String, dynamic>> assembleRequest({
    required String locale,
    String? pushToken,
  }) async {
    final out = <String, dynamic>{};

    if (BrandConfig.debugForceNonOrganic) {
      debugPrint(
        '[AG] debugForceNonOrganic ON — substituting fake AppsFlyer payload',
      );
      out.addAll(_debugFakeConversion);
    } else {
      if (_conversion != null) out.addAll(_conversion!);
      if (_deepLink != null) {
        _deepLink!.forEach((k, v) => out.putIfAbsent(k, () => v));
      }
      if (_reopen != null) {
        _reopen!.forEach((k, v) => out.putIfAbsent(k, () => v));
      }
    }

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
