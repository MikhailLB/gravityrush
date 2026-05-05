import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../config/brand_config.dart';
import '../services/cloud_push_client.dart';
import '../services/local_store.dart';
import '../services/network_monitor.dart';
import '../utils/asset_paths.dart';
import 'web_host.dart' deferred as host;

class PushOptInScreen extends StatefulWidget {
  final LocalStore store;
  final CloudPushClient push;
  final NetworkMonitor net;
  final String target;

  const PushOptInScreen({
    super.key,
    required this.store,
    required this.push,
    required this.net,
    required this.target,
  });

  @override
  State<PushOptInScreen> createState() => _PushOptInScreenState();
}

class _PushOptInScreenState extends State<PushOptInScreen> {
  VideoPlayerController? _player;
  bool _playerReady = false;
  Orientation? _lastOrientation;
  bool _locked = false;

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
        ? AssetPaths.nfHorizontal
        : AssetPaths.nfVertical;
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

  Future<void> _accept() async {
    if (_locked) return;
    _locked = true;
    try {
      // askConsent handles all cooldown logic internally:
      //   - OS granted → writePushConsent(true)
      //   - OS denied  → _markSystemDenied writes a 1-year cooldown so
      //                   the offer screen never reappears after a hard no
      await widget.push.askConsent();
      if (!mounted) return;
      _openWebHost();
    } finally {
      _locked = false;
    }
  }

  Future<void> _skip() async {
    if (_locked) return;
    _locked = true;
    final until = DateTime.now().millisecondsSinceEpoch ~/ 1000 +
        BrandConfig.cooldownSeconds;
    await widget.store.writePushCooldown(until);
    if (!mounted) return;
    _openWebHost();
  }

  Future<void> _openWebHost() async {
    await host.loadLibrary();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => host.WebHost(
          target: widget.target,
          store: widget.store,
          push: widget.push,
          net: widget.net,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final landscape = _lastOrientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox(
        width: size.width,
        height: size.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_playerReady && _player != null)
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _player!.value.size.width,
                    height: _player!.value.size.height,
                    child: VideoPlayer(_player!),
                  ),
                ),
              )
            else
              const ColoredBox(color: Colors.black),
            _buildActions(size, landscape),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(Size size, bool landscape) {
    final acceptWidth = landscape ? size.width * 0.26 : size.width * 0.58;
    final skipWidth = landscape ? size.width * 0.18 : size.width * 0.40;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    // Landscape: dock much closer to the bottom edge so ALLOW clears the
    // gold frame. Portrait: keep a little more breathing room.
    final bottomPadding =
        (landscape ? size.height * 0.04 : size.height * 0.08) + bottomInset;

    return Positioned(
      left: 0,
      right: 0,
      bottom: bottomPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _GoldAcceptButton(
            width: acceptWidth,
            compact: landscape,
            onTap: _accept,
          ),
          SizedBox(height: landscape ? 8 : 12),
          _SkipButton(
            width: skipWidth,
            compact: landscape,
            onTap: _skip,
          ),
        ],
      ),
    );
  }
}

/// Golden gradient Accept button with animated shimmer and pulsing glow.
/// Matches the gold-framed UI in the notification-permission video.
class _GoldAcceptButton extends StatefulWidget {
  final double width;
  final bool compact;
  final VoidCallback onTap;

  const _GoldAcceptButton({
    required this.width,
    required this.compact,
    required this.onTap,
  });

  @override
  State<_GoldAcceptButton> createState() => _GoldAcceptButtonState();
}

class _GoldAcceptButtonState extends State<_GoldAcceptButton>
    with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _shimmer;
  bool _down = false;

  static const _gold = Color(0xFFF6C54A);
  static const _goldDeep = Color(0xFFB07713);
  static const _goldLight = Color(0xFFFFE9A8);

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = widget.compact ? 40.0 : 50.0;
    final fontSize = widget.compact ? 13.0 : 17.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) {
        setState(() => _down = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: AnimatedBuilder(
          animation: Listenable.merge([_pulse, _shimmer]),
          builder: (_, _) {
            final pulse = 0.5 + _pulse.value * 0.5;
            final shimmer = _shimmer.value;
            return SizedBox(
              width: widget.width,
              height: height,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer glow
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(height / 2),
                        boxShadow: [
                          BoxShadow(
                            color: _gold.withValues(alpha: 0.35 * pulse),
                            blurRadius: 22 + 10 * pulse,
                            spreadRadius: 1 + 2 * pulse,
                          ),
                          BoxShadow(
                            color: _goldLight.withValues(alpha: 0.25 * pulse),
                            blurRadius: 40 + 20 * pulse,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Body: gold gradient fill
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(height / 2),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            _goldLight,
                            _gold,
                            _goldDeep,
                          ],
                          stops: [0.0, 0.55, 1.0],
                        ),
                        border: Border.all(
                          color: _goldLight.withValues(alpha: 0.9),
                          width: 1.4,
                        ),
                      ),
                    ),
                  ),
                  // Inner highlight on top half
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(height / 2),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.center,
                            colors: [
                              Colors.white.withValues(alpha: 0.55),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Diagonal shimmer sweep
                  ClipRRect(
                    borderRadius: BorderRadius.circular(height / 2),
                    child: IgnorePointer(
                      child: Transform.translate(
                        offset: Offset(
                          (shimmer * 2.0 - 1.0) * widget.width,
                          0,
                        ),
                        child: Transform.rotate(
                          angle: -math.pi / 9,
                          child: Container(
                            width: widget.width * 0.35,
                            height: height * 2,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Colors.white.withValues(alpha: 0.0),
                                  Colors.white.withValues(alpha: 0.55),
                                  Colors.white.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Label
                  Text(
                    'ALLOW',
                    style: TextStyle(
                      color: const Color(0xFF3B2500),
                      fontSize: fontSize,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                      shadows: [
                        Shadow(
                          color: _goldLight.withValues(alpha: 0.9),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Outlined Skip button: minimal, gold-outline, subtle breathing animation.
class _SkipButton extends StatefulWidget {
  final double width;
  final bool compact;
  final VoidCallback onTap;

  const _SkipButton({
    required this.width,
    required this.compact,
    required this.onTap,
  });

  @override
  State<_SkipButton> createState() => _SkipButtonState();
}

class _SkipButtonState extends State<_SkipButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathe;
  bool _down = false;

  @override
  void initState() {
    super.initState();
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breathe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = widget.compact ? 30.0 : 38.0;
    final fontSize = widget.compact ? 11.0 : 14.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) {
        setState(() => _down = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: AnimatedBuilder(
          animation: _breathe,
          builder: (_, _) {
            final t = _breathe.value;
            return SizedBox(
              width: widget.width,
              height: height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(height / 2),
                  color: Colors.black.withValues(alpha: _down ? 0.5 : 0.35),
                  border: Border.all(
                    color: const Color(0xFFF6C54A)
                        .withValues(alpha: 0.55 + 0.25 * t),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF6C54A)
                          .withValues(alpha: 0.12 * t),
                      blurRadius: 10 + 8 * t,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                      shadows: const [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 2,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
