import UserNotifications

#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

/// NSE — attaches rich media images to FCM pushes before iOS displays them.
/// APS payload MUST include `"mutable-content": 1` to invoke this extension.
class NotificationService: UNNotificationServiceExtension {
  var contentHandler: ((UNNotificationContent) -> Void)?
  var bestAttemptContent: UNMutableNotificationContent?

  override func didReceive(
    _ request: UNNotificationRequest,
    withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
  ) {
    self.contentHandler = contentHandler
    bestAttemptContent = request.content.mutableCopy() as? UNMutableNotificationContent
    guard let bestAttemptContent = bestAttemptContent else {
      contentHandler(request.content); return
    }
    #if canImport(FirebaseMessaging)
    Messaging.serviceExtension().populateNotificationContent(
      bestAttemptContent, withContentHandler: contentHandler)
    #else
    contentHandler(bestAttemptContent)
    #endif
  }

  override func serviceExtensionTimeWillExpire() {
    if let c = contentHandler, let b = bestAttemptContent { c(b) }
  }
}
