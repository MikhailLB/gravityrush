import 'package:flutter/material.dart';

import 'ball_gate/infra/ball_dispatch.dart';
import 'ball_gate/infra/ball_signal.dart';
import 'ball_gate/infra/ball_vault.dart';
import 'ball_gate/infra/flare_relay.dart';
import 'ball_gate/infra/net_probe.dart';
import 'ball_gate/pages/bounce_gate.dart';
import 'root_widget.dart';

/// Root widget — wires the gray gate into Bounce Ball 2.
///
/// When [gateEnabled] is false, boots straight into the white game.
class BounceGateApp extends StatelessWidget {
  final BallVault vault;
  final NetProbe probe;
  final BallSignal signal;
  final BallDispatch dispatch;
  final FlareRelay flare;
  final bool gateEnabled;

  const BounceGateApp({
    super.key,
    required this.vault,
    required this.probe,
    required this.signal,
    required this.dispatch,
    required this.flare,
    required this.gateEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final Widget home = gateEnabled
        ? BounceGate(
            vault: vault, probe: probe,
            signal: signal, dispatch: dispatch, flare: flare,
          )
        : const BallDropApp();

    return MaterialApp(
      title: 'Bounce Ball 2',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black),
      home: home,
    );
  }
}
