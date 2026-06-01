import Flutter
import UIKit
import UserNotifications

/// Scene-based apps deliver cold-start push taps through
/// `scene(_:willConnectTo:options:)` — NOT through AppDelegate launchOptions.
/// Firebase's getInitialMessage() returns nil for these taps on scene-based apps.
///
/// We capture the URL here and store it in UserDefaults under
/// `flutter.bb2_gate_cold_url`. The `flutter.` prefix lets SharedPreferences
/// read it via BallTapBridge.consumeTapUrl() with no MethodChannel needed.
class SceneDelegate: FlutterSceneDelegate {
  static let coldUrlKey = "flutter.bb2_gate_cold_url"

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    if let response = connectionOptions.notificationResponse,
       let url = SceneDelegate.extractUrl(from: response.notification.request.content.userInfo) {
      SceneDelegate.persist(url: url)
    }
  }

  override func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    super.scene(scene, continue: userActivity)
  }

  static func extractUrl(from userInfo: [AnyHashable: Any]) -> String? {
    let keys = ["url", "link", "target", "deeplink", "deep_link"]
    func scan(_ map: [AnyHashable: Any]) -> String? {
      for key in keys {
        if let raw = map[key] as? String,
           !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          return raw.trimmingCharacters(in: .whitespacesAndNewlines)
        }
      }
      return nil
    }
    if let direct = scan(userInfo) { return direct }
    if let nested = userInfo["data"] as? [AnyHashable: Any], let url = scan(nested) { return url }
    if let nested = userInfo["payload"] as? [AnyHashable: Any], let url = scan(nested) { return url }
    return nil
  }

  static func persist(url: String) {
    let d = UserDefaults.standard
    d.set(url, forKey: coldUrlKey)
    d.synchronize()
  }
}
