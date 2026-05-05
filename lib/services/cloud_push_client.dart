import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'browser_http.dart';
import 'local_store.dart';

const String pushChannelId = 'gr_priority_alerts';
const String pushChannelLabel = 'Gravity Rush Alerts';
const String pushIconRes = '@drawable/ic_notification';

@pragma('vm:entry-point')
Future<void> _backgroundHandler(RemoteMessage _) async {}

/// Top-level entry-point invoked by `flutter_local_notifications` when the
/// user taps a locally-shown notification while the Dart isolate is not
/// alive (cold start / background). On iOS we no longer surface local
/// notifications at all, so this is effectively only used by Android.
@pragma('vm:entry-point')
void _trayBackgroundTapHandler(NotificationResponse resp) {
  final payload = resp.payload;
  if (payload == null || payload.isEmpty) return;
  try {
    final decoded = jsonDecode(payload);
    if (decoded is Map && decoded['url'] is String) {
      final url = decoded['url'] as String;
      if (url.isEmpty) return;
      // A background isolate cannot share the foreground LocalStore instance,
      // so we open a fresh one just for the stash write. The foreground app
      // reads it back via writePushTarget / readPushTarget on next entry.
      LocalStore().writePushTarget(url);
    }
  } catch (_) {}
}

class CloudPushClient {
  final FlutterLocalNotificationsPlugin _tray =
      FlutterLocalNotificationsPlugin();
  final LocalStore _store;
  FirebaseMessaging? _msg;
  String? _token;
  bool _ready = false;
  Future<bool>? _permissionFlow;

  void Function(String url)? onRemoteTarget;
  void Function(String token)? onTokenRotate;

  CloudPushClient(this._store);

  String? get token => _token;

  Future<void> bootstrap() async {
    if (_ready) return;
    try {
      await Firebase.initializeApp();
      _msg = FirebaseMessaging.instance;

      FirebaseMessaging.onBackgroundMessage(_backgroundHandler);
      await _configureLocalTray();

      // iOS foreground presentation: enable banner / badge / sound. Combined
      // with the Notification Service Extension this lets the system render
      // rich (image-attached) push notifications natively in foreground —
      // we no longer need to schedule a duplicate flutter_local_notifications
      // copy on iOS. No-op on Android.
      try {
        await _msg!.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      } catch (_) {}

      _token = await _msg!.getToken();

      _msg!.onTokenRefresh.listen((fresh) {
        _token = fresh;
        onTokenRotate?.call(fresh);
      });

      FirebaseMessaging.onMessage.listen(_onForeground);
      FirebaseMessaging.onMessageOpenedApp.listen(_onBackgroundTap);

      final cold = await _msg!.getInitialMessage();
      if (cold != null) await _onColdStart(cold);

      _ready = true;
    } catch (_) {
      // Firebase not configured - silently skip push
    }
  }

