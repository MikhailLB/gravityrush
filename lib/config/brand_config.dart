import '../utils/obfuscator.dart';
import 'endpoint_registry.dart';

const _attributionDevKey = [
  95, 125, 217, 105, 226, 233, 250, 51, 14, 201,
  22, 33, 250, 106, 10, 93, 248, 182, 17, 87,
  86, 89,
];

const _cloudProjectId = [
  125, 104, 214, 122, 225, 213, 203, 24, 11, 252,
  16, 71, 163, 26, 13, 88, 247,
];

abstract final class BrandConfig {
  static const packageName = 'com.gsteamgsgames.gravityrush';
  static const storeIdentifier = 'com.gsteamgsgames.gravityrush';
  static const displayTitle = 'Gravity Rush';
  static const iosAppId = '';

  static const cooldownSeconds = 259200;
  static const refreshDelaySeconds = 5;

  /// Debug-only override: AppsFlyer in the current SDK build started reporting
  /// `af_status: Organic` for every install on this branch, even when the
  /// install came from a OneLink. That makes it impossible to actually
  /// exercise the gray flow on a TestFlight / dev build because the gateway
  /// short-circuits to "no offer" for organic users. When this flag is `true`
  /// the attribution layer substitutes a hard-coded Non-organic conversion
  /// payload before composing the gateway request. MUST be set back to
  /// `false` before shipping.
  static const bool debugForceNonOrganic = true;

  static String get attributionDevKey => unpack(_attributionDevKey);
  static String get cloudProjectId => unpack(_cloudProjectId);
  static String get configUrl => brandEndpoint();
  static String get chromeVersion => browserChromeVersion();
  static String get safariVersion => browserSafariVersion();
  static String get privacyUrl => brandPrivacyUrl;
  static String get supportUrl => brandSupportUrl;
}
