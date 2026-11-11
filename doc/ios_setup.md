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

Make the app delegate the notification center's delegate, so taps reach Firebase Messaging and
flutter_local_notifications (the Flutter app delegate passes the calls on to the plugins):

```swift
override func application(_ application: UIApplication,
                          didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
}
```

Nothing else: the package's plugin then puts itself in front and answers how a notification shows while the app is
open. The Flutter app delegate asks every plugin and the first answer wins, and Firebase Messaging answers for every
notification with the options set for pushes, which with `inApp` would hide a notification the app made itself
completely. The plugin answers instead:

- a push (it carries `gcm.message_id`): as `setForegroundNotificationPresentationOptions` says; with the in-app
  notification off (the app shows its own) it still goes into the list, quietly;
- a notification made on the phone: as flutter_local_notifications asks for it (`notify(quiet:)` puts it into the list
  only).

Everything else (a tap, the settings link) goes on to the app delegate.

- Don't add a plugin that takes the delegate for **every** notification (such as `awesome_notifications`).
- Don't let flutter_local_notifications ask for the permission (`DarwinInitializationSettings(request...Permission:
  false)`): the app asks when it is needed ([app_setup.md](app_setup.md#7-the-permission)).

## 4. A push's image (Notification Service Extension)

iOS shows a push's image only through a Notification Service Extension, a target of the app's own that no package can
add. The package does its work; the app keeps only:

1. Xcode › File › New › Target › Notification Service Extension, named `NotificationService` (bundle id
   `<app id>.NotificationService`, the app's deployment target and team). Its `NotificationService.swift` becomes:

```swift
import InAppNotificationsService

class NotificationService: InAppNotificationService {}
```

2. In `ios/Podfile`, outside the Runner target:

```ruby
target 'NotificationService' do
  use_frameworks!
  pod 'InAppNotificationsService', :path => '.symlinks/plugins/in_app_notifications/ios'
end
```

3. In Runner's Build Phases, move **Embed Foundation Extensions** above **Thin Binary** (Flutter's script), or the
   build stops with a cycle.

The push then carries `mutable-content: 1` (`apns.payload.aps.mutable-content`) and its image in the data (`image`) or
in FCM's `apns.fcm_options.image`.

## 5. How iOS behaves (for testing)

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
