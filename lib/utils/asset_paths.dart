class AssetPaths {
  AssetPaths._();

  // Skins
  static const String blueSphere = 'assets/game_assets/blue_sphere_asset.webp';
  static const String greenSphere = 'assets/game_assets/green_sphere_asset.webp';
  static const String yellowSphere = 'assets/game_assets/yellow_sphere_asset.webp';
  static const String redSphere = 'assets/game_assets/red_sphere_asset.webp';
  static const String purpleSphere = 'assets/game_assets/purple_sphere_asset.webp';

  // Pipes
  static const String greenPipe = 'assets/game_assets/green_pipe.webp';
  static const String redPipeWithSkull = 'assets/game_assets/red_pipe_with_skull.webp';
  static const String redPipeWithoutSkull = 'assets/game_assets/red_pipe_without_skull.webp';

  // Circles / markers
  static const String greenCircle = 'assets/game_assets/green_circle.webp';
  static const String circleWith2x = 'assets/game_assets/circle_with_2x_inside.webp';
  static const String circleWithSkull = 'assets/game_assets/circle_with_skull_inside.webp';
  static const String asset2x = 'assets/game_assets/2x_asset.webp';

  // Spikes
  static const String blueSpike = 'assets/game_assets/blue_spike.webp';
  static const String redSpike = 'assets/game_assets/red_spike.webp';

  // Background
  static const String background = 'assets/game_assets/backround_asset.webp';

  // Loading screen
  static const String loadingBarStart = 'assets/loading_screen/loading_bar_start.webp';
  static const String loadingBarHalf = 'assets/loading_screen/loading_bar_half.webp';
  static const String loadingBarAlmostFull = 'assets/loading_screen/loading_bar_almost_full.webp';
  static const String loadingBarFull = 'assets/loading_screen/loading_bar_full.webp';
  static const String loadingBarEmpty = 'assets/loading_screen/loading_bar_empty.webp';
  static const String loadingVertical = 'assets/loading_screen/loading_vertical.mp4';
  static const String loadingHorizontal = 'assets/loading_screen/loading_horizontal.mp4';

  // Logo
  static const String logo = 'assets/logo_options/logo.webp';

  // No WiFi
  static const String noWifi = 'assets/NO_WIFI/no_wifi_screen.webp';
  static const String noWifiHorizontal = 'assets/NO_WIFI/no_wifi_horizontal.webp';

  // Ad screens
  static const String nfVertical = 'assets/add_screens/nf_vertical_screen.mp4';
  static const String nfHorizontal = 'assets/add_screens/nf_horizontal_screen.mp4';

  static const List<String> allImages = [
    blueSphere, greenSphere, yellowSphere, redSphere, purpleSphere,
    greenPipe, redPipeWithSkull, redPipeWithoutSkull,
    greenCircle, circleWith2x, circleWithSkull, asset2x,
    blueSpike, redSpike,
    background,
    loadingBarStart, loadingBarHalf, loadingBarAlmostFull, loadingBarFull, loadingBarEmpty,
    logo, noWifi, noWifiHorizontal,
  ];
}
