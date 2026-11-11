# Setup, A to Z

Every step an app takes, in order. Each step's details are a tap away.

**1. Dependencies** ([pubspec.yaml](pubspec_setup.md)):
```yaml
in_app_notifications: ^0.17.0   # the latest version; the rest is the app's choice
```

**2. Native, once** ([android_setup.md](android_setup.md), [ios_setup.md](ios_setup.md)):
```kotlin
// Android: google-services.json in android/app/, then in android/app/build.gradle.kts:
android { compileOptions { isCoreLibraryDesugaringEnabled = true } }
dependencies { coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5") }
```
```swift
// iOS: GoogleService-Info.plist in ios/Runner/, the APNs key in the Firebase console,
// Xcode: Push Notifications + Background Modes › Remote notifications, then in AppDelegate.swift:
UNUserNotificationCenter.current().delegate = self
```

**3. The delegates** (copy each whole):
```dart
class FcmMessagingDelegate implements NotificationMessagingDelegate { /* the push service */ }
class LocalDisplayDelegate implements NotificationDisplayDelegate { /* the notification bar */ }
class FirestoreTokenStoreDelegate implements TokenStoreDelegate { /* where the server finds the phones */ }
class PreferencesScheduleStoreDelegate implements ScheduleStoreDelegate { /* optional: the scheduled ones */ }
```
[Messaging](../push_example/lib/fcm_messaging_delegate.dart) ·
[Display](../push_example/lib/local_display_delegate.dart) ·
[Tokens](../push_example/lib/firestore_token_store_delegate.dart) ·
[Schedules](../push_example/lib/preferences_schedule_store_delegate.dart)

**4. Init, at launch, once** ([details](../push_example/lib/push_setup.dart)):
```dart
await Firebase.initializeApp();
await InAppNotifications.init(
  messaging: const FcmMessagingDelegate(background: PushBackground.pushed), // a push while the app is in the background
  display: const LocalDisplayDelegate(systemWhileOpen: true),  // true with bar
  tokens: FirestoreTokenStoreDelegate(prefs),
  whileOpen: WhileOpen.bar,  // while the app is open: bar (the default) | inAppAndBar | inAppOnly
);
```

**5. With the account**:
```dart
InAppNotifications.start(uid);        // after sign-in, and at a launch still signed in: keeps the token on the account
await InAppNotifications.clear();     // before sign-out and before deleting the account: takes it away
```

**6. The permission** ([permission_setup.md](permission_setup.md)): only the notification permission (Android 13+ and iOS); without it nothing shows in the notification bar.
```dart
await FirebaseMessaging.instance.requestPermission();  // recommended; or another way (permission_setup.md)
```

**7. Shown inside the app while it is open, optional** ([in_app_notification_setup.md](in_app_notification_setup.md)): needed only with `WhileOpen.inAppAndBar`, `WhileOpen.inAppOnly` or `show()`.
```dart
MaterialApp(builder: (context, child) => InAppNotificationHost(builder: (context, data) => MyNotification(data), child: child!));
```

**8. Sending one** ([details](usage.md#1-sending-one); to another phone: [server](server_setup.md)):
```dart
await InAppNotifications.notify(id: 'streak', title: 'Keep your streak');   // on the phone, now or later (after:, at:)
InAppNotifications.show(title: 'Saved');                                     // only inside the app
```

**9. A tap opens its page** ([details](usage.md#2-a-tap-opens-its-page)):
```dart
InAppNotifications.opened.addListener(() => openPage(InAppNotifications.take()));
```

**10. Actions and replies** ([details](usage.md#3-actions-and-replies)):
```dart
InAppNotifications.actions.listen((a) => handle(a.actionId, a.input));
```

**11. Check it works** ([details](usage.md#4-check-it-works)):
```dart
await InAppNotifications.notify(id: 'test', title: 'Local works'); // then a test push from the Firebase console
```
