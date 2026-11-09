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

    private var channel: FlutterMethodChannel?

    /// Actions answered on a push before Dart was listening (the app started by one): handed over by `takeActions`.
    private var pending: [[String: Any]] = []
    private var listening = false

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "in_app_notifications", binaryMessenger: registrar.messenger())
        shared.channel = channel
        registrar.addMethodCallDelegate(shared, channel: channel)
        let center = UNUserNotificationCenter.current()
        guard center.delegate !== shared else { return }
        shared.previous = center.delegate
        center.delegate = shared
    }

    /// `removePush(id)`: a push (by its `gcm.message_id`) taken out of Notification Center, once the app has shown it
    /// and it was tapped. iOS shows a push itself, under an id of its own, so the display can't take it away.
    /// `takeActions()`: the actions answered on a push so far, and from now on each one as `action` calls.
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "takeActions" {
            listening = true
            result(pending)
            pending.removeAll()
            return
        }
        guard call.method == "removePush", let id = (call.arguments as? [String: Any])?["id"] as? String else {
            result(FlutterMethodNotImplemented)
            return
        }
        let center = UNUserNotificationCenter.current()
        center.getDeliveredNotifications { delivered in
            let ids = delivered
                .filter { ($0.request.content.userInfo["gcm.message_id"] as? String) == id }
                .map { $0.request.identifier }
            center.removeDeliveredNotifications(withIdentifiers: ids)
            DispatchQueue.main.async { result(ids.count) }
        }
    }

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // The plugins still hear of it (Firebase Messaging tells the app of a push from here: onMessage); their answer
        // is set aside, and this one is given.
        if let previous = previous,
           previous.responds(to: #selector(UNUserNotificationCenterDelegate.userNotificationCenter(_:willPresent:withCompletionHandler:))) {
            previous.userNotificationCenter?(center, willPresent: notification) { _ in }
        }
        completionHandler(Self.options(for: notification.request.content.userInfo))
    }

    private static func options(for info: [AnyHashable: Any]) -> UNNotificationPresentationOptions {
        var options: UNNotificationPresentationOptions = []
        if info["gcm.message_id"] != nil {
            let firebase = UserDefaults.standard.dictionary(forKey: firebaseOptions)
            let alert = (firebase?["alert"] as? Bool) == true
            options.insert(.list)
            if alert { options.insert(.banner) }
            if alert, (firebase?["sound"] as? Bool) == true { options.insert(.sound) }
            if (firebase?["badge"] as? Bool) == true { options.insert(.badge) }
            return options
        }
        if (info["presentBanner"] as? Bool) ?? true { options.insert(.banner) }
        if (info["presentList"] as? Bool) ?? true { options.insert(.list) }
        if (info["presentSound"] as? Bool) ?? true { options.insert(.sound) }
        if (info["presentBadge"] as? Bool) ?? true { options.insert(.badge) }
        return options
    }

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // An action on a push (Reply, Accept): Firebase Messaging only tells of a tap, so it is told here. A plain tap
        // and the app's own notifications (flutter_local_notifications) go on as before.
        let info = response.notification.request.content.userInfo
        let action = response.actionIdentifier
        if info["gcm.message_id"] != nil,
           action != UNNotificationDefaultActionIdentifier, action != UNNotificationDismissActionIdentifier {
            var data: [String: String] = [:]
            for (key, value) in info {
                guard let key = key as? String, key != "aps" else { continue }
                data[key] = "\(value)"
            }
            var answer: [String: Any] = ["id": info["gcm.message_id"] as? String ?? "", "actionId": action, "data": data]
            if let text = (response as? UNTextInputNotificationResponse)?.userText { answer["input"] = text }
            if listening, let channel = channel {
                channel.invokeMethod("action", arguments: answer)
            } else {
                pending.append(answer)
            }
            completionHandler()
            return
        }
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
