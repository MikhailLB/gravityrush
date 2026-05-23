import 'dart:io';
import 'ball_endpoint.dart';
import 'signal_keys.dart';
import 'brand_links.dart';

abstract final class BallConfig {
  static const String iosStoreId = '6771020170';
  static const String bundleId   = 'com.bounce.balltwo';
  static const String appTitle   = 'Bounce Ball 2';

  static const int pushCooldownSeconds = 259200;
  static const int organicRetrySeconds = 6;

  static String get configEndpoint  => ballEndpointUrl();
  static String get installKey      => appsflyerDevKey();
  static String get firebaseNumber  => firebaseProjectNum();
  static String get privacyUrl      => brandPrivacyUrl;
  static String get supportUrl      => brandSupportUrl;
  static String get platformStoreId =>
      Platform.isIOS ? 'id$iosStoreId' : bundleId;
  static String get analyticsAppId  =>
      Platform.isIOS ? iosStoreId : bundleId;
}
