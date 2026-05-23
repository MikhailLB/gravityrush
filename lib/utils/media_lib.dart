class MediaLib {
  MediaLib._();

  // Skins
  static const String blueSphere   = 'assets/game_assets/orb_aqua.webp';
  static const String greenSphere  = 'assets/game_assets/orb_verdant.webp';
  static const String yellowSphere = 'assets/game_assets/orb_solar.webp';
  static const String redSphere    = 'assets/game_assets/orb_blaze.webp';
  static const String purpleSphere = 'assets/game_assets/orb_void.webp';

  // Circles / markers
  static const String circleWithSkull = 'assets/game_assets/trap_marker.webp';

  // Logo
  static const String logo = 'assets/logo.jpg';

  static const List<String> allImages = [
    blueSphere, greenSphere, yellowSphere, redSphere, purpleSphere,
    circleWithSkull,
    logo,
  ];
}
