import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'ball_agent.dart';
import 'ball_vault.dart';

const _channelId    = 'vt9k_push';
const _channelLabel = 'Bounce Ball 2';
const _iconRes      = '@drawable/ic_bb2_alert';

@pragma('vm:entry-point')
Future<void> _bgMsgHandler(RemoteMessage _) async {}

@pragma('vm:entry-point')
Future<void> flareTrayTapHandler(NotificationResponse resp) async {
  final payload = resp.payload;
  if (payload == null || payload.isEmpty) return;
  try {
    final d = jsonDecode(payload);
    if (d is Map && d['url'] is String && (d['url'] as String).isNotEmpty) {
      await BallVault().stashOneShotUrl(d['url'] as String);
    }
  } catch (_) {}
}

class FlareRelay {
  final FlutterLocalNotificationsPlugin _tray =
      FlutterLocalNotificationsPlugin();
  final BallVault _vault;
  final Completer<void> _coldGate = Completer<void>();

  FirebaseMessaging? _fcm;
  String? _token;
  bool _ready = false;
  Future<void>? _bootFuture;
  Future<bool>? _consentInflight;

  void Function(String url)?   onPushUrl;
  void Function(String token)? onTokenRefresh;

  FlareRelay(this._vault);

  String? get token => _token;
  bool get ready    => _ready;
  Future<void> get coldStartReady => _coldGate.future;

  Future<void> bootstrap() => _bootFuture ??= _doBootstrap();

  Future<void> _doBootstrap() async {
    try {
      _fcm = FirebaseMessaging.instance;
      await _captureColdStart();
      FirebaseMessaging.onBackgroundMessage(_bgMsgHandler);
      await _setupTray();
      try {
        await _fcm!.setForegroundNotificationPresentationOptions(
          alert: true, badge: true, sound: true,
        );
      } catch (_) {}
      _fcm!.onTokenRefresh.listen((t) {
        _token = t; onTokenRefresh?.call(t);
      });
      FirebaseMessaging.onMessage.listen(_onForeground);
      FirebaseMessaging.onMessageOpenedApp.listen(_onBgTap);
      if (Platform.isIOS) {
        try {
          final s = await _fcm!.getNotificationSettings();
          if (s.authorizationStatus == AuthorizationStatus.notDetermined) {
            await _fcm!.requestPermission(
              alert: false, badge: false, sound: false, provisional: true);
          }
        } catch (_) {}
        await _pollApns();
      }
      _token = await _fcm!.getToken();
      _ready = true;
    } catch (_) {
    } finally {
      if (!_coldGate.isCompleted) _coldGate.complete();
    }
  }

  Future<void> _captureColdStart() async {
    try {
      final msg = await _fcm!.getInitialMessage()
          .timeout(const Duration(seconds: 4), onTimeout: () => null);
      if (msg != null) {
        final url = _extractUrl(msg);
        if (url != null) {
          await _vault.stashOneShotUrl(url);
        }
      }
    } catch (_) {}
    finally { if (!_coldGate.isCompleted) _coldGate.complete(); }
  }

