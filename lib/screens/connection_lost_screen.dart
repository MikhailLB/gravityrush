import 'dart:async';
import 'package:flutter/material.dart';
import '../services/network_monitor.dart';
import '../utils/asset_paths.dart';

class ConnectionLostScreen extends StatefulWidget {
  final WidgetBuilder retryBuilder;
  final NetworkMonitor net;

  const ConnectionLostScreen({
    super.key,
    required this.retryBuilder,
    required this.net,
  });

  @override
  State<ConnectionLostScreen> createState() => _ConnectionLostScreenState();
}

class _ConnectionLostScreenState extends State<ConnectionLostScreen>
    with SingleTickerProviderStateMixin {
  bool _busy = false;
  bool _showHint = false;
  Timer? _hintTimer;
  late final AnimationController _pulse;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _retry() async {
    if (_busy) return;
    await _pulse.forward();
    await _pulse.reverse();
    if (!mounted) return;
    setState(() => _busy = true);

    final online = await widget.net.isOnline();
    if (!mounted) return;

    if (!online) {
      _hintTimer?.cancel();
      setState(() {
        _busy = false;
        _showHint = true;
      });
      _hintTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showHint = false);
      });
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: widget.retryBuilder),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final landscape = mq.orientation == Orientation.landscape;
    final bgAsset = landscape ? AssetPaths.noWifiHorizontal : AssetPaths.noWifi;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            bgAsset,
            fit: BoxFit.cover,
            errorBuilder: (_, e, s) => const ColoredBox(color: Colors.black),
          ),
          if (landscape)
            _buildLandscapeAction(mq)
          else
            _buildPortraitAction(mq),
          if (landscape) _buildTopHint(mq),
        ],
      ),
    );
  }

  Widget _buildPortraitAction(MediaQueryData mq) {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 60, left: 36, right: 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedOpacity(
                opacity: _showHint ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Text(
                    'Check your internet connection',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ),
              ScaleTransition(
                scale: _scale,
                child: _buildButton(height: 52),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLandscapeAction(MediaQueryData mq) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: mq.padding.bottom + 14,
      child: Center(
        child: ScaleTransition(
          scale: _scale,
          child: SizedBox(
            width: mq.size.width * 0.32,
            child: _buildButton(height: 44),
          ),
        ),
      ),
    );
  }

  Widget _buildTopHint(MediaQueryData mq) {
    return Positioned(
      top: mq.padding.top + 12,
      left: 24,
      right: 24,
      child: AnimatedSlide(
        offset: _showHint ? Offset.zero : const Offset(0, -2),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: _showHint ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Check your internet connection and tap Retry',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButton({required double height}) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: _busy
              ? null
              : const LinearGradient(
                  colors: [Color(0xFF00E5FF), Color(0xFF00BCD4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: _busy ? Colors.cyanAccent.withValues(alpha: 0.3) : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _busy
              ? const []
              : [
                  BoxShadow(
                    color: Colors.cyanAccent.withValues(alpha: 0.4),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _busy ? null : _retry,
            child: Center(
              child: _busy
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Connecting...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    )
                  : const Text(
                      'Retry',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
