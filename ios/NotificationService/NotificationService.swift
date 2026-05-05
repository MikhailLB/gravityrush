import UserNotifications

#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

/// Notification Service Extension that lets iOS render rich (image-attached)
/// pushes regardless of the host app state (foreground / background / killed).
///
/// Without this extension iOS ignores `notification.image` (or
/// `apns.fcm_options.image`) for our FCM payloads. By calling
/// `Messaging.serviceExtension().populateNotificationContent` we hand decoding
/// off to FirebaseMessaging, which downloads the image and attaches it to the
/// system-displayed notification automatically.
///
/// IMPORTANT: APS payload sent from the backend MUST contain
/// `"mutable-content": 1` — otherwise iOS will not invoke this extension and
/// the picture stays invisible.
class NotificationService: UNNotificationServiceExtension {
  var contentHandler: ((UNNotificationContent) -> Void)?
  var bestAttemptContent: UNMutableNotificationContent?

  override func didReceive(
    _ request: UNNotificationRequest,
    withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
  ) {
    self.contentHandler = contentHandler
    bestAttemptContent =
      request.content.mutableCopy() as? UNMutableNotificationContent

    guard let bestAttemptContent = bestAttemptContent else {
      contentHandler(request.content)
      return
    }

    #if canImport(FirebaseMessaging)
    Messaging.serviceExtension().populateNotificationContent(
      bestAttemptContent,
      withContentHandler: contentHandler
    )
    #else
    contentHandler(bestAttemptContent)
    #endif
  }

  override func serviceExtensionTimeWillExpire() {
    if let contentHandler = contentHandler,
       let bestAttemptContent = bestAttemptContent {
      contentHandler(bestAttemptContent)
    }
  }
}
