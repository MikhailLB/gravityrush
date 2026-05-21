import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ball_skin.dart';
import '../utils/media_lib.dart';
import 'web_view_screen.dart';

class LobbyScreen extends StatefulWidget {
  final void Function(BallSkin skin) onPlay;

  const LobbyScreen({super.key, required this.onPlay});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen>
    with SingleTickerProviderStateMixin {
  int _activeSkinIdx = 0;
  int _balance = 0;
  Set<String> _owned = {'blue'};
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _balance = prefs.getInt('bb2_wallet') ?? 0;
      final raw = prefs.getString('bb2_owned') ?? 'blue';
      _owned = raw.split(',').toSet();
      final saved = prefs.getString('bb2_active') ?? 'blue';
      _activeSkinIdx = BallSkin.all
          .indexWhere((s) => s.id == saved)
          .clamp(0, BallSkin.all.length - 1);
      if (!_owned.contains(BallSkin.all[_activeSkinIdx].id)) {
        _activeSkinIdx = 0;
      }
    });
  }

  Future<void> _saveActive(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bb2_active', id);
  }

  Future<void> _buySkin(BallSkin skin) async {
    if (_balance < skin.price) return;
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _balance -= skin.price;
      _owned.add(skin.id);
    });
    await prefs.setInt('bb2_wallet', _balance);
    await prefs.setString('bb2_owned', _owned.join(','));
  }

  void _onSkinTap(int index) {
    final skin = BallSkin.all[index];
    final isOwned = _owned.contains(skin.id);

    if (isOwned) {
      setState(() => _activeSkinIdx = index);
      _saveActive(skin.id);
    } else if (_balance >= skin.price) {
      _showBuyDialog(skin, index);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Need ${BallSkin.formatPrice(skin.price)} coins',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red.withValues(alpha: 0.8),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _showBuyDialog(BallSkin skin, int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF150025),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'BUY ${skin.name.toUpperCase()}?',
          style: TextStyle(color: skin.primaryColor, letterSpacing: 2),
        ),
        content: Text(
          'Cost: ${BallSkin.formatPrice(skin.price)} coins\n'
          'Balance: ${BallSkin.formatPrice(_balance)}',
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _buySkin(skin);
              setState(() => _activeSkinIdx = index);
              _saveActive(skin.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: skin.primaryColor.withValues(alpha: 0.3),
              foregroundColor: skin.primaryColor,
            ),
            child: const Text('BUY', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeSkin = BallSkin.all[_activeSkinIdx];
    return Scaffold(
      backgroundColor: const Color(0xFF080015),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 30),
            Image.asset(MediaLib.logo, width: 140, height: 140),
            const SizedBox(height: 10),
            const Text(
              'GRAVITY RUSH',
              style: TextStyle(
                color: Color(0xFFCC66FF),
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 6,
                shadows: [
                  Shadow(color: Color(0xFFCC66FF), blurRadius: 24),
                  Shadow(color: Color(0xFF8800FF), blurRadius: 8),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'BALANCE: ${BallSkin.formatPrice(_balance)}',
              style: const TextStyle(
                color: Color(0xFFFFCC00),
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                shadows: [Shadow(color: Color(0xFFFFAA00), blurRadius: 10)],
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'SHOP',
              style: TextStyle(
                color: Color(0x77CC66FF),
                fontSize: 13,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 10),
            _buildSkinGrid(activeSkin),
            const Spacer(),
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) => Transform.scale(
                scale: _pulse.value,
                child: child,
              ),
              child: _buildPlayButton(activeSkin),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _linkButton('Privacy Policy', 'https://bounceball2.com/privacy-policy.html'),
                const SizedBox(width: 20),
                _linkButton('Support', 'https://bounceball2.com/support.html'),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _linkButton(String label, String url) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WebViewScreen(title: label, url: url),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.35),
          fontSize: 12,
          decoration: TextDecoration.underline,
          decorationColor: Colors.white.withValues(alpha: 0.25),
        ),
      ),
    );
  }

  Widget _buildSkinGrid(BallSkin selected) {
    return SizedBox(
      height: 150,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: BallSkin.all.length,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
          final skin = BallSkin.all[index];
          final isSelected = index == _activeSkinIdx;
          final isOwned = _owned.contains(skin.id);
          final canAfford = _balance >= skin.price;

          return GestureDetector(
            onTap: () => _onSkinTap(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 92,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? skin.primaryColor
                      : isOwned
                          ? Colors.white24
                          : Colors.white10,
                  width: isSelected ? 2 : 1,
                ),
                color: isSelected
                    ? skin.primaryColor.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.03),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: skin.primaryColor.withValues(alpha: 0.4),
                          blurRadius: 16,
                        )
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Opacity(
                        opacity: isOwned ? 1.0 : 0.3,
                        child: Image.asset(skin.assetPath, width: 46, height: 46),
                      ),
                      if (!isOwned)
                        Icon(
                          Icons.lock,
                          color: Colors.white.withValues(alpha: 0.6),
                          size: 22,
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    skin.name,
                    style: TextStyle(
                      color: isOwned
                          ? (isSelected ? skin.primaryColor : Colors.white60)
                          : Colors.white30,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (isOwned)
                    Text(
                      skin.rarity.name.toUpperCase(),
                      style: TextStyle(
                        color: isSelected
                            ? skin.primaryColor.withValues(alpha: 0.7)
                            : Colors.white30,
                        fontSize: 9,
                        letterSpacing: 1,
                      ),
                    )
                  else
                    Text(
                      BallSkin.formatPrice(skin.price),
                      style: TextStyle(
                        color: canAfford
                            ? Colors.amberAccent.withValues(alpha: 0.9)
                            : Colors.redAccent.withValues(alpha: 0.6),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlayButton(BallSkin skin) {
    return SizedBox(
      width: 200,
      height: 60,
      child: ElevatedButton(
        onPressed: () => widget.onPlay(skin),
        style: ElevatedButton.styleFrom(
          backgroundColor: skin.primaryColor.withValues(alpha: 0.2),
          foregroundColor: skin.primaryColor,
          side: BorderSide(color: skin.primaryColor, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: Text(
          'PLAY',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 6,
            shadows: [Shadow(color: skin.primaryColor, blurRadius: 15)],
          ),
        ),
      ),
    );
  }
}
