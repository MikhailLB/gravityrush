import 'dart:ui';

/// The five playable elemental orbs of the game.
///
/// Each element is a distinct "essence" that the player aligns on the board.
/// Matching three or more of the same essence triggers an elemental reaction.
enum Essence { frost, nature, solar, ember, arcane }

/// Visual + thematic metadata for every essence.
class EssenceStyle {
  final Essence essence;
  final String label;
  final String assetPath;
  final Color core;
  final Color glow;

  const EssenceStyle({
    required this.essence,
    required this.label,
    required this.assetPath,
    required this.core,
    required this.glow,
  });
}

const Map<Essence, EssenceStyle> kEssenceStyles = {
  Essence.frost: EssenceStyle(
    essence: Essence.frost,
    label: 'Frost',
    assetPath: 'assets/game_assets/blue_sphere_asset.webp',
    core: Color(0xFF4FC3F7),
    glow: Color(0xFF1976D2),
  ),
  Essence.nature: EssenceStyle(
    essence: Essence.nature,
    label: 'Verdant',
    assetPath: 'assets/game_assets/green_sphere_asset.webp',
    core: Color(0xFF66BB6A),
    glow: Color(0xFF2E7D32),
  ),
  Essence.solar: EssenceStyle(
    essence: Essence.solar,
    label: 'Solar',
    assetPath: 'assets/game_assets/yellow_sphere_asset.webp',
    core: Color(0xFFFFC107),
    glow: Color(0xFFFF8F00),
  ),
  Essence.ember: EssenceStyle(
    essence: Essence.ember,
    label: 'Ember',
    assetPath: 'assets/game_assets/red_sphere_asset.webp',
    core: Color(0xFFEF5350),
    glow: Color(0xFFC62828),
  ),
  Essence.arcane: EssenceStyle(
    essence: Essence.arcane,
    label: 'Arcane',
    assetPath: 'assets/game_assets/purple_sphere_asset.webp',
    core: Color(0xFFAB47BC),
    glow: Color(0xFF6A1B9A),
  ),
};

EssenceStyle styleOf(Essence e) => kEssenceStyles[e]!;

/// Shared asset paths that are not tied to a specific essence.
class GameArt {
  GameArt._();

  static const String corruption =
      'assets/game_assets/circle_with_skull_inside.webp';
  static const String logo = 'assets/logo_options/logo.jpg';

  static const List<String> essenceOrbs = [
    'assets/game_assets/blue_sphere_asset.webp',
    'assets/game_assets/green_sphere_asset.webp',
    'assets/game_assets/yellow_sphere_asset.webp',
    'assets/game_assets/red_sphere_asset.webp',
    'assets/game_assets/purple_sphere_asset.webp',
  ];
}
