# Gray Flow тАФ Living Integration Guide
## For AI agents working on this project

---

## What Is This Project?

This is a Flutter app template that implements a **"gray flow"** тАФ a dual-mode mobile app:

- **Gray mode (online):** Shows a WebView with URL provided by a remote backend. The app acts as a content shell.
- **White mode (offline):** Shows an offline game (fallback when the backend returns no URL).

The backend decides which users see the WebView based on attribution data (AppsFlyer install source, campaign, etc.). Organic/unattributed users typically get the game; users coming from specific ad campaigns get the WebView content.

**Why this architecture exists:** Allows one app binary to serve two completely different experiences, determined at runtime without code changes.

---

## Project Layout

```
lib/
тФЬтФАтФА main.dart               Entry point: Firebase, HttpAgent, services, runApp
тФЬтФАтФА bootstrap.dart          Root widget (StreetSurgeApp) тАФ TODO: rename per project
тФЬтФАтФА cfg/                    тЪая╕П ALL CREDENTIALS LIVE HERE
тФВ   тФЬтФАтФА app_config.dart     Bundle ID, App Store ID, app name
тФВ   тФЬтФАтФА network_cfg.dart    Encoded config endpoint URL
тФВ   тФЬтФАтФА tracker_data.dart   Encoded AppsFlyer key + Firebase project number
тФВ   тФФтФАтФА remote_paths.dart   Privacy policy + support URLs
тФЬтФАтФА pages/
тФВ   тФЬтФАтФА launch_page.dart    тШЕ CORE: splash video + routing logic
тФВ   тФЬтФАтФА notify_page.dart    Push permission promo screen (with video)
тФВ   тФЬтФАтФА web_view_page.dart  WebView + keyboard/safe-area JS injections
тФВ   тФФтФАтФА no_signal_page.dart No internet error screen with retry
тФЬтФАтФА infra/
тФВ   тФЬтФАтФА api_client.dart     POST to config endpoint, cache URL
тФВ   тФЬтФАтФА analytics_tracker.dart  AppsFlyer SDK init + attribution waiting
тФВ   тФЬтФАтФА cold_start_bridge.dart  iOS: read push URL written by SceneDelegate
тФВ   тФЬтФАтФА data_store.dart     SharedPreferences + SecureStorage wrapper
тФВ   тФЬтФАтФА http_agent.dart     HTTP client with real device User-Agent
тФВ   тФЬтФАтФА net_checker.dart    Internet connectivity check (DNS probe)
тФВ   тФФтФАтФА push_manager.dart   Firebase FCM + flutter_local_notifications
тФЬтФАтФА data/
тФВ   тФЬтФАтФА api_result.dart     API response model {ok, url, expires, message}
тФВ   тФФтФАтФА app_state.dart      online / offline / pending enum
тФЬтФАтФА helpers/
тФВ   тФФтФАтФА cipher.dart         тЪая╕П XOR cipher тАФ change seed per app
тФФтФАтФА core/
    тФФтФАтФА white_part.dart     тЪая╕П TODO: replace with actual game widget

tool/
тФФтФАтФА encode_keys.dart        Run with `dart run tool/encode_keys.dart` to encode secrets

ios/Runner/
тФЬтФАтФА SceneDelegate.swift     Captures push URLs on cold start
тФФтФАтФА Info.plist              тЪая╕П Multiple keys required тАФ see iOS section below
```

---

## Setup Checklist (for a new project)

### Step 1 тАФ Credentials in `lib/cfg/`

| File | What to change |
|------|---------------|
| `app_config.dart` | `iosAppStoreId`, `bundleId`, `appName` |
| `network_cfg.dart` | Byte arrays for config endpoint URL |
| `tracker_data.dart` | Byte arrays for AppsFlyer key, Firebase project number, GCD URL |
| `remote_paths.dart` | Privacy policy and support page URLs |
| `helpers/cipher.dart` | `seedBytes` тАФ unique per app, drives all encoding |

### Step 2 тАФ Encode secrets

```bash
dart run tool/encode_keys.dart
```

Fill in your values at the top of `tool/encode_keys.dart`, run it, copy the printed byte arrays into the cfg files.

**тЪая╕П Always use `dart run`, never PowerShell `foreach` loops for encoding.**
PowerShell truncates integers at 32 bits on Windows, producing wrong byte values.
Symptom: `FormatException: Invalid HTTP header field value` in network logs.

### Step 3 тАФ Change cipher seed

Edit `seedBytes` in `lib/helpers/cipher.dart`. Use a short unique ASCII string (6тАУ12 chars). Then re-encode all secrets (Step 2).

### Step 4 тАФ Firebase config files

- Android: `android/app/google-services.json`
- iOS: `ios/Runner/GoogleService-Info.plist`

Both must match your bundle ID / applicationId exactly.
Add to `.gitignore` if the repo is public.

### Step 5 тАФ Bundle IDs

| File | Field |
|------|-------|
| `android/app/build.gradle.kts` | `namespace` and `applicationId` |
| `ios/Runner.xcodeproj/project.pbxproj` | `PRODUCT_BUNDLE_IDENTIFIER` (3 occurrences for Runner + 3 for RunnerTests) |
| `lib/cfg/app_config.dart` | `bundleId` constant |

Also: move `MainActivity.kt` to match the new package path.

### Step 7 тАФ iOS Notification Service Extension (NSE)

The NSE allows iOS to attach rich media images to push notifications when the app is backgrounded or killed. Without it, images only appear when the Dart isolate is alive.

#### 7a тАФ Create NSE Swift files

Create `ios/NotificationService/NotificationService.swift`:
```swift
import UserNotifications
#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

class NotificationService: UNNotificationServiceExtension {
  var contentHandler: ((UNNotificationContent) -> Void)?
  var bestAttemptContent: UNMutableNotificationContent?

  override func didReceive(_ request: UNNotificationRequest,
    withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
    self.contentHandler = contentHandler
    bestAttemptContent = request.content.mutableCopy() as? UNMutableNotificationContent
    guard let best = bestAttemptContent else { contentHandler(request.content); return }
    #if canImport(FirebaseMessaging)
    Messaging.serviceExtension().populateNotificationContent(best, withContentHandler: contentHandler)
    #else
    contentHandler(best)
    #endif
  }

  override func serviceExtensionTimeWillExpire() {
    if let h = contentHandler, let b = bestAttemptContent { h(b) }
  }
}
```

Create `ios/NotificationService/Info.plist` тАФ standard app-extension plist with:
```xml
<key>NSExtension</key>
<dict>
  <key>NSExtensionPointIdentifier</key>
  <string>com.apple.usernotifications.service</string>
  <key>NSExtensionPrincipalClass</key>
  <string>$(PRODUCT_MODULE_NAME).NotificationService</string>
</dict>
```

#### 7b тАФ Podfile

Add to `ios/Podfile` (MUST be outside the Runner target block):
```ruby
target 'NotificationService' do
  use_frameworks!
  pod 'Firebase/Messaging'
end
```

#### 7c тАФ Wire NSE into project.pbxproj

This is the most error-prone step. Add the following sections manually (or copy from a working project):

**UUIDs to use** (pick any unique 24-char hex strings for your project):
```
NSE_SWIFT_BUILD_FILE   = AA00000100000000000001AA
NSE_SWIFT_FILE_REF     = AA00000100000000000003AA
NSE_PLIST_FILE_REF     = AA00000100000000000004AA
NSE_APPEX_FILE_REF     = AA00000100000000000005AA
NSE_GROUP              = AA00000100000000000006AA
NSE_TARGET             = AA00000100000000000007AA
NSE_SOURCES_PHASE      = AA00000100000000000008AA
NSE_RESOURCES_PHASE    = AA00000100000000000009AA
NSE_FRAMEWORKS_PHASE   = AA0000010000000000000AAA
NSE_DEBUG_CFG          = AA0000010000000000000BAA
NSE_RELEASE_CFG        = AA0000010000000000000CAA
NSE_PROFILE_CFG        = AA0000010000000000000DAA
NSE_CFG_LIST           = AA0000010000000000000EAA
EMBED_EXT_PHASE        = AA0000010000000000000FAA
EMBED_EXT_BUILD_FILE   = AA00000100000000000010AA
NSE_TARGET_DEP         = AA00000100000000000011AA
NSE_PROXY              = AA00000100000000000012AA
GOOGLE_PLIST_FILE_REF  = AA00000100000000000013AA
GOOGLE_PLIST_BUILD     = AA00000100000000000014AA
```

