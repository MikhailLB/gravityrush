import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../config/ball_config.dart';
import '../infra/ball_vault.dart';
import '../infra/flare_relay.dart';
import '../infra/net_probe.dart';
import 'ball_browser.dart';

/// Push-permission promo — full-screen looping video with invisible tap zones
/// aligned to the Accept / Skip artwork baked into the clip.
class NotifGate extends StatefulWidget {
  final BallVault vault;
  final FlareRelay flare;
  final NetProbe probe;
  final String destination;
  final Future<void> Function(String token)? onTokenReady;

  const NotifGate({
    super.key,
    required this.vault,
    required this.flare,
    required this.probe,
    required this.destination,
    this.onTokenReady,
  });

  @override
  State<NotifGate> createState() => _NotifGateState();
}

class _NotifGateState extends State<NotifGate> {
  VideoPlayerController? _vid;
  Orientation? _activeOrientation;
  bool _vidReady = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final o = MediaQuery.of(context).orientation;
    if (o != _activeOrientation) {
      _activeOrientation = o;
      _loadVideo(o);
    }
  }

  @override
  void dispose() {
    _vid?.dispose();
    super.dispose();
  }

  Future<void> _loadVideo(Orientation o) async {
    final path = o == Orientation.landscape
        ? 'assets/vt9k_note/bell_wide.mp4'
        : 'assets/vt9k_note/bell_tall.mp4';
    final old = _vid;
    final ctrl = VideoPlayerController.asset(path);
    try {
      await ctrl.initialize();
      ctrl.setLooping(true);
      ctrl.setVolume(0);
      ctrl.play();
      if (!mounted) {
        ctrl.dispose();
        return;
      }
      setState(() {
        _vid = ctrl;
        _vidReady = true;
      });
      await Future.delayed(const Duration(milliseconds: 400));
      old?.dispose();
    } catch (_) {
      ctrl.dispose();
    }
  }

  Future<void> _accept() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final granted = await widget.flare.askConsent();
      if (granted) {
        final token = await widget.flare.refreshTokenAfterConsent();
        if (token != null && token.isNotEmpty) {
          await widget.onTokenReady?.call(token);
        }
      } else {
        await _setCooldown();
      }
      _openBrowser();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _skip() async {
    if (_busy) return;
    await _setCooldown();
    _openBrowser();
  }

  Future<void> _setCooldown() async {
    final until = DateTime.now().millisecondsSinceEpoch ~/ 1000 +
        BallConfig.pushCooldownSeconds;
    await widget.vault.writePushCooldown(until);
  }

  void _openBrowser() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => BallBrowser(
        destination: widget.destination,
        vault: widget.vault,
        flare: widget.flare,
        probe: widget.probe,
        layoutSettle: true,
      ),
    ));
  }

  /// Tap targets tuned for 1080×2400 (portrait) and 2400×1080 (landscape) clips.
  _TapLayout _layout(Size size) {
    final landscape = size.width > size.height;
    if (landscape) {
      return const _TapLayout(
        acceptTop: 0.58,
        acceptHeight: 0.11,
        acceptInset: 0.35,
        skipTop: 0.72,
        skipHeight: 0.06,
        skipInset: 0.38,
      );
    }
    return const _TapLayout(
      acceptTop: 0.61,
      acceptHeight: 0.07,
      acceptInset: 0.11,
      skipTop: 0.70,
      skipHeight: 0.045,
      skipInset: 0.28,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final layout = _layout(size);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.black),
          AnimatedOpacity(
            opacity: _vidReady ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 350),
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
          if (_vidReady) ...[
            _TapZone(
              top: size.height * layout.acceptTop,
              height: size.height * layout.acceptHeight,
              left: size.width * layout.acceptInset,
              right: size.width * layout.acceptInset,
              onTap: _busy ? null : _accept,
            ),
            _TapZone(
              top: size.height * layout.skipTop,
              height: size.height * layout.skipHeight,
              left: size.width * layout.skipInset,
              right: size.width * layout.skipInset,
              onTap: _busy ? null : _skip,
            ),
          ],
          if (_busy)
            const ColoredBox(
              color: Color(0x44000000),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white70,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TapLayout {
  final double acceptTop;
  final double acceptHeight;
  final double acceptInset;
  final double skipTop;
  final double skipHeight;
  final double skipInset;

  const _TapLayout({
    required this.acceptTop,
    required this.acceptHeight,
    required this.acceptInset,
    required this.skipTop,
    required this.skipHeight,
    required this.skipInset,
  });
}

class _TapZone extends StatelessWidget {
  final double top;
  final double height;
  final double left;
  final double right;
  final VoidCallback? onTap;

  const _TapZone({
    required this.top,
    required this.height,
    required this.left,
    required this.right,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      height: height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: const SizedBox.expand(),
      ),
    );
  }
}