  Future<void> _configureLocalTray() async {
    const androidInit = AndroidInitializationSettings(pushIconRes);
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _tray.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (resp) {
        final payload = resp.payload;
        if (payload == null) return;
        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map && decoded['url'] is String) {
            final url = decoded['url'] as String;
            if (url.isNotEmpty) onRemoteTarget?.call(url);
          }
        } catch (_) {}
      },
      onDidReceiveBackgroundNotificationResponse: _trayBackgroundTapHandler,
    );

    if (Platform.isAndroid) {
      final impl = _tray.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await impl?.createNotificationChannel(
        const AndroidNotificationChannel(
          pushChannelId,
          pushChannelLabel,
          description: 'Priority push channel',
          importance: Importance.high,
        ),
      );
    }
  }

  // One year — effectively "never show our offer screen again" after the OS
  // has permanently denied notifications.
  static const int _systemDeniedCooldown = 365 * 24 * 3600;

  Future<void> _markSystemDenied() async {
    await _store.writePushConsent(false);
    await _store.writePushCooldown(
      (DateTime.now().millisecondsSinceEpoch ~/ 1000) + _systemDeniedCooldown,
    );
  }

  /// Returns true when it still makes sense to show the in-app offer screen.
  /// Once the OS has permanently denied, the offer is pointless — tapping
  /// ALLOW would silently no-op.
  Future<bool> shouldOfferConsent() async {
    if (_msg == null) return false;
    try {
      if (Platform.isAndroid) {
        final impl = _tray.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        if (impl == null) return true;
        final enabled = await impl.areNotificationsEnabled();
        return enabled != true;
      }
      final settings = await _msg!.getNotificationSettings();
      final status = settings.authorizationStatus;
      if (status == AuthorizationStatus.notDetermined) return true;
      if (status == AuthorizationStatus.denied) {
        await _markSystemDenied();
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> askConsent() async {
    if (_msg == null) return false;
    final pending = _permissionFlow;
    if (pending != null) return pending;

    final future = _askConsentImpl();
    _permissionFlow = future;
    try {
      return await future;
    } finally {
      _permissionFlow = null;
    }
  }

  Future<bool> _askConsentImpl() async {
    try {
      if (Platform.isAndroid) {
        return await _askConsentAndroid();
      }
      return await _askConsentIOS();
    } catch (_) {
      return false;
    }
  }

  Future<bool> _askConsentAndroid() async {
    final impl = _tray.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (impl == null) return _askConsentIOS();

    final already = await impl.areNotificationsEnabled();
    if (already == true) {
      await _store.writePushConsent(true);
      return true;
    }
    final granted = await impl.requestNotificationsPermission();
    if (granted == true) {
      await _store.writePushConsent(true);
      return true;
    }
    // The user tapped ALLOW but the OS denied — or it was silently denied
    // after repeated requests. The system prompt is no longer reachable,
    // so suppress our offer screen for the foreseeable future.
    await _markSystemDenied();
    return false;
  }

  Future<bool> _askConsentIOS() async {
    final current = await _msg!.getNotificationSettings();
    final status = current.authorizationStatus;
    if (status == AuthorizationStatus.denied) {
      await _markSystemDenied();
      return false;
    }
    if (status != AuthorizationStatus.notDetermined) {
      final ok = status == AuthorizationStatus.authorized ||
          status == AuthorizationStatus.provisional;
      await _store.writePushConsent(ok);
      return ok;
    }
    final result = await _msg!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    final ok = result.authorizationStatus == AuthorizationStatus.authorized ||
        result.authorizationStatus == AuthorizationStatus.provisional;
    if (!ok && result.authorizationStatus == AuthorizationStatus.denied) {
      await _markSystemDenied();
      return false;
    }
    await _store.writePushConsent(ok);
    return ok;
  }

  void _onForeground(RemoteMessage message) async {
    final notif = message.notification;
    if (notif == null) return;

    // On iOS the system already presents the FCM notification in foreground
    // (alert/badge/sound enabled in bootstrap) and the Notification Service
    // Extension attaches the image before display. Scheduling our own
    // flutter_local_notifications copy here used to produce a duplicate
    // banner and broke tap routing because Firebase's swizzled
    // UNUserNotificationCenter delegate intercepts taps on locally-scheduled
    // notifications differently from FCM-displayed ones. Taps on the system
    // notification flow through onMessageOpenedApp which onRemoteTarget
    // subscribers already handle.
    if (Platform.isIOS) return;

    final imageUrl = notif.android?.imageUrl;

    AndroidNotificationDetails? androidDetails;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      final bytes = await _downloadPicture(imageUrl);
      if (bytes != null) {
        androidDetails = AndroidNotificationDetails(
          pushChannelId,
          pushChannelLabel,
          importance: Importance.high,
          priority: Priority.high,
          icon: pushIconRes,
          styleInformation: BigPictureStyleInformation(
            ByteArrayAndroidBitmap(bytes),
            largeIcon:
                const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          ),
        );
      }
    }

    androidDetails ??= const AndroidNotificationDetails(
      pushChannelId,
      pushChannelLabel,
      importance: Importance.high,
      priority: Priority.high,
      icon: pushIconRes,
    );

    final payload =
        message.data.isNotEmpty ? jsonEncode(message.data) : null;

    await _tray.show(
      notif.hashCode,
      notif.title,
      notif.body,
      NotificationDetails(android: androidDetails),
      payload: payload,
    );
  }

  Future<void> _onColdStart(RemoteMessage message) async {
    final url = message.data['url'] as String?;
    if (url != null && url.isNotEmpty) {
      // Await the stash write so the URL is persisted before bootstrap()
      // returns and the entry flow calls takePushTarget(). Without await
      // the async write could complete after the read, losing the URL.
      await _store.writePushTarget(url);
    }
  }

  void _onBackgroundTap(RemoteMessage message) {
    final url = message.data['url'] as String?;
    if (url != null && url.isNotEmpty) {
      onRemoteTarget?.call(url);
    }
  }

  Future<Uint8List?> _downloadPicture(String url) async {
    try {
      final response = await browserHttp
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) return response.bodyBytes;
    } catch (_) {}
    return null;
  }
}
