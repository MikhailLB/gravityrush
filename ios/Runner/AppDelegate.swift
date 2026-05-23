import FirebaseMessaging
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Register plugins eagerly so Firebase Messaging swizzle installs before any push tap.
    GeneratedPluginRegistrant.register(with: self)
    // Explicit APNs registration refreshes the FCM→APNs mapping on every launch.
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