**Critical rules for pbxproj:**

1. **PBXBuildFile** тАФ add NSE swift source and Embed App Extensions entry
2. **PBXContainerItemProxy** тАФ proxy for NSE target dependency
3. **PBXCopyFilesBuildPhase** тАФ `Embed App Extensions` with `dstSubfolderSpec = 13`
4. **PBXFileReference** тАФ NSE swift, NSE Info.plist, NSE appex product, GoogleService-Info.plist
5. **PBXGroup** тАФ add NSE group, add NSE product to Products, add GoogleService-Info.plist to Runner group
6. **PBXNativeTarget (NSE)** тАФ `productType = "com.apple.product-type.app-extension"`
7. **PBXNativeTarget (Runner)** тАФ add NSE as dependency + `Embed App Extensions` phase
8. **XCBuildConfiguration (NSE)** тАФ тЪая╕П **NO** `baseConfigurationReference` тАФ let CocoaPods set it
9. **Build phases ORDER in Runner**:
   ```
   Run Script тЖТ Sources тЖТ Frameworks тЖТ Resources тЖТ
   Embed Frameworks тЖТ Embed App Extensions тЖТ Thin Binary
   ```
   тЪая╕П `Embed App Extensions` MUST come BEFORE `Thin Binary` тАФ otherwise Xcode detects a build cycle

**NSE build settings** тАФ hardcode version, do NOT use `$(FLUTTER_BUILD_NUMBER)`:
```
CURRENT_PROJECT_VERSION = 1;          тЖР hardcoded, NOT $(FLUTTER_BUILD_NUMBER)
MARKETING_VERSION = 1.0;              тЖР hardcoded, NOT $(FLUTTER_BUILD_NAME)
INFOPLIST_FILE = NotificationService/Info.plist;
PRODUCT_BUNDLE_IDENTIFIER = com.yourapp.NotificationService;
SKIP_INSTALL = YES;
```

тЪая╕П **Why NOT use `$(FLUTTER_BUILD_NUMBER)` in NSE configs:**
If you set `baseConfigurationReference` to `Debug.xcconfig`/`Release.xcconfig` to inherit Flutter's xcconfig (which defines `FLUTTER_BUILD_NUMBER`), CocoaPods can no longer set its own xcconfig as the base for the NSE target. CocoaPods will print warnings and the NSE won't get Firebase/Messaging linked. Hardcoding `CURRENT_PROJECT_VERSION = 1` avoids the conflict.

**NSE Resources phase** тАФ EMPTY (do NOT add Info.plist):
```
AA00000100000000000009AA /* Resources */ = {
  isa = PBXResourcesBuildPhase;
  files = ();   тЖР empty!
};
```
тЪая╕П Adding Info.plist to Resources causes `Multiple commands produce ... Info.plist` error because `INFOPLIST_FILE` build setting already handles it.

**GoogleService-Info.plist** тАФ must be added to Runner's Copy Bundle Resources:
```
97C146EC1CF9000F007C117D /* Resources */ = {
  files = (
    ...,
    AA00000100000000000014AA /* GoogleService-Info.plist in Resources */,
  );
};
```
Without this, Firebase.initializeApp() silently fails: `Could not locate configuration file: 'GoogleService-Info.plist'`

**All white-part routes must be registered in the root MaterialApp:**
```dart
routes: {
  '/loading':        (_) => const LoadingScreen(),
  '/menu':           (_) => const MainMenuScreen(),
  '/level-select':   (_) => const LevelSelectScreen(),
  '/game':           (_) => const GameScreen(),
  '/level-complete': (_) => const LevelCompleteScreen(),
},
```
Without this, navigating from the gray flow to the white game crashes with `Could not find route "/menu"`.

#### 7d тАФ After wiring, run pod install

```bash
cd ios
pod install    # must produce NO warnings about base configuration
open Runner.xcworkspace   # ALWAYS open .xcworkspace, never .xcodeproj
```

If `pod install` still prints CocoaPods xcconfig warnings for the NSE target, it means there's still a `baseConfigurationReference` in the NSE build configs. Remove it.

### Step 6 тАФ White part (your game)

Replace `WhitePartPlaceholder` in `lib/core/white_part.dart`:
1. Copy your game files into `lib/core/` (or subdirectory)
2. Replace `WhitePartPlaceholder` class with your game widget
3. Implement `MediaBundle.loadAll()` to preload assets

The single integration point is in `launch_page.dart`:
```dart
void _navigateToGame() {
  // тЪая╕П TODO: Replace WhitePartPlaceholder with your game
  Navigator.of(context).pushReplacement(
    MaterialPageRoute(builder: (_) => const WhitePartPlaceholder()),
  );
}
```

---

## Gray Flow Logic (launch_page.dart in detail)

```
AppState.pending (first launch)
  тФЬтФАтФА No internet тЖТ NoSignalPage (retry тЖТ LaunchPage)
  тФФтФАтФА Has internet
        тФЬтФАтФА Init AppsFlyer, wait attribution (30s) + deepLink (12s)
        тФЬтФАтФА POST to config endpoint with attribution body
        тФЬтФАтФА Response ok + url тЖТ setAppMode(online) тЖТ WebView / NotifyPage
        тФФтФАтФА Response error / no url тЖТ setAppMode(offline) тЖТ Game

AppState.online (returning user)
  тФЬтФАтФА No internet тЖТ NoSignalPage
  тФЬтФАтФА Push URL stored тЖТ WebView (from push tap)
  тФЬтФАтФА Fresh API call тЖТ WebView (new URL)
  тФФтФАтФА API fail + savedUrl тЖТ WebView (cached URL)

AppState.offline (returning user, flagged as white)
  тФЬтФАтФА Has internet тЖТ tryRestoreOnlineContent()
  тФВ     тФЬтФАтФА API ok тЖТ setAppMode(online) тЖТ WebView (re-conversion)
  тФВ     тФФтФАтФА API fail тЖТ Game
  тФФтФАтФА No internet тЖТ Game
```

**Key insight:** `AppState.offline` users can be "re-converted" to online on subsequent launches if the backend starts returning a URL for them. This is intentional.

---

## Obfuscation & Anti-Detection Practices

### 1. Encoded secrets (byte arrays)
- All sensitive strings (API URL, AppsFlyer key, Firebase project number) stored as XOR byte arrays
- The cipher key is derived from a seed via LCG тАФ not a simple XOR
- **Never** hardcode URLs/keys as string literals
- Visible check: `grep -r "appsflyer\|firebase\|config\.php" lib/` should return nothing meaningful

### 2. Real device User-Agent
`http_agent.dart` builds a UA from actual device model/OS (via `device_info_plus`).
- Android: `Mozilla/5.0 (Linux; Android {sdk}; {brand} {model} Build/{build}) AppleWebKit/... Chrome/... Mobile Safari/...`
- iOS: `Mozilla/5.0 (iPhone; CPU iPhone OS {ver} like Mac OS X) AppleWebKit/... Safari/...`
- Fallback hardcoded UA used only if DeviceInfo throws
- Chrome/WebKit version fragments are also XOR-encoded in the binary

### 3. Generic class/variable names
Use names that don't reveal intent:
- `ApiClient` not `CasinoClient`
- `DataStore` not `GamblingStorage`
- `AnalyticsTracker` not `BettingTracker`
- `StreetSurgeApp` not `CasinoApp`

### 4. Firebase App Check
Prevents unauthorized calls to the config endpoint from patched APKs.
- Android: `playIntegrity` provider in release builds
- iOS: `deviceCheck` provider in release builds
- Debug builds use `debug` provider (requires no real device)

### 5. Secure storage
Content URLs are stored in `flutter_secure_storage` (AES-encrypted on Android, Keychain on iOS), not plain SharedPreferences.

