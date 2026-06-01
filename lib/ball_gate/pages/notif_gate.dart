import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../config/ball_config.dart';
import '../infra/ball_vault.dart';
import '../infra/flare_relay.dart';
import '../infra/net_probe.dart';
import 'ball_browser.dart';

/// Push permission screen for Bounce Ball 2.
/// Background: looping MP4 clip — neon/bounce aesthetic.
/// Buttons: neon cyan gradient matching the game theme.
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

class _NotifGateState extends State<NotifGate> with TickerProviderStateMixin {
  VideoPlayerController? _vid;
  Orientation? _activeOrientation;
  bool _vidReady = false;
  bool _busy = false;
  late final AnimationController _glow;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _glow = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
        ..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final o = MediaQuery.of(context).orientation;
    if (o != _activeOrientation) { _activeOrientation = o; _loadVideo(o); }
  }

  @override
  void dispose() {
    _vid?.dispose();
    _glow.dispose();
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
      if (!mounted) { ctrl.dispose(); return; }
      setState(() { _vid = ctrl; _vidReady = true; });
      old?.dispose();
    } catch (_) { ctrl.dispose(); }
  }

  Future<void> _accept() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final granted = await widget.flare.askConsent();
      if (granted) {
        final token = await widget.flare.refreshTokenAfterConsent();
        if (token != null && token.isNotEmpty) await widget.onTokenReady?.call(token);
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

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final landscape = mq.size.width > mq.size.height;
    final btnW = landscape
        ? (mq.size.width * 0.30).clamp(220.0, 360.0)
        : mq.size.width * 0.76;
    final bottomGap = mq.size.height * (landscape ? 0.05 : 0.07);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_vidReady && _vid != null)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _vid!.value.size.width,
                  height: _vid!.value.size.height,
                  child: VideoPlayer(_vid!),
                ),
              )
            else
              const ColoredBox(color: Color(0xFF080A1A)),
            SafeArea(
              child: Stack(
                children: [
                  Positioned(
                    left: 0, right: 0, bottom: bottomGap,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _CyanAcceptButton(
                          width: btnW,
                          busy: _busy,
                          glow: _glow,
                          onTap: _accept,
                          compact: landscape,
                        ),
                        SizedBox(height: mq.size.height * 0.022),
                        _SkipText(onTap: _skip, compact: landscape),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Neon cyan Accept button — matches BounceBall 2 neon aesthetic.
class _CyanAcceptButton extends StatefulWidget {
  final double width;
  final bool busy;
  final bool compact;
  final AnimationController glow;
  final VoidCallback onTap;
  const _CyanAcceptButton({
    required this.width, required this.busy, required this.glow,
    required this.onTap, this.compact = false,
  });
  @override
  State<_CyanAcceptButton> createState() => _CyanAcceptButtonState();
}

class _CyanAcceptButtonState extends State<_CyanAcceptButton>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _press = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 100));
  @override
  void dispose() { _press.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final fontSize = widget.compact ? 16.0 : 20.0;
    return GestureDetector(
      onTapDown: (_) { setState(() => _pressed = true); _press.forward(); },
      onTapUp: (_) { setState(() => _pressed = false); _press.reverse(); widget.onTap(); },
      onTapCancel: () { setState(() => _pressed = false); _press.reverse(); },
      child: AnimatedBuilder(
        animation: Listenable.merge([_press, widget.glow]),
        builder: (context, child) => Transform.scale(
          scale: 1.0 - 0.04 * _press.value,
          child: Container(
            width: widget.width,
            padding: EdgeInsets.symmetric(vertical: widget.compact ? 12 : 17),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _pressed
                    ? [const Color(0xFF006064), const Color(0xFF004D51)]
                    : [const Color(0xFF00BCD4), const Color(0xFF006064)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(50),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00BCD4).withValues(
                      alpha: _pressed ? 0.15 : 0.25 + 0.30 * widget.glow.value),
                  blurRadius: _pressed ? 8 : 18 + widget.glow.value * 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: widget.busy
                  ? SizedBox(
                      width: fontSize + 4, height: fontSize + 4,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2.5, color: Color(0xFF001F2E)))
                  : Text('Accept',
                      style: TextStyle(
                        color: const Color(0xFF001F2E),
                        fontSize: fontSize,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      )),
            ),
          ),
        ),
      ),
    );
  }
}

class _SkipText extends StatefulWidget {
  final VoidCallback onTap;
  final bool compact;
  const _SkipText({required this.onTap, this.compact = false});
  @override
  State<_SkipText> createState() => _SkipTextState();
}

class _SkipTextState extends State<_SkipText> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedOpacity(
        opacity: _pressed ? 0.45 : 0.82,
        duration: const Duration(milliseconds: 80),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: widget.compact ? 4 : 8),
          child: Text('Skip',
              style: TextStyle(
                color: Colors.white,
                fontSize: widget.compact ? 16 : 22,
                fontWeight: FontWeight.w700,
                shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
              )),
        ),
      ),
    );
  }
}
