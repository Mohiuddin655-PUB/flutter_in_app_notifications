# Setup, A to Z

Every step an app takes, in order. Each step's details are a tap away.

**1. Dependencies** ([pubspec.yaml](pubspec_setup.md)):
```yaml
in_app_notifications: ^0.17.0   # the latest version; the rest is the app's choice
```

**2. Native, once** ([Android](android_setup.md), [iOS](ios_setup.md)):
```text
Android: google-services.json; desugaring on in build.gradle.kts
iOS:     GoogleService-Info.plist; the APNs key; Push + Background Modes;
         UNUserNotificationCenter.current().delegate = self in AppDelegate
```

**3. The delegates** (copy each whole):
```dart
class FcmMessagingDelegate implements NotificationMessagingDelegate { /* the push service */ }
class LocalDisplayDelegate implements NotificationDisplayDelegate { /* the notification bar */ }
class FirestoreTokenStoreDelegate implements TokenStoreDelegate { /* where the server finds the phones */ }
class PreferencesScheduleStoreDelegate implements ScheduleStoreDelegate { /* optional: the scheduled ones */ }
```
[Messaging](app_setup.md#1-the-messaging-delegate-the-push-service) ·
[Display](app_setup.md#2-the-display-delegate-the-notification-bar) ·
[Tokens](app_setup.md#3-the-token-store-delegate-where-the-server-finds-the-phones) ·
[Schedules](app_setup.md#4-the-schedule-store-delegate-scheduled-notifications-while-open)

**4. Init, at launch, once** ([details](app_setup.md#5-init-at-launch)):
```dart
await Firebase.initializeApp();
await InAppNotifications.init(
  messaging: const FcmMessagingDelegate(background: PushBackground.pushed), // a push while the app is in the background
  display: const LocalDisplayDelegate(systemWhileOpen: false),
  tokens: FirestoreTokenStoreDelegate(prefs),
  whileOpen: WhileOpen.inApp,     // while the app is open: bar | inApp | inAppOnly
);
```

**5. With the account** ([details](app_setup.md#6-with-the-account)):
```dart
InAppNotifications.start(uid);        // after sign-in
await InAppNotifications.clear();     // before sign-out
```

**6. The permission** ([details](app_setup.md#7-the-permission)):
```dart
await FirebaseMessaging.instance.requestPermission();
```

**7. Shown inside the app while it is open** ([details](app_setup.md#8-shown-inside-the-app)):
```dart
ValueListenableBuilder(                     // where the app shows its overlays
  valueListenable: InAppNotifications.inApp,
  builder: (_, m, _) => m == null ? const SizedBox.shrink()
      : InAppNotificationView(message: m, onOpen: InAppNotifications.open, onDismiss: InAppNotifications.dismiss),
);
```

**8. Sending one** ([details](app_setup.md#9-sending-one)):
```dart
await InAppNotifications.notify(id: 'streak', title: 'Keep your streak');   // on the phone, now or later (after:, at:)
InAppNotifications.show(title: 'Saved');                                     // only inside the app
```

**9. A tap opens its page** ([details](app_setup.md#10-a-tap-opens-its-page)):
```dart
InAppNotifications.opened.addListener(() => openPage(InAppNotifications.take()));
```

**10. Actions and replies** ([details](app_setup.md#11-actions-and-replies)):
```dart
InAppNotifications.actions.listen((a) => handle(a.actionId, a.input));
```

**11. Its own look** ([details](app_setup.md#12-its-own-look)):
```dart
InAppNotificationView(message: m, onOpen: ..., onDismiss: ..., style: InAppNotificationStyle(...));
```

**12. Check it works** ([details](app_setup.md#13-check-it-works)):
```dart
await InAppNotifications.notify(id: 'test', title: 'Local works'); // then a test push from the Firebase console
```