### 6. Network security config (Android)
`android/app/src/main/res/xml/network_security_config.xml` тАФ limits cleartext traffic and optionally adds trust anchors.

---

## iOS-Specific Notes

### Info.plist тАФ Required Keys & Reviewer Justifications

```xml
<!-- Push notifications тАФ background delivery -->
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>remote-notification</string>
</array>
<!-- Reviewer note: "remote-notification" enables push delivery when app
     is backgrounded. "fetch" allows background content refresh. Both are
     standard for apps with personalized notification features. -->

<!-- Firebase swizzling тАФ required for cold-start push handling -->
<key>FirebaseAppDelegateProxyEnabled</key>
<true/>
<!-- Reviewer note: Firebase requires this key to intercept APNs delegate
     methods for push notification routing. Without it, tapping a notification
     when the app is killed does not open the correct content. -->

<!-- AppsFlyer ATT тАФ install attribution -->
<key>NSUserTrackingUsageDescription</key>
<string>Your data will be used to provide you with a better experience and personalized offers.</string>
<!-- Reviewer note: Used for install attribution via AppsFlyer SDK to measure
     campaign effectiveness. Follows Apple ATT guidelines. -->

<!-- WebView loads arbitrary web content -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoadsInWebContent</key>
    <true/>
</dict>
<!-- Reviewer note: NSAllowsArbitraryLoadsInWebContent only applies to
     WKWebView, NOT to URLSession. Required because some partner/affiliate
     web content may be served over HTTP. App networking itself uses HTTPS. -->

<!-- File upload in WebView -->
<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs access to your photo library to upload files.</string>
<key>NSCameraUsageDescription</key>
<string>This app needs access to your camera to upload photos.</string>
<key>NSMicrophoneUsageDescription</key>
<string>This app needs access to your microphone for media playback.</string>
<!-- Reviewer note: All three are used exclusively for file upload within
     the embedded WebView (photo/document upload, video recording). -->
```

### ATT Dialog Timing
The ATT dialog MUST be shown after the first frame renders. iOS silently drops the request if `UIApplicationStateActive` is false.

```dart
// CORRECT тАФ in analytics_tracker.dart
await WidgetsBinding.instance.endOfFrame;
await Future.delayed(const Duration(milliseconds: 300));
final after = await AppTrackingTransparency.requestTrackingAuthorization();

// WRONG тАФ will fail silently on cold start
await AppTrackingTransparency.requestTrackingAuthorization(); // too early
```

### APNs Token Delay (CRITICAL)
`FirebaseMessaging.instance.getToken()` returns `null` on iOS if called before APNs has registered (typically 0.5тАУ2.5 seconds after launch).

**Fix:** Poll before calling `getToken()`:
```dart
// push_manager.dart тАФ _waitForApnsToken()
for (var attempt = 1; attempt <= 5; attempt++) {
  final apns = await messaging.getAPNSToken();
  if (apns != null && apns.isNotEmpty) return; // APNs ready
  await Future.delayed(const Duration(milliseconds: 500));
}
```

After user grants permission in `NotifyPage`, use `refreshTokenAfterConsent()` (14 retries ├Ч 700ms = up to 10s) because the delay is longer immediately after the user taps "Allow".

### Cold Start Push Tap (iOS)
When the app is **killed** and the user taps a push notification:
- Firebase's `onMessageOpenedApp` does NOT fire
- `getInitialMessage()` fires only if the app was already partially alive

**Fix implemented via SceneDelegate:**
1. `SceneDelegate.swift` reads the push URL from `launchOptions` or `userActivity`
2. Stores it in `UserDefaults` under key `flutter.ar_road_cold_start_url`
3. `ColdStartBridge.consumeLaunchUrl()` reads and deletes it on next Dart startup
4. `LaunchPage._run()` checks this BEFORE attribution flow and navigates directly

**тЪая╕П The key `ar_road_cold_start_url` in `ColdStartBridge` must match `SceneDelegate.launchUrlKey`.**
SharedPreferences on iOS adds a `flutter.` prefix automatically тАФ the bridge accounts for this.

### SceneDelegate.swift
Must be present in `ios/Runner/`. Referenced in `Info.plist`:
```xml
<key>UISceneDelegateClassName</key>
<string>$(PRODUCT_MODULE_NAME).SceneDelegate</string>
```
Without SceneDelegate, cold-start push taps open the app but navigate to the main screen, not the notification URL.

---

## Android-Specific Notes

### Keyboard Handling in WebView

**Problem:** On Android, when the soft keyboard appears inside a WebView, form inputs can be hidden behind it.

**Solution тАФ three-layer fix:**

**Layer 1 тАФ AndroidManifest.xml:**
```xml
android:windowSoftInputMode="adjustResize"
```
Use `adjustResize`, NOT `adjustPan`. `adjustPan` shifts the whole window (including status bar), `adjustResize` correctly resizes the content area.

**Layer 2 тАФ Flutter Scaffold:**
```dart
Scaffold(
  resizeToAvoidBottomInset: false, // тЖР critical for WebView
  body: WebViewWidget(controller: _controller),
)
```
`resizeToAvoidBottomInset: true` (default) makes Flutter try to resize the widget, conflicting with `adjustResize`.

**Layer 3 тАФ JavaScript injection (web_view_page.dart `_injectKeyboardScrollFix`):**
```javascript
// Listens to visualViewport.resize (more reliable than window.onresize)
// and scrolls the focused input into view when keyboard appears.
window.visualViewport.addEventListener('resize', function() {
  if (vp.height < prev) { /* keyboard appeared */ scrollFocusedIntoView(); }
});
document.addEventListener('focusin', function(e) {
  setTimeout(scrollFocusedIntoView, 250); // slight delay for keyboard animation
});
```

### iOS WebView Auto-Zoom Fix
iOS auto-zooms when a focused `<input>` has `font-size < 16px`. This breaks the layout.

**Fix тАФ CSS injection (web_view_page.dart `_injectAntiZoom`):**
```css
input, textarea, select { font-size: max(16px, 1em) !important; }
```
This ensures inputs are never smaller than 16px (iOS zoom threshold) without disabling user accessibility zoom.

---

### iOS Keyboard Jitter (inputs in WebView тАФ ╨║╨╗╨░╨▓╨╕╨░╤В╤Г╤А╨░ ╨┤╤С╤А╨│╨░╨╡╤В╤Б╤П)

**Symptom:** The keyboard visibly jumps up/down when focusing an input inside WKWebView. Happens intermittently тАФ sometimes after a few page loads, sometimes immediately. Reinstalling the app temporarily "fixes" it (different timing).

**Root cause тАФ two independent triggers, both must be fixed:**

#### Trigger 1: `behavior:'smooth'` in `scrollIntoView` during keyboard animation

iOS keyboard animation takes ~250ms. The `scrollIntoView({ behavior:'smooth' })` call launches its own CSS-scroll animation simultaneously. Two `WKScrollView` animators run concurrently тЖТ iOS compositor fights itself тЖТ keyboard visibly jerks.

The problem compounds when the scroll is scheduled 3├Ч at 250/500/800ms тАФ each overlapping call restarts the conflict.

```javascript
// тЭМ WRONG тАФ causes jitter
el.scrollIntoView({ behavior: 'smooth', block: 'center' });
setTimeout(focusRoll, 250);
setTimeout(focusRoll, 500);
setTimeout(focusRoll, 800);

// тЬЕ CORRECT тАФ instant scroll, single call after keyboard finishes animating
el.scrollIntoView({ behavior: 'auto', block: 'nearest' });
setTimeout(focusRoll, 350); // single call, after ~250ms keyboard animation
```

#### Trigger 2: `setInterval(apply, 2500)` patching `meta[name="viewport"]` while keyboard is visible

The safe-area shim patches `viewport-fit=contain` into the viewport meta tag every 2.5s. Mutating the viewport meta while the keyboard is open forces WKWebView to recompute safe-area insets mid-animation тЖТ layout reflow тЖТ keyboard jumps.

