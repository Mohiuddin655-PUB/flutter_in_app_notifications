# in_app_notifications

Push notifications for any push service and backend: the phone's **token** kept on the signed-in account, a push
**shown while the app is open**, and the **page a tapped push opens**. It has no dependencies: the app gives the push
service, the display and the storage through three small delegates.

```dart
InAppNotifications.setup(
  messaging: FcmMessaging(),          // NotificationMessagingDelegate: Firebase Cloud Messaging, say
  display: LocalDisplay(),            // NotificationDisplayDelegate: a local notifications plugin, say
  tokens: FirestoreTokens(),          // TokenStoreDelegate: accounts/{uid}/devices/{token}, say
  onError: (error, stack, where) => crashlytics.recordError(error, stack, reason: where),
  unreachable: (error) => error is TimeoutException,
);
await InAppNotifications.init();      // at launch
InAppNotifications.start(uid);        // at sign-in, or a launch still signed in
await InAppNotifications.clear();     // before sign-out, while the account can still write

// With visibility: LocalNotificationVisibility.inApp, a push while the app is open shows inside it:
MaterialApp(
  builder: (context, child) => InAppNotificationGate(
    builder: (context, message, onOpen, onDismiss) => MyBanner(message, onTap: onOpen, onSwipe: onDismiss),
    transitionBuilder: (child, animation) => SlideTransition(
      position: Tween(begin: const Offset(0, -1), end: Offset.zero).animate(animation),
      child: child,
    ),
    child: child!,
  ),
);

// A notification made on the phone: now, or scheduled.
await InAppNotifications.notify(id: 'streak', title: 'Keep your streak', data: {'page': 'home'});
await InAppNotifications.notify(id: 'reminder', title: 'See who liked you', at: tomorrowAtNine, data: {'page': 'likes'});
await InAppNotifications.cancel('reminder');

InAppNotifications.opened.addListener(() {
  final data = InAppNotifications.take(); // {'page': 'chats', ...}
});
```

## Setup

1. [App setup](doc/app_setup.md): the dependencies, the three delegates (FCM, flutter_local_notifications, Firestore),
   `setup`, `start` and `clear`, the permission, opening the right page, the in-app banner, and notifications made on
   the phone.
2. [Android setup](doc/android_setup.md): Firebase, desugaring, the manifest (permissions, the scheduled-notification
   receivers, the default channel and icon), and how Android behaves when testing.
3. [iOS setup](doc/ios_setup.md): the APNs key in Firebase, Push Notifications and Background Modes, the AppDelegate,
   which plugins not to add, and testing on a simulator.

### Native checklist

The Dart side needs nothing native; the plugins the app picks do. With FCM and flutter_local_notifications:

**Android**

| File | What |
| --- | --- |
| `android/app/google-services.json` | the app's Firebase config |
| `android/app/build.gradle.kts` | `isCoreLibraryDesugaringEnabled = true` and `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")` |
| `AndroidManifest.xml` | `POST_NOTIFICATIONS` and `RECEIVE_BOOT_COMPLETED` permissions |
| `AndroidManifest.xml` | the `ScheduledNotificationReceiver` and `ScheduledNotificationBootReceiver` receivers (scheduled notifications) |
| `AndroidManifest.xml` | FCM's `default_notification_channel_id`, `default_notification_icon`, `default_notification_color` |
| `res/drawable*/ic_stat.png` | a white-on-transparent small icon; `res/values/colors.xml` its colour |

**iOS**

| Where | What |
| --- | --- |
| Firebase console › Cloud Messaging | the APNs authentication key (`.p8`), Key ID and Team ID |
| `ios/Runner/GoogleService-Info.plist` | the app's Firebase config |
| Xcode › Signing & Capabilities | Push Notifications (`aps-environment`: development / production) |
| `ios/Runner/Info.plist` | `UIBackgroundModes` › `remote-notification` |
| `ios/Runner/AppDelegate.swift` | `UNUserNotificationCenter.current().delegate = self` before `super.application(...)` |
| Pubspec | no plugin that takes the notification delegate for every notification (`awesome_notifications`) |

Each line is explained in the platform guide.

## How it works

- **Token**: asked at `start`, saved through `TokenStoreDelegate.save` only when it differs from the copy last saved on
  the phone (`saved` / `remember`), so a launch writes nothing. A refreshed token is saved and the old one removed.
  `clear` removes it from the account and lets it go (`forgetToken`), so pushes to it stop even when the removal
  couldn't reach the server; it also drops a tapped push not yet taken and every push still shown
  (`NotificationDisplayDelegate.clearShown`), so none opens a page for the next account.
- **Shown while open**: each push from `NotificationMessagingDelegate.received` with a title or a body goes to
  `NotificationDisplayDelegate.show` (which does nothing where the platform shows it itself, as iOS does).
- **Inside the app instead**: with `setup(visibility: LocalNotificationVisibility.inApp)`, such a push goes to
  `InAppNotifications.inApp` (the newest replaces the one before) and not to the notification bar; the app shows it
  (a banner at its top, say) and calls `open()` when it is tapped or `dismiss()` when it goes. In the background or
  closed, the system shows it in the notification bar either way.
- **Tapped**: a push tapped in the background (`NotificationMessagingDelegate.tapped`), one that started the app (`initial`), and
  one shown while open (`NotificationDisplayDelegate.tapped` / `initial`) all put their data in `opened`, which waits until the app
  is ready to `take` it.
- **Errors**: every delegate call is caught; `onError` gets it unless `unreachable` says it was only offline.

## Server side

Send to the tokens kept on the account, with the data your app reads in `opened` (a page, an id). A token the push
service says is no longer registered can be deleted there.
