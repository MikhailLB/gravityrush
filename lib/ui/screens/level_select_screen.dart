import 'package:flutter/material.dart';

import '../../core/palette.dart';
import '../../data/level.dart';
import '../../data/level_library.dart';
import '../../data/progress_store.dart';
import '../widgets/void_background.dart';
import 'game_screen.dart';

/// The campaign map: a scrollable grid of level nodes with their star ratings.
class LevelSelectScreen extends StatefulWidget {
  final ProgressStore progress;
  const LevelSelectScreen({super.key, required this.progress});

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  @override
  void initState() {
    super.initState();
    widget.progress.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.progress.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _play(Level level) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            GameScreen.campaign(level: level, progress: widget.progress),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: VoidBackground(
        child: SafeArea(
          child: Column(
            children: [
              _header(context),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(20),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: LevelLibrary.count,
                  itemBuilder: (context, i) {
                    final level = LevelLibrary.levels[i];
                    final unlocked = widget.progress.isUnlocked(level.index);
                    final stars = widget.progress.starsFor(level.index);
                    return _LevelNode(
                      level: level,
                      unlocked: unlocked,
                      stars: stars,
                      onTap: unlocked ? () => _play(level) : null,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded,
                color: Palette.textPrimary),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Text('SELECT REALM', style: Palette.title(20)),
          const Spacer(),
          const Icon(Icons.star_rounded, color: Palette.gold, size: 20),
          const SizedBox(width: 6),
          Text('${widget.progress.totalStars}',
              style: Palette.body(15, color: Palette.gold, weight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _LevelNode extends StatelessWidget {
  final Level level;
  final bool unlocked;
  final int stars;
  final VoidCallback? onTap;

  const _LevelNode({
    required this.level,
    required this.unlocked,
    required this.stars,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = unlocked ? Palette.accent : Palette.panelBorder;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: unlocked
              ? Palette.panel.withValues(alpha: 0.7)
              : Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent, width: 1.6),
          boxShadow: unlocked ? Palette.glow(Palette.accent, blur: 14) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!unlocked)
              const Icon(Icons.lock_rounded, color: Palette.textMuted, size: 30)
            else ...[
              Text(
                '${level.index}',
                style: TextStyle(
                  color: Palette.textPrimary,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  shadows: [Shadow(color: Palette.accent, blurRadius: 12)],
                ),
              ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  level.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Palette.body(10, color: Palette.textMuted),
                ),
              ),
            ],
            const SizedBox(height: 6),
            if (unlocked)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  return Icon(
                    i < stars ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 14,
                    color: i < stars
                        ? Palette.gold
                        : Palette.textMuted.withValues(alpha: 0.5),
                  );
                }),
              ),
          ],
        ),
      ),
    );
  }
}