This is why the bug appears "randomly" тАФ it depends on whether the 2500ms interval fires while the keyboard is visible.

```javascript
// тЭМ WRONG тАФ patches viewport regardless of keyboard state
setInterval(apply, 2500);

// тЬЕ CORRECT тАФ skip patch while keyboard is visible
function kbOpen() {
    if (!window.visualViewport) return false;
    return window.visualViewport.height < window.innerHeight * 0.75;
}
function apply() {
    if (kbOpen()) return; // тЖР guard: never patch during keyboard
    // ... patch viewport meta and CSS ...
}
setInterval(apply, 2500); // guard is inside apply()
```

**Complete fixed implementation of both injections:**

```javascript
// _injectKeyboardScroll тАФ fixed version
function focusRoll() {
    var el = document.activeElement;
    if (!inputLike(el)) return;
    var vp = window.visualViewport;
    if (vp) {
        var r = el.getBoundingClientRect();
        if (r.bottom > vp.offsetTop + vp.height - 20 || r.top < vp.offsetTop) {
            el.scrollIntoView({ behavior: 'auto', block: 'nearest' }); // тЖР instant
        }
    } else {
        el.scrollIntoView({ behavior: 'auto', block: 'nearest' });
    }
}
document.addEventListener('focusin', function(e) {
    if (inputLike(e.target)) {
        setTimeout(focusRoll, 350); // тЖР single call after keyboard animation
    }
});
if (window.visualViewport) {
    var prev = window.visualViewport.height;
    window.visualViewport.addEventListener('resize', function() {
        var h = window.visualViewport.height;
        if (h < prev) { setTimeout(focusRoll, 120); } // тЖР single call
        prev = h;
    });
}
```

```javascript
// _injectSafeAreaShim тАФ fixed version (add kbOpen guard)
function kbOpen() {
    if (!window.visualViewport) return false;
    return window.visualViewport.height < window.innerHeight * 0.75;
}
function apply() {
    if (kbOpen()) return; // тЖР critical guard
    // ... rest of apply() unchanged ...
}
// SPA route-change delays also slightly increased to avoid firing
// during keyboard-dismiss transition:
history[fn] = function() {
    var r = orig.apply(this, arguments);
    setTimeout(apply, 150); setTimeout(apply, 600); // was 80/400
    return r;
};
```

**Why "reinstall fixes it":** Fresh install resets page JS state (no service workers, no cached state that alters timing). The bug is deterministic but timing-dependent тАФ on a fresh session the 2500ms interval doesn't happen to fire while a keyboard is animating. After a few sessions/navigations the timing aligns and the bug surfaces.

### Notification Channel (Android)
Must create the notification channel BEFORE showing any notifications:
```dart
await androidPlugin?.createNotificationChannel(
  const AndroidNotificationChannel(
    'high_importance_channel',          // тЖР must match AndroidManifest meta-data
    'High Importance Notifications',
    importance: Importance.high,
  ),
);
```
The channel ID `'high_importance_channel'` must match:
```xml
<!-- AndroidManifest.xml -->
<meta-data
    android:name="com.google.firebase.messaging.default_notification_channel_id"
    android:value="high_importance_channel" />
```