  String? _extractUrl(RemoteMessage msg) {
    for (final k in const ['url', 'link', 'target', 'deeplink', 'deep_link']) {
      final v = msg.data[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    final nested = msg.data['payload'];
    if (nested is Map) {
      for (final k in const ['url', 'link', 'target', 'deeplink', 'deep_link']) {
        final v = nested[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
    }
    return null;
  }

  Future<void> _pollApns({int retries = 5}) async {
    for (var i = 0; i < retries; i++) {
      try {
        final t = await _fcm!.getAPNSToken();
        if (t != null && t.isNotEmpty) return;
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<void> _setupTray() async {
    await _tray.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings(_iconRes),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (resp) {
        final payload = resp.payload;
        if (payload == null) return;
        try {
          final d = jsonDecode(payload);
          if (d is Map && d['url'] is String) _dispatchUrl(d['url'] as String, from: 'tray');
        } catch (_) {}
      },
      onDidReceiveBackgroundNotificationResponse: flareTrayTapHandler,
    );
    if (Platform.isAndroid) {
      final impl = _tray.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await impl?.createNotificationChannel(const AndroidNotificationChannel(
        _channelId, _channelLabel,
        description: 'Bounce Ball 2 real-time alerts',
        importance: Importance.high,
      ));
    }
  }

  Future<bool> shouldOfferConsent() async {
    final m = _fcm;
    if (m == null) return false;
    try {
      if (Platform.isAndroid) {
        final impl = _tray.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        if (impl == null) return true;
        final enabled = await impl.areNotificationsEnabled();
        return enabled != true;
      }
      final s = await m.getNotificationSettings();
      final st = s.authorizationStatus;
      if (st == AuthorizationStatus.denied) {
        await _vault.writePushCooldown(
            DateTime.now().millisecondsSinceEpoch ~/ 1000 + 365 * 24 * 3600);
        await _vault.writePushConsent(false);
      }
      return st == AuthorizationStatus.notDetermined ||
          st == AuthorizationStatus.provisional;
    } catch (_) { return false; }
  }

  Future<bool> askConsent() async {
    if (_fcm == null) return false;
    final pending = _consentInflight;
    if (pending != null) return pending;
    final flow = _runConsent();
    _consentInflight = flow;
    try { return await flow; } finally { _consentInflight = null; }
  }

  Future<bool> _runConsent() async {
    try {
      if (Platform.isAndroid) {
        final impl = _tray.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        if (impl != null) {
          final already = await impl.areNotificationsEnabled();
          if (already == true) { await _vault.writePushConsent(true); return true; }
          final ok = (await impl.requestNotificationsPermission()) ?? false;
          await _vault.writePushConsent(ok);
          return ok;
        }
      }
      final settings = await _fcm!.getNotificationSettings();
      final st = settings.authorizationStatus;
      if (st == AuthorizationStatus.denied) {
        await _vault.writePushCooldown(
            DateTime.now().millisecondsSinceEpoch ~/ 1000 + 365 * 24 * 3600);
        await _vault.writePushConsent(false);
        return false;
      }
      if (st == AuthorizationStatus.authorized) {
        await _vault.writePushConsent(true);
        return true;
      }
      final result = await _fcm!.requestPermission(
          alert: true, badge: true, sound: true, provisional: false);
      final ok = result.authorizationStatus == AuthorizationStatus.authorized ||
          result.authorizationStatus == AuthorizationStatus.provisional;
      if (!ok && result.authorizationStatus == AuthorizationStatus.denied) {
        await _vault.writePushCooldown(
            DateTime.now().millisecondsSinceEpoch ~/ 1000 + 365 * 24 * 3600);
      }
      await _vault.writePushConsent(ok);
      return ok;
    } catch (_) {
      return false;
    }
  }

  Future<String?> refreshTokenAfterConsent() async {
    final m = _fcm;
    if (m == null) return null;
    try {
      if (Platform.isIOS) await _pollApns(retries: 14);
      _token = await m.getToken().timeout(const Duration(seconds: 10));
      final t = _token;
      if (t != null && t.isNotEmpty) onTokenRefresh?.call(t);
      return t;
    } catch (_) { return null; }
  }

  void _onForeground(RemoteMessage msg) async {
    if (Platform.isIOS) return;
    final notif = msg.notification;
    if (notif == null) {
      final url = _extractUrl(msg);
      if (url != null) _dispatchUrl(url, from: 'fg-data');
      return;
    }
    final imageUrl = msg.notification?.android?.imageUrl;
    AndroidNotificationDetails? androidDetails;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      final bytes = await _fetchImage(imageUrl);
      if (bytes != null) {
        androidDetails = AndroidNotificationDetails(
          _channelId, _channelLabel,
          importance: Importance.high, priority: Priority.high, icon: _iconRes,
          styleInformation: BigPictureStyleInformation(
            ByteArrayAndroidBitmap(bytes),
            largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          ),
        );
      }
    }
    androidDetails ??= const AndroidNotificationDetails(
      _channelId, _channelLabel,
      importance: Importance.high, priority: Priority.high, icon: _iconRes,
    );
    await _tray.show(
      notif.hashCode, notif.title, notif.body,
      NotificationDetails(android: androidDetails,
          iOS: const DarwinNotificationDetails(
            presentAlert: true, presentBadge: true, presentSound: true,
            presentBanner: true, presentList: true)),
      payload: msg.data.isNotEmpty ? jsonEncode(msg.data) : null,
    );
  }

  void _onBgTap(RemoteMessage msg) {
    final url = _extractUrl(msg);
    if (url != null) _dispatchUrl(url, from: 'bg-tap');
  }

  void _dispatchUrl(String url, {required String from}) {
    final cb = onPushUrl;
    if (cb != null) {
      cb(url);
    } else {
      _vault.stashOneShotUrl(url);
    }
  }

  Future<Uint8List?> _fetchImage(String url) async {
    try {
      final r = await ballAgent.get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) return r.bodyBytes;
    } catch (_) {}
    return null;
  }
}
