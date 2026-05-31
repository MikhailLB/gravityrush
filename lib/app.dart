import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/haptics.dart';
import 'core/palette.dart';
import 'data/progress_store.dart';
import 'screens/preload_screen.dart';
import 'ui/screens/home_screen.dart';

/// Root of the app. Shows the (unchanged) loading screen first, warms up the
/// progress store, then hands off to the main menu.
class ElementraApp extends StatefulWidget {
  const ElementraApp({super.key});

  @override
  State<ElementraApp> createState() => _ElementraAppState();
}

class _ElementraAppState extends State<ElementraApp> {
  final ProgressStore _progress = ProgressStore();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  Future<void> _onPreloaded() async {
    await _progress.init();
    Haptics.enabled = _progress.hapticsEnabled;
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bounce Ball 2',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Palette.voidDeep,
      ),
      home: _ready
          ? HomeScreen(progress: _progress)
          : PreloadScreen(onReady: _onPreloaded),
    );
  }
}
