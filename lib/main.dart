import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'bootstrap.dart';
import 'ball_gate/config/ball_endpoint.dart';
import 'ball_gate/config/signal_keys.dart';
import 'ball_gate/infra/ball_agent.dart';
import 'ball_gate/infra/ball_dispatch.dart';
import 'ball_gate/infra/ball_signal.dart';
import 'ball_gate/infra/ball_vault.dart';
import 'ball_gate/infra/flare_relay.dart';
import 'ball_gate/infra/net_probe.dart';

Future<void> _bootFirebase() async {
  try {
    await Firebase.initializeApp();
  } catch (err) {
    debugPrint('[BB2.BOOT] Firebase init skipped: $err');
    return;
  }
  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider:
          kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode
          ? AppleProvider.debug
          : AppleProvider.appAttestWithDeviceCheckFallback,
    );
  } catch (err) { debugPrint('[BB2.BOOT] AppCheck skipped: $err'); }
}

Future<void> main() async {
  final sw = Stopwatch()..start();
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp, DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  final firebaseFuture = _bootFirebase();
  final agentFuture    = ballAgent.warmup();
  final vault          = BallVault();
  final vaultFuture    = vault.init().catchError((err) {
    debugPrint('[BB2.BOOT] vault init failed: $err');
  });

  await firebaseFuture;
  debugPrint('[BB2.BOOT] firebase ready ${sw.elapsedMilliseconds}ms');
  await Future.wait([agentFuture, vaultFuture]);
  debugPrint('[BB2.BOOT] agent+vault ready ${sw.elapsedMilliseconds}ms');

  final probe    = NetProbe();
  final signal   = BallSignal();
  final dispatch = BallDispatch(vault);
  final flare    = FlareRelay(vault);

  unawaited(flare.bootstrap().catchError((err) {
    debugPrint('[BB2.BOOT] flare pre-fire: $err');
  }));

  final gateEnabled =
      ballEndpointUrl().isNotEmpty || appsflyerDevKey().isNotEmpty;

  debugPrint('[BB2.BOOT] gateEnabled=$gateEnabled  ${sw.elapsedMilliseconds}ms');

  runApp(BounceGateApp(
    vault: vault,
    probe: probe,
    signal: signal,
    dispatch: dispatch,
    flare: flare,
    gateEnabled: gateEnabled,
  ));
}
