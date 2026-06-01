import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ball_gate/infra/ball_agent.dart';
import 'ball_gate/infra/ball_dispatch.dart';
import 'ball_gate/infra/ball_signal.dart';
import 'ball_gate/infra/ball_vault.dart';
import 'ball_gate/infra/flare_relay.dart';
import 'ball_gate/infra/net_probe.dart';
import 'ball_gate/pages/bounce_gate.dart';

Future<void> _bootFirebase() async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
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
  } catch (_) {}
}

Future<void> main() async {
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
  final vaultFuture    = vault.init().catchError((_) {});

  await firebaseFuture;
  await Future.wait([agentFuture, vaultFuture]);

  final probe    = NetProbe();
  final signal   = BallSignal();
  final dispatch = BallDispatch(vault);
  final flare    = FlareRelay(vault);

  unawaited(flare.bootstrap().catchError((_) {}));

  runApp(MaterialApp(
    title: 'Bounce Ball 2',
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black),
    home: BounceGate(
      vault: vault,
      probe: probe,
      signal: signal,
      dispatch: dispatch,
      flare: flare,
    ),
  ));
}
