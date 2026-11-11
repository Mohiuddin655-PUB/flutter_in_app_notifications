# iOS setup

## 1. Apple and Firebase

- In Apple Developer › Keys (<https://developer.apple.com/account/resources/authkeys/list>), make an **APNs authentication key** (`.p8`), and upload it in the Firebase console (<https://console.firebase.google.com>) ›
  Project settings › Cloud Messaging, with its Key ID and Team ID.
- Add the iOS app in the Firebase console (<https://console.firebase.google.com>) and put `GoogleService-Info.plist` in `ios/Runner/` (or run `flutterfire configure`).

## 2. Xcode (Runner target › Signing & Capabilities)

- Add **Push Notifications**.
- Add **Background Modes › Remote notifications**.

## 3. `ios/Runner/AppDelegate.swift`

```swift
override func application(_ application: UIApplication,
                          didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    ...
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
}
```

Don't add a plugin that takes every notification for itself (such as `awesome_notifications`).

## 4. A push's image (optional)

1. Xcode › File › New › Target › **Notification Service Extension**, named `NotificationService`. Its
   `NotificationService.swift`:

```swift
import InAppNotificationsService

class NotificationService: InAppNotificationService {}
```

2. In `ios/Podfile`, outside the Runner target:

```ruby
...

target 'NotificationService' do
  use_frameworks!
  pod 'InAppNotificationsService', :path => '.symlinks/plugins/in_app_notifications/ios'
end
```

3. In Runner › Build Phases, move **Embed Foundation Extensions** above **Thin Binary**.

The push carries `mutable-content: 1` and its image in the data (`image`).
