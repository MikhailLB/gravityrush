import 'package:flutter/material.dart';
import '../utils/media_lib.dart';

class PreloadScreen extends StatefulWidget {
  final VoidCallback onReady;

  const PreloadScreen({super.key, required this.onReady});

  @override
  State<PreloadScreen> createState() => _PreloadScreenState();
}

class _PreloadScreenState extends State<PreloadScreen>
    with SingleTickerProviderStateMixin {
  double _progress = 0;
  bool _started = false;
  late AnimationController _glowCtrl;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _preload();
    }
  }

  Future<void> _preload() async {
    final images = MediaLib.allImages;
    final total = images.length;
    int done = 0;

    for (final path in images) {
      if (!mounted) return;
      try {
        await precacheImage(AssetImage(path), context);
      } catch (_) {}
      done++;
      if (mounted) setState(() => _progress = done / total);
    }

    if (mounted) {
      setState(() => _progress = 1.0);
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) widget.onReady();
    }
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.1,
            colors: [Color(0xFF17134A), Color(0xFF070714), Colors.black],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    MediaLib.logo,
                    width: 130,
                    height: 130,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stack) => const SizedBox(height: 130),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'BOUNCE BALL 2',
                    style: TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 5,
                      shadows: [Shadow(color: Colors.cyanAccent, blurRadius: 18)],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'LOADING',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                      letterSpacing: 4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 60,
              left: 40,
              right: 40,
              child: AnimatedBuilder(
                animation: _glowCtrl,
                builder: (context, child) {
                  return Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: _progress,
                          minHeight: 6,
                          backgroundColor: Colors.white12,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color.lerp(
                              Colors.cyanAccent,
                              Colors.purpleAccent,
                              _progress,
                            )!
                                .withValues(
                              alpha: 0.7 + 0.3 * _glowCtrl.value,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
