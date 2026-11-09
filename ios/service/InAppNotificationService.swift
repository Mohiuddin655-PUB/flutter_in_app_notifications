import UserNotifications

/// A push's image for in_app_notifications: iOS hands a push with `mutable-content: 1` to the app's Notification Service
/// Extension before showing it, and this downloads the image named in its data (`image`, as NotificationKeys, or FCM's
/// own `fcm_options.image`) and attaches it. Anything that fails shows the push as it came. The app's extension is just
/// `class NotificationService: InAppNotificationService {}`.
open class InAppNotificationService: UNNotificationServiceExtension {
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var content: UNMutableNotificationContent?

    open override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        guard let content = request.content.mutableCopy() as? UNMutableNotificationContent else {
            contentHandler(request.content)
            return
        }
        self.content = content
        let info = content.userInfo
        let fcm = (info["fcm_options"] as? [String: Any])?["image"] as? String
        guard let address = (info["image"] as? String) ?? fcm, let url = URL(string: address) else {
            contentHandler(content)
            return
        }
        URLSession.shared.downloadTask(with: url) { location, response, _ in
            defer { contentHandler(content) }
            guard let location = location else { return }
            let suggested = response?.suggestedFilename ?? url.lastPathComponent
            let file = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent(UUID().uuidString + "-" + (suggested.isEmpty ? "image.jpg" : suggested))
            do {
                try FileManager.default.moveItem(at: location, to: file)
                content.attachments = [try UNNotificationAttachment(identifier: "image", url: file)]
            } catch {}
        }.resume()
    }

    /// Out of time: the push shows as it came, without its image.
    open override func serviceExtensionTimeWillExpire() {
        if let contentHandler = contentHandler, let content = content { contentHandler(content) }
    }
}
