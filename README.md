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

InAppNotifications.opened.addListener(() {
  final data = InAppNotifications.take(); // {'page': 'chats', ...}
});
```

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
