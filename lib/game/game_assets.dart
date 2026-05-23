import 'package:flame/components.dart';
import 'package:flame/game.dart';

class GameAssets {
  late final Sprite circleSkull;
  late final Map<String, Sprite> spheres;

  Future<void> loadAll(FlameGame game) async {
    game.images.prefix = 'assets/';

    final loaded = await Future.wait([
      game.loadSprite('game_assets/trap_marker.webp'),
      game.loadSprite('game_assets/orb_aqua.webp'),
      game.loadSprite('game_assets/orb_verdant.webp'),
      game.loadSprite('game_assets/orb_solar.webp'),
      game.loadSprite('game_assets/orb_blaze.webp'),
      game.loadSprite('game_assets/orb_void.webp'),
    ]);

    circleSkull = loaded[0];
    spheres = {
      'blue': loaded[1],
      'green': loaded[2],
      'yellow': loaded[3],
      'red': loaded[4],
      'purple': loaded[5],
    };
  }

  Sprite getSphere(String skinId) => spheres[skinId] ?? spheres['blue']!;
}
