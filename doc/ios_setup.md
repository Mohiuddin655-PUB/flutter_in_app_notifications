# iOS setup

What an iOS app needs for `in_app_notifications` with Firebase Cloud Messaging and `flutter_local_notifications`
(see [app_setup.md](app_setup.md) for the Dart side).

## 1. Apple and Firebase

- In Apple Developer › Keys, make an **APNs authentication key** (`.p8`) and upload it in the Firebase console ›
  Project settings › Cloud Messaging › your iOS app, with its Key ID and Team ID. One key covers development and
  production. Without it FCM accepts a message and Apple never delivers it.
- Add the iOS app in Firebase and put `GoogleService-Info.plist` in `ios/Runner/` (or use `flutterfire configure`).

## 2. Xcode (Runner target › Signing & Capabilities)

- **Push Notifications**: adds `aps-environment` to the entitlements: `development` for debug builds, `production` for
  release (keep one entitlements file per configuration if you have two).
- **Background Modes › Remote notifications**: in `Info.plist`,

```xml
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>
```

## 3. `ios/Runner/AppDelegate.swift`

Firebase Messaging and flutter_local_notifications both work through `UNUserNotificationCenter`'s delegate; the
Flutter app delegate passes its calls on to them:

```swift
override func application(_ application: UIApplication,
                          didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
}
```

While the app is open, iOS asks how each notification shows. The Flutter app delegate asks every plugin and **the first
answer wins**, and Firebase Messaging answers for every notification, the app's own included, with the options set for
pushes. With `inApp` (alert off) a notification the app made itself (`InAppNotifications.notify`, now or scheduled)
would then show nowhere: no banner, not even in the list. Answer for those in the AppDelegate and leave pushes to
Firebase:

```swift
override func userNotificationCenter(_ center: UNUserNotificationCenter,
                                     willPresent notification: UNNotification,
                                     withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    if notification.request.content.userInfo["gcm.message_id"] == nil { // made on the phone
        completionHandler([.banner, .list, .sound, .badge])
        return
    }
    super.userNotificationCenter(center, willPresent: notification, withCompletionHandler: completionHandler)
}
```

- A push then shows while open as `setForegroundNotificationPresentationOptions` says (alert off with `inApp`, so it
  shows once, as the app's banner).
- Don't add a plugin that takes the delegate for **every** notification (such as `awesome_notifications`): it shows the
  system banner over the app's own banner, whatever the options say.
- Don't let flutter_local_notifications ask for the permission (`DarwinInitializationSettings(request...Permission:
  false)`): the app asks when it is needed (app_setup.md step 6).

## 4. How iOS behaves (for testing)

- The FCM token waits for Apple's (APNs) token, which can take a moment after launch: `token()` gives up after a few
  tries and the refresh stream brings it later.
- A push while open is shown by iOS itself (with `alert: true`), or only by the app (`inApp`, `alert: false`).
- **Simulator**: a real FCM push needs Xcode 14+, macOS 13+ and the APNs key above. Without them, send one straight to
  the simulator; `gcm.message_id` makes Firebase Messaging treat it as its own:

```sh
cat > push.json <<'JSON'
{"Simulator Target Bundle": "com.example.app",
 "aps": {"alert": {"title": "Hello", "body": "Opens chats"}},
 "gcm.message_id": "test-1", "page": "chats"}
JSON
xcrun simctl push booted com.example.app push.json
```

- "Source is not authorized" from `simctl push` means the app hasn't been allowed notifications yet.
- Background: open another app (`xcrun simctl launch booted com.apple.Preferences`); closed:
  `xcrun simctl terminate booted <bundle id>`.
