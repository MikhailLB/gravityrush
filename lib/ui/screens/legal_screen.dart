import 'package:flutter/material.dart';

import '../../core/haptics.dart';
import '../../core/palette.dart';
import '../../data/progress_store.dart';
import '../widgets/glow_button.dart';
import '../widgets/void_background.dart';
import 'web_view_screen.dart';

/// Settings / About hub: haptics toggle plus the hosted Privacy & Support
/// pages (opened in an in-app web view).
class LegalScreen extends StatefulWidget {
  final ProgressStore progress;
  const LegalScreen({super.key, required this.progress});

  static const String privacyUrl =
      'https://bounceball2.com/privacy-policy.html';
  static const String supportUrl = 'https://bounceball2.com/support.html';

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  void _open(String title, String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WebViewScreen(title: title, url: url),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: VoidBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: Palette.textPrimary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Text('SETTINGS & ABOUT', style: Palette.title(18)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _aboutBlock(),
                    _settingsBlock(),
                    _linksBlock(),
                    const SizedBox(height: 12),
                    Center(
                      child: Text('Version 1.0',
                          style: Palette.body(12, color: Palette.textMuted)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Palette.panel.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Palette.panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Palette.title(18, glowColor: Palette.accent)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _aboutBlock() {
    return _card(
      title: 'About',
      child: Text(
        'Bounce Ball 2 is a single-player elemental match puzzle. Align orbs '
        'of the five essences, forge reactions, trigger volatile chain '
        'explosions and cleanse corruption across the campaign and the '
        'unlockable game modes.',
        style: Palette.body(14, color: Palette.textPrimary),
      ),
    );
  }

  Widget _settingsBlock() {
    return _card(
      title: 'Settings',
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        activeThumbColor: Palette.accentBright,
        title: Text('Haptics',
            style: Palette.body(15, color: Palette.textPrimary)),
        subtitle: Text('Vibrate on swipes and explosions',
            style: Palette.body(12, color: Palette.textMuted)),
        value: widget.progress.hapticsEnabled,
        onChanged: (v) async {
          await widget.progress.setHaptics(v);
          Haptics.enabled = v;
          if (v) Haptics.select();
          setState(() {});
        },
      ),
    );
  }

  Widget _linksBlock() {
    return _card(
      title: 'Legal & Help',
      child: Column(
        children: [
          GlowButton(
            label: 'PRIVACY POLICY',
            icon: Icons.privacy_tip_outlined,
            color: Palette.accent,
            filled: false,
            width: double.infinity,
            height: 52,
            onTap: () => _open('Privacy Policy', LegalScreen.privacyUrl),
          ),
          const SizedBox(height: 12),
          GlowButton(
            label: 'SUPPORT',
            icon: Icons.help_outline_rounded,
            color: Palette.accentBright,
            filled: false,
            width: double.infinity,
            height: 52,
            onTap: () => _open('Support', LegalScreen.supportUrl),
          ),
        ],
      ),
    );
  }
}