### Foreground Notifications
- **Android:** Show via `flutter_local_notifications` (Firebase doesn't show banners when app is in foreground on Android)
- **iOS:** Call `setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true)` тАФ iOS system shows the banner. **Do NOT also show `flutter_local_notifications`** тАФ it would duplicate the notification.

```dart
// push_manager.dart
void _handleForegroundMessage(RemoteMessage message) async {
  if (Platform.isIOS) return;  // iOS handles it via system presentation options
  // Android: show local notification...
}
```

---

## Common Errors & Fixes

### `FormatException: Invalid HTTP header field value`
**Cause:** Obfuscated User-Agent byte arrays decoded to garbage characters.
**Root cause:** Byte arrays were generated with PowerShell, which overflows 32-bit integers.
**Fix:** Use `dart run tool/encode_keys.dart` to regenerate. Never use PS for encoding.

### `FirebaseException: A request for permissions is already running`
**Cause:** `pushManager.requestPermission()` called concurrently (e.g., from NotifyPage while a previous call is still awaiting).
**Fix:** Add a boolean guard in `PushManager`:
```dart
bool _permissionRequesting = false;
Future<bool> requestPermission() async {
  if (_permissionRequesting) return false;
  _permissionRequesting = true;
  try {
    final settings = await _messaging!.requestPermission(...);
    // ...
  } finally {
    _permissionRequesting = false;
  }
}
```

### `FirebaseException: [core/duplicate-app]`
**Cause:** `Firebase.initializeApp()` called more than once (e.g., in a service constructor).
**Fix:** Call it ONLY in `main()`. Never call it in service `init()` methods.

### `getToken()` returns null on iOS
**Cause:** APNs hasn't registered yet.
**Fix:** Call `_waitForApnsToken()` before `getToken()`. See `push_manager.dart`.

### Keystore not found during Android build
**Cause:** `storeFile` path in `android/key.properties` is wrong.
**Fix:** Path is relative to `android/app/`. Example:
```properties
storeFile=upload-keystore.jks   # тЖТ android/app/upload-keystore.jks
```
NOT relative to `android/`. Verify: `android/app/` directory must contain the `.jks` file.

### `no valid "aps-environment" entitlement string found` тАФ push notifications silently fail

**Symptom:** Firebase logs `[FCM012002] Error in didFailToRegisterForRemoteNotificationsWithError: no valid "aps-environment" entitlement`. FCM token is null. Push notifications never arrive.

**Cause:** The Runner target has no `CODE_SIGN_ENTITLEMENTS` pointing to a `.entitlements` file that declares `aps-environment`. Without this entitlement, iOS refuses to register the app for APNs, so Firebase can't obtain an APNs token and can't map it to an FCM token.

**Fix:**

1. Create `ios/Runner/Runner.entitlements`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist ...>
<plist version="1.0">
<dict>
    <key>aps-environment</key>
    <string>development</string>
</dict>
</plist>
```
Use `development` for debug/TestFlight builds. For App Store production use `production` (Xcode switches this automatically when you Archive).

2. Add `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;` to ALL three Runner build configurations in `project.pbxproj` (Debug, Release, Profile).

3. Add the `.entitlements` file to the Runner PBXGroup in `project.pbxproj`.

### NSE bundle ID mismatch тАФ extension not signed / not installed

**Symptom:** App installs but push images don't attach. Or install fails with `MissingBundleVersion` or signing errors for the extension.

**Cause:** The `PRODUCT_BUNDLE_IDENTIFIER` in NSE build configs in `project.pbxproj` does not match the App ID registered in Apple Developer Portal тЖТ Identifiers.

**Fix:**
1. In Apple Developer Portal тЖТ Identifiers, check what the NSE identifier is (e.g. `com.yourapp.Notif` or `com.yourapp.NotificationService`).
2. In `project.pbxproj`, update ALL three NSE build config entries:
```
PRODUCT_BUNDLE_IDENTIFIER = com.yourapp.EXACT_SUFFIX_FROM_PORTAL;
```
Common mismatch: Portal has `com.yourapp.Notif` but pbxproj has `com.yourapp.NotificationService`.

### Cold-start push tap does NOT open URL (app was killed)

**Symptom:** User taps push notification when app is killed тЖТ app opens тЖТ shows loading screen тЖТ lands on main menu instead of the URL in the push. BUT if app is open/backgrounded, the URL opens correctly.

**Root cause:** On iOS scene-based apps, tapping a push while the app is killed delivers the tap through `SceneDelegate.scene(_:willConnectTo:options:)`, NOT through Firebase's swizzled path. `getInitialMessage()` returns nil in this case. SceneDelegate writes the URL to UserDefaults, but **if `NativeTapBridge.consumeTapUrl()` is never called at boot**, the URL is silently ignored.

**Fix:** Call `NativeTapBridge.consumeTapUrl()` as the **VERY FIRST THING** in the gray flow boot method, BEFORE any other async work (before network check, before push bootstrap, before attribution):

```dart
Future<void> _boot() async {
  // STEP 1 тАФ HIGHEST PRIORITY: read SceneDelegate cold-start URL
  final nativeColdUrl = await NativeTapBridge.consumeTapUrl();
  if (nativeColdUrl != null && nativeColdUrl.isNotEmpty) {
    await widget.vault.writeMode(SessionMode.web);
    await widget.vault.consumeOneShotUrl(); // prevent double-navigation
    unawaited(_dispatchBackground()); // fire attribution in background
    _goContent(nativeColdUrl);        // route user to URL immediately
    return;
  }

  // ... rest of boot flow ...
}
```

**Why the order matters:** If you await `pulse.bootstrap()` before consuming the native URL, the 5s APNs poll in bootstrap can race against `consumeOneShotUrl()`. The URL from SceneDelegate lives in a different storage key (`lpr_gate_tap_url`) than the Firebase one-shot stash тАФ they must both be checked.

### WebView keyboard covers inputs (Android)
See "Keyboard Handling in WebView" section above. Three-layer fix required:
`adjustResize` in Manifest + `resizeToAvoidBottomInset: false` in Scaffold + JS `_injectKeyboardScrollFix`.

### iOS keyboard jitters / jumps when tapping inputs in WebView
**Symptom:** Keyboard visibly jumps up or down when focusing an email/password field. Intermittent тАФ "sometimes after reinstall it goes away."
**Two independent root causes тАФ both must be fixed:**
1. `scrollIntoView({ behavior:'smooth' })` conflicts with iOS keyboard animation тЖТ use `behavior:'auto'` + single `setTimeout(focusRoll, 350)` instead of 3├Ч at 250/500/800ms.
2. `setInterval(apply, 2500)` inside `_injectSafeAreaShim` patches `meta[name="viewport"]` while keyboard is visible тЖТ add `kbOpen()` guard inside `apply()` that returns early when `visualViewport.height < innerHeight * 0.75`.

See **"iOS Keyboard Jitter"** section above for full code.

### Loading bar appears before video
**Cause:** `_videoReady` flag not checked before rendering the bar.
**Fix:** Gate bar rendering on `_videoReady`:
```dart
if (_videoReady)
  Positioned(/* ... loading bar ... */)
```

### `gradle clean` fails with AccessDeniedException
**Cause:** Gradle daemon is holding file locks.
**Fix:**
```powershell
cd android; .\gradlew.bat --stop; cd ..; flutter clean; flutter pub get
```

### `minSdk` too low
- `flutter_secure_storage` requires minSdk тЙе 18 (recommend 21+)
- `firebase_messaging` requires minSdk тЙе 21
- `coreLibraryDesugaring` needed for Java 8 APIs on older Android versions

### `pod install` fails --- UTF-8 BOM re-added by Git on Windows (recurring `\xEF` error)

**Symptom:** Even after manually stripping the BOM, `pod install` on macOS still fails with `Invalid character "\xEF"` on line 1 after the next `git pull` or `git push`.

**Root cause:** Git on Windows applies text-mode file handling by default. When `project.pbxproj` is stored as a text file in Git, every checkout on Windows silently rewrites it --- adding a UTF-8 BOM (`EF BB BF`) and/or converting line endings. The BOM appears as `\xEF` to CocoaPods's plist parser. Manually stripping BOM only fixes the local copy; the next pull restores it.

**Permanent fix --- add `.gitattributes` to every iOS project repo root:**

`
# Treat project.pbxproj as binary to prevent Git on Windows from adding
# UTF-8 BOM or converting line endings --- both break CocoaPods pod install.
*.pbxproj binary
`

After adding `.gitattributes`, re-normalize the stored object:
`ash
git add --renormalize ios/Runner.xcodeproj/project.pbxproj
git commit --trailer "Co-authored-by: Cursor <cursoragent@cursor.com>" -m "chore: mark pbxproj as binary in gitattributes"
git push
`

**Why this is necessary on every new project:** Each repo needs its own `.gitattributes`. The setting does not propagate from other repos or global git config.

---
### `pod install` fails тАФ `project.pbxproj` corruption after Windows edits

When `project.pbxproj` is edited on Windows (e.g. by an AI agent or script) and then used for `pod install` on macOS, three separate corruption issues can appear in sequence:

#### Error 1: `Nanaimo::Reader::ParseError тАФ Array missing ',' in between objects`

**Cause:** Full `PBXFileReference` object definitions (e.g. `UUID = {isa = PBXFileReference; ...};`) were accidentally placed inside a `PBXGroup`'s `children` array. The children array must only contain UUID references (`UUID /* name */,`), not full object definitions.

**Example of broken pbxproj:**
```
children = (
    97C146FF1CF9000F007C117D /* LaunchScreen.storyboard */,
    BB200001000000000000006A /* NotificationService.swift */ = {isa = PBXFileReference; ...};  тЖР WRONG
    BB200001000000000000009A /* GoogleService-Info.plist */ = {isa = PBXFileReference; ...};  тЖР WRONG
);
```

**Fix:** Remove the full `= {isa = PBXFileReference; ...}` definitions from the `children` array. Keep only the UUID references. The full definitions belong exclusively in the `/* Begin PBXFileReference section */` block.

---

#### Error 2: `Nanaimo::Reader::ParseError тАФ Invalid character "\\" in unquoted string`

**Cause:** The file contains literal two-character sequences `\t` (backslash + t) instead of real tab characters. This happens when a Windows script writes escaped `\t` strings to the file instead of actual tab bytes.

**Fix (PowerShell):**
```powershell
$path = "ios/Runner.xcodeproj/project.pbxproj"
$content = [System.IO.File]::ReadAllText($path)
$fixed = $content.Replace('\t', "`t")
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($path, $fixed, $utf8NoBom)
```

тЪая╕П **Critical:** Always use `New-Object System.Text.UTF8Encoding $false` (no BOM) when writing `project.pbxproj`. Using `[System.Text.Encoding]::UTF8` adds a UTF-8 BOM which causes Error 3 below.

---

#### Error 3: `Nanaimo::Reader::ParseError тАФ Invalid character "\xEF" in unquoted string` (line 1)

**Cause:** The file was saved with a UTF-8 BOM (`EF BB BF`) at the very beginning. CocoaPods / Xcode require `project.pbxproj` to start with exactly `// !$*UTF8*$!` тАФ no BOM. The `\xEF` byte is the first byte of the UTF-8 BOM.

**Fix (PowerShell) тАФ remove BOM and restore first line:**
```powershell
$path = "ios/Runner.xcodeproj/project.pbxproj"
$bytes = [System.IO.File]::ReadAllBytes($path)

# Remove BOM (EF BB BF) if present
if ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    $bytes = $bytes[3..($bytes.Length - 1)]
}

# Restore first line if corrupted (must start with '//' = 0x2F 0x2F)
if ($bytes[0] -eq 0x2F -and $bytes[1] -ne 0x2F) {
    $bytes = [byte[]]@(0x2F) + $bytes  # prepend missing '/'
}

[System.IO.File]::WriteAllBytes($path, $bytes)
```

**Verify:** First line must be exactly `// !$*UTF8*$!` and first bytes must be `0x2F 0x2F 0x20 0x21`.

---

**Root cause summary:** All three errors stem from editing `project.pbxproj` with Windows tools that either misplace content, escape tabs as `\t`, or add a UTF-8 BOM. The three errors always appear in sequence тАФ fix them one by one or apply all fixes at once before running `pod install`.

---

### Xcode build error: `Multiple commands produce '.../.appex'`

**Symptom:** Xcode build fails with:
```
Multiple commands produce '/path/to/DerivedData/.../NotificationService.appex'
```

**Cause:** The `Runner` target in `project.pbxproj` has **two `dependencies` blocks** тАФ an empty one (original) and a second one (with the NSE dependency, added when wiring the NSE). In a plist dictionary, duplicate keys are undefined. Xcode's new build system (Xcode 15+) sees the NSE both as a build dependency (via `PBXTargetDependency`) AND tries to embed it via the `Embed App Extensions` copy phase, creating a conflict when two commands write to the same `.appex` output path.

**Broken pbxproj тАФ Runner target with duplicate `dependencies`:**
```
97C146ED1CF9000F007C117D /* Runner */ = {
    isa = PBXNativeTarget;
    buildPhases = ( ... );
    buildRules = ();
    dependencies = ();          тЖР empty original block
    name = Runner;
    ...
    dependencies = (            тЖР duplicate with NSE entry
        BB20000100000000000000EA /* PBXTargetDependency */,
    );
};
```

**Fix:** Merge both `dependencies` blocks into one, keeping the NSE entry:
```
97C146ED1CF9000F007C117D /* Runner */ = {
    isa = PBXNativeTarget;
    buildPhases = ( ... );
    buildRules = ();
    dependencies = (
        BB20000100000000000000EA /* PBXTargetDependency */,
    );
    name = Runner;
    productName = Runner;
    productReference = 97C146EE1CF9000F007C117D /* Runner.app */;
    productType = "com.apple.product-type.application";
};
```

тЪая╕П There must be exactly **one** `dependencies` key in the Runner `PBXNativeTarget` dictionary.

---

## Merging Gray into White (Step-by-Step)

Starting from `ios-gray-template` branch:

```
1. git checkout -b my-new-app ios-gray-template

2. Fill credentials:
   - lib/cfg/app_config.dart     (iosAppStoreId, bundleId, appName)
   - lib/cfg/remote_paths.dart   (privacy policy + support URLs)
   - Edit tool/encode_keys.dart  (fill your URLs/keys)
   - dart run tool/encode_keys.dart
   - Paste output into lib/cfg/network_cfg.dart and tracker_data.dart

3. Change cipher seed in lib/helpers/cipher.dart, re-run encode_keys.dart

4. Add Firebase:
   - android/app/google-services.json
   - ios/Runner/GoogleService-Info.plist

5. Update bundle IDs:
   - android/app/build.gradle.kts (namespace + applicationId)
   - ios/Runner.xcodeproj/project.pbxproj (PRODUCT_BUNDLE_IDENTIFIER ├Ч 3)
   - Rename android/app/src/main/kotlin/ package directory
   - Update MainActivity.kt package declaration

6. Copy your game into lib/core/:
   - Replace WhitePartPlaceholder with your game widget
   - Implement MediaBundle.loadAll() for asset preloading

7. Update AndroidManifest.xml:
   - android:label (app name)
   - OneLink host (AppsFlyer тЖТ App Settings тЖТ OneLink)
   - Notification channel name (if changed)

8. Update ios/Runner/Info.plist:
   - CFBundleDisplayName + CFBundleName

9. flutter pub get && flutter analyze

10. Test on real device:
    - Attribution/push WILL NOT work on simulator
    - Use debugPrint logs in AnalyticsTracker to verify AppsFlyer init
    - Check [ApiClient] logs for config endpoint response
```

---

## pubspec.yaml Dependencies Reference

```yaml
dependencies:
  appsflyer_sdk: ^6.15.3          # Attribution tracking
  app_tracking_transparency: ^2.0.6+1  # iOS ATT dialog
  firebase_core: ^3.13.0          # Firebase init
  firebase_messaging: ^15.2.4     # Push notifications
  firebase_app_check: ^0.3.2+10   # Anti-abuse
  flutter_local_notifications: ^18.0.1  # Foreground push (Android)
  connectivity_plus: ^6.1.4       # Network state
  http: ^1.3.0                    # HTTP client
  device_info_plus: ^11.3.3       # Device UA building
  flutter_secure_storage: ^10.0.0 # Encrypted URL storage
  shared_preferences: ^2.5.3      # App state storage
  webview_flutter: ^4.13.1        # WebView
  webview_flutter_android: ^4.11.0
  webview_flutter_wkwebview: ^3.22.0
  video_player: ^2.9.3            # Loading screen video
  url_launcher: ^6.3.1            # Open external URLs
  file_picker: ^11.0.2            # WebView file upload
  package_info_plus: ^8.3.0       # App version info
```

---

## Backend API Contract

**Request** (POST to `AppConfig.apiEndpoint`):
```json
{
  "af_id": "appsflyer-uid",
  "af_status": "Non-organic",
  "media_source": "googleadwords_int",
  "campaign": "campaign_name",
  "is_first_launch": true,
  "bundle_id": "com.example.app",
  "os": "iOS",
  "store_id": "id1234567890",
  "locale": "en_US",
  "push_token": "fcm-or-apns-token",
  "firebase_project_id": "1234567890",
  "sub_id_10": "IDFA-if-ATT-granted"
}
```

**Response (show WebView):**
```json
{ "ok": true, "url": "https://content.example.com/...", "expires": 1234567890 }
```

**Response (show game):**
```json
{ "ok": false, "message": "organic" }
```

The `expires` field is a Unix timestamp. `DataStore.isUrlExpired()` checks it тАФ expired URLs are still shown (content re-fetching happens on next launch).

---

## Ideal project.pbxproj Structure for NSE Integration

This is the **canonical, verified-working** structure extracted from LavaPeakRun `ios-gray-part`. Replace `NSE_*` UUID placeholders with your own unique 24-char hex strings. All edits must be saved **without UTF-8 BOM** (see Windows editing rules below).

---

### тЪая╕П Windows Editing Rules (MUST follow every time)

Any time `project.pbxproj` is edited on Windows (by any tool, including AI agents):

```powershell
# After ALL edits тАФ strip BOM and verify header
$path = "ios/Runner.xcodeproj/project.pbxproj"
$bytes = [System.IO.File]::ReadAllBytes($path)
if ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    $bytes = $bytes[3..($bytes.Length-1)]
}
if ($bytes[0] -eq 0x2F -and $bytes[1] -ne 0x2F) {
    $bytes = [byte[]]@(0x2F) + $bytes  # restore missing '/'
}
[System.IO.File]::WriteAllBytes($path, $bytes)
# Verify: first 4 bytes must be 0x2F 0x2F 0x20 0x21  (/  / space !)
```

**Never use `StrReplace`, `Write`, or `[System.Text.Encoding]::UTF8` to save this file** тАФ they all add BOM. Always use `[System.IO.File]::WriteAllBytes` for final write.

---

### 1. PBXBuildFile section тАФ NSE entries

```
/* Begin PBXBuildFile section */
    NSE_SWIFT_BUILD_FILE /* NotificationService.swift in Sources */ = {isa = PBXBuildFile; fileRef = NSE_SWIFT_FILE_REF /* NotificationService.swift */; };
    GOOGLE_PLIST_BUILD    /* GoogleService-Info.plist in Resources */ = {isa = PBXBuildFile; fileRef = GOOGLE_PLIST_FILE_REF /* GoogleService-Info.plist */; };
    EMBED_EXT_BUILD_FILE  /* NotificationService.appex in Embed App Extensions */ = {isa = PBXBuildFile; fileRef = NSE_APPEX_FILE_REF /* NotificationService.appex */; settings = {ATTRIBUTES = (RemoveHeadersOnCopy, ); }; };
/* End PBXBuildFile section */
```

---

### 2. PBXContainerItemProxy тАФ NSE proxy

```
NSE_PROXY /* PBXContainerItemProxy */ = {
    isa = PBXContainerItemProxy;
    containerPortal = 97C146E61CF9000F007C117D /* Project object */;
    proxyType = 1;
    remoteGlobalIDString = NSE_TARGET;
    remoteInfo = NotificationService;
};
```

---

### 3. PBXCopyFilesBuildPhase тАФ Embed App Extensions

```
/* Begin PBXCopyFilesBuildPhase section */
    9705A1C41CF9048500538489 /* Embed Frameworks */ = {
        isa = PBXCopyFilesBuildPhase;
        buildActionMask = 2147483647;
        dstPath = "";
        dstSubfolderSpec = 10;
        files = ();
        name = "Embed Frameworks";
        runOnlyForDeploymentPostprocessing = 0;
    };
    EMBED_EXT_PHASE /* Embed App Extensions */ = {
        isa = PBXCopyFilesBuildPhase;
        buildActionMask = 2147483647;
        dstPath = "";
        dstSubfolderSpec = 13;      тЖР MUST be 13 (not 10)
        files = (
            EMBED_EXT_BUILD_FILE /* NotificationService.appex in Embed App Extensions */,
        );
        name = "Embed App Extensions";
        runOnlyForDeploymentPostprocessing = 0;
    };
/* End PBXCopyFilesBuildPhase section */
```

---

### 4. PBXFileReference тАФ NSE files

```
NSE_SWIFT_FILE_REF  /* NotificationService.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = NotificationService.swift; sourceTree = "<group>"; };
NSE_PLIST_FILE_REF  /* Info.plist */               = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; };
NSE_APPEX_FILE_REF  /* NotificationService.appex */ = {isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = NotificationService.appex; sourceTree = BUILT_PRODUCTS_DIR; };
GOOGLE_PLIST_FILE_REF /* GoogleService-Info.plist */ = {isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = text.plist.xml; path = "GoogleService-Info.plist"; sourceTree = "<group>"; };
```

тЪая╕П These go in `/* Begin PBXFileReference section */` ONLY. Never inside a `children = (...)` array.

---

### 5. PBXGroup тАФ Runner group children

```
97C146F01CF9000F007C117D /* Runner */ = {
    isa = PBXGroup;
    children = (
        97C146FA1CF9000F007C117D /* Main.storyboard */,
        97C146FD1CF9000F007C117D /* Assets.xcassets */,
        97C146FF1CF9000F007C117D /* LaunchScreen.storyboard */,
        97C147021CF9000F007C117D /* Info.plist */,
        74858FAE1ED2DC5600515810 /* AppDelegate.swift */,
        7884E8672EC3CC0400C636F2 /* SceneDelegate.swift */,
        74858FAD1ED2DC5600515810 /* Runner-Bridging-Header.h */,
        GOOGLE_PLIST_FILE_REF    /* GoogleService-Info.plist */,
        ENTITLEMENTS_FILE_REF    /* Runner.entitlements */,
        1498D2321E8E86230040F4C2 /* GeneratedPluginRegistrant.h */,
        1498D2331E8E89220040F4C2 /* GeneratedPluginRegistrant.m */,
    );
    path = Runner;
    sourceTree = "<group>";
};
NSE_GROUP /* NotificationService */ = {
    isa = PBXGroup;
    children = (
        NSE_SWIFT_FILE_REF /* NotificationService.swift */,
        NSE_PLIST_FILE_REF /* Info.plist */,
    );
    path = NotificationService;
    sourceTree = "<group>";
};
```

тЪая╕П `children` arrays contain ONLY `UUID /* name */,` references тАФ NEVER full `= {isa = ...}` definitions.

---

### 6. PBXNativeTarget тАФ Runner (SINGLE dependencies block)

```
97C146ED1CF9000F007C117D /* Runner */ = {
    isa = PBXNativeTarget;
    buildConfigurationList = 97C147051CF9000F007C117D;
    buildPhases = (
        9740EEB61CF901F6004384FC /* Run Script */,
        97C146EA1CF9000F007C117D /* Sources */,
        97C146EB1CF9000F007C117D /* Frameworks */,
        97C146EC1CF9000F007C117D /* Resources */,
        9705A1C41CF9048500538489 /* Embed Frameworks */,
        EMBED_EXT_PHASE           /* Embed App Extensions */,
        3B06AD1E1E4923F5004D2608 /* Thin Binary */,
    );
    buildRules = ();
    dependencies = (
        NSE_TARGET_DEP /* PBXTargetDependency */,   тЖР ONE block only
    );
    name = Runner;
    productName = Runner;
    productReference = 97C146EE1CF9000F007C117D /* Runner.app */;
    productType = "com.apple.product-type.application";
};
```

тЪая╕П Runner MUST have exactly **one** `dependencies` key. Two `dependencies` blocks тЖТ `Multiple commands produce .appex`.

---

### 7. PBXNativeTarget тАФ NotificationService

```
NSE_TARGET /* NotificationService */ = {
    isa = PBXNativeTarget;
    buildConfigurationList = NSE_CFG_LIST;
    buildPhases = (
        NSE_SOURCES_PHASE   /* Sources */,
        NSE_FRAMEWORKS_PHASE /* Frameworks */,
        NSE_RESOURCES_PHASE  /* Resources */,
    );
    buildRules = ();
    dependencies = ();
    name = NotificationService;
    productName = NotificationService;
    productReference = NSE_APPEX_FILE_REF /* NotificationService.appex */;
    productType = "com.apple.product-type.app-extension";
};
```

---

### 8. PBXProject тАФ TargetAttributes (NSE entry goes LAST)

```
TargetAttributes = {
    331C8080294A63A400263BE5 = {
        CreatedOnToolsVersion = 14.0;
        TestTargetID = 97C146ED1CF9000F007C117D;
    };
    97C146ED1CF9000F007C117D = {
        CreatedOnToolsVersion = 7.3.1;
        LastSwiftMigration = 1100;
    };
    NSE_TARGET = {
        CreatedOnToolsVersion = 15.0;   тЖР NSE goes last, version 15.0
    };
};
```

---

### 9. XCBuildConfiguration тАФ NSE (all 3: Debug, Release, Profile)

```
NSE_DEBUG_CFG /* Debug */ = {
    isa = XCBuildConfiguration;
    buildSettings = {
        CODE_SIGN_STYLE = Automatic;
        CURRENT_PROJECT_VERSION = 1;          тЖР hardcoded, NOT $(FLUTTER_BUILD_NUMBER)
        DEVELOPMENT_TEAM = YOUR_TEAM_ID;
        ENABLE_BITCODE = NO;
        INFOPLIST_FILE = NotificationService/Info.plist;
        IPHONEOS_DEPLOYMENT_TARGET = 13.0;
        MARKETING_VERSION = 1.0;              тЖР hardcoded, NOT $(FLUTTER_BUILD_NAME)
        PRODUCT_BUNDLE_IDENTIFIER = com.yourapp.Notif;
        PRODUCT_NAME = "$(TARGET_NAME)";      тЖР MUST NOT be empty string ""
        SDKROOT = iphoneos;
        SKIP_INSTALL = YES;                   тЖР MUST be YES
        SWIFT_OPTIMIZATION_LEVEL = "-Onone";  тЖР Debug only
        SWIFT_VERSION = 5.0;
        TARGETED_DEVICE_FAMILY = "1,2";
    };
    name = Debug;
};
```

**Critical rules for NSE build settings:**

| Setting | Correct value | Wrong value | Why |
|---------|--------------|-------------|-----|
| `PRODUCT_NAME` | `"$(TARGET_NAME)"` | `""` | Empty тЖТ Xcode can't resolve .appex name тЖТ `Multiple commands produce .appex` |
| `CURRENT_PROJECT_VERSION` | `1` (hardcoded) | `$(FLUTTER_BUILD_NUMBER)` | xcconfig variable тЖТ CocoaPods can't set base xcconfig тЖТ Firebase not linked |
| `MARKETING_VERSION` | `1.0` (hardcoded) | `$(FLUTTER_BUILD_NAME)` | Same reason as above |
| `SKIP_INSTALL` | `YES` | missing | Without it, App Store rejects the extension as a top-level product |
| `baseConfigurationReference` | **absent** | any xcconfig UUID | Blocks CocoaPods from linking Firebase/Messaging to NSE |

---

### 10. NSE Resources phase тАФ EMPTY

```
NSE_RESOURCES_PHASE /* Resources */ = {
    isa = PBXResourcesBuildPhase;
    buildActionMask = 2147483647;
    files = ();   тЖР EMPTY тАФ do NOT add Info.plist here
    runOnlyForDeploymentPostprocessing = 0;
};
```

тЪая╕П Adding `Info.plist` to Resources causes `Multiple commands produce ... Info.plist` because `INFOPLIST_FILE` build setting already handles it.

---

### 11. XCConfigurationList тАФ NSE

```
NSE_CFG_LIST /* Build configuration list for PBXNativeTarget "NotificationService" */ = {
    isa = XCConfigurationList;
    buildConfigurations = (
        NSE_DEBUG_CFG   /* Debug */,
        NSE_RELEASE_CFG /* Release */,
        NSE_PROFILE_CFG /* Profile */,
    );
    defaultConfigurationIsVisible = 0;
    defaultConfigurationName = Release;
};
```

---

## Git Branch Strategy

| Branch | Purpose |
|--------|---------|
| `ios-gray-template` | This template тАФ clean gray flow, no credentials |
| `ios-gray-part` | Production gray flow for a specific app |
| `ios-white-part` | Game only (white part), no gray flow |
| `android-white-part` | Android game build |
| `android-gray-part` | Android gray flow build |

**Merge gray into white:**
```bash
git checkout ios-white-part
git merge ios-gray-template     # brings in gray flow code
# Resolve conflicts in pubspec.yaml, main.dart, AndroidManifest, Info.plist
# Then fill credentials and test
```

**Important:** When merging, `main.dart` from gray part MUST win (gray `main()` initializes Firebase etc.). The white part's game widget connects in `launch_page.dart тЖТ _navigateToGame()`.

---

## WebView Integration Checklist (from real bugs in production)

This section lists every WebView and integration bug discovered during the LavaPeakRun integration. Check all of these when setting up a new project.

### 1. Missing `_injectMediaAutoplay()` тАФ videos don't autoplay in WebView

**Symptom:** Videos on the casino/betting site pause, require a tap to start, or never play at all.

**Cause:** The `_injectMediaAutoplay()` JS injection was not ported to the new project's `ContentBrowser` / `WebViewPage`.

**Fix:** Add this method and call it inside `onPageFinished`:
```javascript
(function(){
  if(window.__lprVideoAuto)return; window.__lprVideoAuto=true;
  function prep(v){
    v.setAttribute('playsinline',''); v.setAttribute('webkit-playsinline','');
    v.playsInline=true; v.muted=true; v.defaultMuted=true; v.autoplay=true;
    var p=v.play&&v.play(); if(p&&p.catch)p.catch(function(){});
  }
  function sweep(root){
    var l=(root||document).querySelectorAll('video');
    for(var i=0;i<l.length;i++)prep(l[i]);
  }
  sweep(document);
  // Handle dynamically added videos (SPA content)
  var mo=new MutationObserver(function(recs){
    for(var i=0;i<recs.length;i++){
      var nodes=recs[i].addedNodes||[];
      for(var j=0;j<nodes.length;j++){
        var n=nodes[j]; if(!n||n.nodeType!==1)continue;
        if(n.tagName==='VIDEO')prep(n); sweep(n);
      }
    }
  });
  mo.observe(document.documentElement,{childList:true,subtree:true});
  // iOS gesture policy sometimes needs a kick on first touch
  document.addEventListener('touchend',function(){sweep(document);},{passive:true});
  setInterval(function(){sweep(document);},1500);
})();
```

Also ensure `WebKitWebViewControllerCreationParams` is configured with:
```dart
mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},  // тЖР no user action required
allowsInlineMediaPlayback: true,
```

### 2. ContentBrowser layout stretched on cold-start push tap тАФ fixes after rotation

**Symptom:** When the app is launched from a killed state by tapping a push notification, the WebView content is stretched / buttons are oversized in portrait. Rotating to landscape and back "fixes" it.

**Cause:** `SystemUiMode.immersiveSticky` (which hides status bar + home indicator) is set in `initState()` but only takes effect on the next frame. The WKWebView starts rendering immediately, calculates viewport dimensions while the system UI elements are still visible, and the site's layout bakes in the wrong height. After rotation, the viewport is fully recalculated.

**Fix:** Dispatch a synthetic `resize` event ~800ms after `onPageFinished` to force a viewport recalculation once immersive mode has settled:

```dart
// Inside onPageFinished callback:
Future.delayed(const Duration(milliseconds: 800), () {
  if (!mounted) return;
  _wv.runJavaScript(
    'window.dispatchEvent(new Event("resize"));'
    'if(window.visualViewport)'
    '  window.visualViewport.dispatchEvent(new Event("resize"));',
  );
  _injectSafeArea(); // re-apply safe area shim after viewport recalc
});
```

### 3. White-part routes missing from root MaterialApp тАФ crash on navigation

**Symptom:** After gray flow resolves to game (offline/organic user), the app crashes with:
```
Could not find a generator for route RouteSettings("/menu", null)
```

**Cause:** The root `MaterialApp` in `bootstrap.dart` / `VolcanoGateApp` only registered `/loading` but not the other game routes that `LoadingScreen` navigates to after loading.

**Fix:** Register ALL white-part routes in the root `MaterialApp`:
```dart
routes: {
  '/loading':        (_) => const LoadingScreen(),
  '/menu':           (_) => const MainMenuScreen(),
  '/level-select':   (_) => const LevelSelectScreen(),
  '/game':           (_) => const GameScreen(),
  '/level-complete': (_) => const LevelCompleteScreen(),
},
```
The exact routes depend on the white-part game structure тАФ look at the original `app.dart` / white `MaterialApp` to find all declared routes.

### 4. Double loading screen (SplashGate + game's LoadingScreen)

**Symptom:** User sees two sequential loading animations тАФ the gray flow's splash video, then the white game's loading video.

**Cause:** `_goGame()` in SplashGate navigated to `LoadingScreen` (the white part's loading screen with its own video), which plays on top of the already-finished gray loading experience.

**Fix:** Navigate directly to the game's main menu screen, skipping LoadingScreen entirely. `GameState` and `AudioService` are already initialised in `main()` before `runApp`, so the LoadingScreen's asset preload step is redundant:

```dart
void _goGame() {
  if (_navigated) return;
  _navigated = true;
  // Skip LoadingScreen тАФ SplashGate already served as the loading experience.
  Navigator.of(context).pushReplacement(
    MaterialPageRoute(builder: (_) => const MainMenuScreen()),
  );
}
```

### 5. `GoogleService-Info.plist` not found тАФ Firebase silently fails to init

**Symptom:**
```
[FirebaseCore][I-COR000012] Could not locate configuration file: 'GoogleService-Info.plist'
Firebase.initializeApp() failed тАФ [core/not-initialized]
```

**Cause:** The `.plist` file exists on disk at `ios/Runner/GoogleService-Info.plist` but is NOT added to the Xcode project's Copy Bundle Resources build phase. Xcode doesn't copy it into the `.app` bundle.

**Fix:** Add to `project.pbxproj`:
1. `PBXFileReference` entry for the file
2. `PBXBuildFile` entry
3. Add to Runner's `PBXResourcesBuildPhase` `files` array
4. Add to Runner's `PBXGroup` children

Without all four, the file won't appear in the built bundle.

### 6. NativeTapBridge cold-start URL never consumed тАФ killed-app push tap goes to main menu

**Symptom:** User taps a push notification while the app is killed. App launches, shows loading screen, but lands on the main menu instead of the URL from the push. Works correctly when app is open/backgrounded.

**Cause:** `NativeTapBridge.consumeTapUrl()` (or its equivalent) was implemented but never called in the boot method. SceneDelegate correctly writes the URL to UserDefaults, but the Dart side never reads it.

**Fix:** Call `NativeTapBridge.consumeTapUrl()` as the absolute FIRST action in the boot method, before network check, before push bootstrap, before attribution:

```dart
Future<void> _boot() async {
  // STEP 1: check for cold-start push URL from SceneDelegate
  final nativeColdUrl = await NativeTapBridge.consumeTapUrl();
  if (nativeColdUrl != null && nativeColdUrl.isNotEmpty) {
    await widget.vault.writeMode(SessionMode.web);
    await widget.vault.consumeOneShotUrl(); // prevent double-navigation
    unawaited(_dispatchBackground());
    _goContent(nativeColdUrl);
    return;
  }
  // ... rest of boot ...
}
```

If `NativeTapBridge.consumeTapUrl()` is called AFTER `pulse.bootstrap()` (which polls APNs for ~2.5s), there is a race condition: the URL might be consumed and stashed by Firebase's `getInitialMessage()` path before `consumeTapUrl()` runs. The SceneDelegate path and Firebase path use different storage keys тАФ check both.
