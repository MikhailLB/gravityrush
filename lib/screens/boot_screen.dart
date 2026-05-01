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
  bool _leaving = false;
  Orientation? _lastOrientation;

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

    final mode = widget.store.readRuntimeMode();
    switch (mode) {
      case RuntimeMode.browser:
        await _runBrowserMode();
        break;
      case RuntimeMode.arcade:
        await Future.delayed(const Duration(milliseconds: 600));
        _goArcade();
        break;
      case RuntimeMode.undetermined:
        await _runFirstLaunch();
        break;
    }
  }

  Future<void> _runFirstLaunch() async {
    final online = await widget.net.isOnline();
    if (!online) {
      if (!mounted) return;
      _goOffline(firstLaunch: true);
      return;
    }

    await widget.attribution.warmup();
    await Future.wait([
      widget.attribution.awaitConversion(),
      widget.attribution.awaitDeepLink(),
    ]);

    final locale = Platform.localeName.replaceAll('-', '_');
    final body = await widget.attribution.assembleRequest(
      locale: locale,
      pushToken: widget.push.token,
    );
    final reply = await widget.config.dispatch(body);

    if (reply.accepted && reply.target != null) {
      await widget.store.writeRuntimeMode(RuntimeMode.browser);
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      _goWebContent(reply.target!);
    } else {
      await widget.store.writeRuntimeMode(RuntimeMode.arcade);
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      _goArcade();
    }
  }

  Future<void> _runBrowserMode() async {
    final online = await widget.net.isOnline();
    if (!online) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      _goOffline(firstLaunch: false);
      return;
    }

    final pushTarget = await widget.store.takePushTarget();
    if (pushTarget != null) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      _goWebContent(pushTarget);
      return;
    }

    final cached = await widget.store.readCachedTarget();

    await widget.attribution.warmup();
    await Future.wait([
      widget.attribution.awaitConversion(
        timeout: const Duration(seconds: 10),
      ),
      widget.attribution.awaitDeepLink(),
    ]);

    final locale = Platform.localeName.replaceAll('-', '_');
    final body = await widget.attribution.assembleRequest(
      locale: locale,
      pushToken: widget.push.token,
    );
    final reply = await widget.config.dispatch(body);
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    if (reply.accepted && reply.target != null) {
      _goWebContent(reply.target!);
      return;
    }
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

  Future<void> _goWebContent(String url) async {
    if (_leaving) return;
    _leaving = true;

    await host.loadLibrary();
    await primeBrowser();
    if (!mounted) return;

    if (widget.store.needsPushPrompt()) {
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
        ],
      ),
    );
  }

}
