import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../infra/net_probe.dart';

/// No-internet screen with dungeon-ball themed artwork + cyan Retry button.
class NoNetScreen extends StatefulWidget {
  final WidgetBuilder retryBuilder;
  final NetProbe probe;

  const NoNetScreen({super.key, required this.retryBuilder, required this.probe});

  @override
  State<NoNetScreen> createState() => _NoNetScreenState();
}

class _NoNetScreenState extends State<NoNetScreen>
    with SingleTickerProviderStateMixin {
  bool _busy = false;
  bool _hint = false;
  Timer? _hintTimer;
  late final AnimationController _press;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(vsync: this, duration: const Duration(milliseconds: 130));
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _press.dispose();
    super.dispose();
  }

  Future<void> _retry() async {
    if (_busy) return;
    HapticFeedback.lightImpact();
    await _press.forward();
    await _press.reverse();
    if (!mounted) return;
    setState(() => _busy = true);
    final online = await widget.probe.isOnline();
    if (!mounted) return;
    if (!online) {
      _hintTimer?.cancel();
      setState(() { _busy = false; _hint = true; });
      _hintTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _hint = false);
      });
      return;
    }
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: widget.retryBuilder));
  }

  @override
  Widget build(BuildContext context) {
    final c = MediaQuery.of(context);
    final landscape = c.size.width > c.size.height;
    final topInset = c.viewPadding.top;
    final bgAsset = landscape
        ? 'assets/vt9k_off/veil_wide.webp'
        : 'assets/vt9k_off/veil_tall.webp';
    final btnW = landscape
        ? (c.size.width * 0.24).clamp(200.0, 340.0)
        : (c.size.width * 0.52).clamp(180.0, 300.0);
    final btnBottom = landscape ? c.size.height * 0.05 : c.size.height * 0.18;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(bgAsset, fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const ColoredBox(color: Color(0xFF080A1A))),
          Positioned(
            left: 0, right: 0, bottom: btnBottom,
            child: Center(
              child: AnimatedBuilder(
                animation: _press,
                builder: (context, child) => Transform.scale(
                  scale: 1.0 - 0.05 * _press.value, child: child,
                ),
                child: GestureDetector(
                  onTap: _busy ? null : _retry,
                  child: SizedBox(
                    width: btnW,
                    child: AspectRatio(
                      aspectRatio: 3.6,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: _busy ? null : const LinearGradient(
                            colors: [Color(0xFF00BCD4), Color(0xFF006064)],
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                          ),
                          color: _busy ? const Color(0xFF00BCD4).withValues(alpha: 0.3) : null,
                          border: Border.all(color: const Color(0xFF001F2E), width: 2),
                        ),
                        child: Center(
                          child: _busy
                              ? const SizedBox(width: 24, height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: Color(0xFF001F2E)))
                              : const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.refresh_rounded, color: Color(0xFF001F2E), size: 26),
                                    SizedBox(width: 8),
                                    Text('Retry',
                                        style: TextStyle(
                                          color: Color(0xFF001F2E),
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.0,
                                        )),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_hint)
            Positioned(
              top: topInset + 12, left: 20, right: 20,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Text('Still no internet — please try again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 13)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
