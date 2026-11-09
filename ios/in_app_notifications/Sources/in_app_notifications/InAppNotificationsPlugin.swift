import Flutter
import UIKit
import UserNotifications

/// How a notification shows while the app is open. iOS asks the notification center's delegate; the Flutter app
/// delegate asks every plugin and the first answer wins, and Firebase Messaging answers for every notification with the
/// options set for pushes. So this plugin becomes the delegate and answers itself:
/// - a push (it carries `gcm.message_id`): as Firebase's options say; when they leave the banner off (the app shows its
///   own, `LocalNotificationVisibility.inApp`), it still goes into the list, quietly;
/// - a notification the app made itself (flutter_local_notifications): as it asks (`presentBanner`, `presentList`,
///   `presentSound`, `presentBadge`), so one the app also shows inside itself goes into the list quietly.
/// Everything else (a tap, the settings link) goes on to the delegate that was there before (the app delegate).
public class InAppNotificationsPlugin: NSObject, FlutterPlugin, UNUserNotificationCenterDelegate {
    private static let shared = InAppNotificationsPlugin()

    /// The delegate before this one: the Flutter app delegate, which hands the calls to the plugins.
    private weak var previous: UNUserNotificationCenterDelegate?

    /// Where Firebase Messaging keeps `setForegroundNotificationPresentationOptions`.
    private static let firebaseOptions = "flutter_firebase_messaging_presentation_options"

    public static func register(with registrar: FlutterPluginRegistrar) {
        let center = UNUserNotificationCenter.current()
        guard center.delegate !== shared else { return }
        shared.previous = center.delegate
        center.delegate = shared
    }

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let info = notification.request.content.userInfo
        if info["gcm.message_id"] != nil {
            let firebase = UserDefaults.standard.dictionary(forKey: Self.firebaseOptions)
            if (firebase?["alert"] as? Bool) == true, let previous = previous,
               previous.responds(to: #selector(UNUserNotificationCenterDelegate.userNotificationCenter(_:willPresent:withCompletionHandler:))) {
                previous.userNotificationCenter?(center, willPresent: notification, withCompletionHandler: completionHandler)
            } else if (firebase?["alert"] as? Bool) == true {
                completionHandler([.banner, .list, .sound, .badge])
            } else {
                completionHandler([.list, .badge])
            }
            return
        }
        var options: UNNotificationPresentationOptions = []
        if (info["presentBanner"] as? Bool) ?? true { options.insert(.banner) }
        if (info["presentList"] as? Bool) ?? true { options.insert(.list) }
        if (info["presentSound"] as? Bool) ?? true { options.insert(.sound) }
        if (info["presentBadge"] as? Bool) ?? true { options.insert(.badge) }
        completionHandler(options)
    }

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        guard let previous = previous,
              previous.responds(to: #selector(UNUserNotificationCenterDelegate.userNotificationCenter(_:didReceive:withCompletionHandler:)))
        else {
            completionHandler()
            return
        }
        previous.userNotificationCenter?(center, didReceive: response, withCompletionHandler: completionHandler)
    }

    public func userNotificationCenter(_ center: UNUserNotificationCenter, openSettingsFor notification: UNNotification?) {
        previous?.userNotificationCenter?(center, openSettingsFor: notification)
    }
}
