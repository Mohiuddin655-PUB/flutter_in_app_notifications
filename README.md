# in_app_notifications

Push notifications for any push service and backend: the phone's **token** kept on the signed-in account, a push
**shown while the app is open**, and the **page a tapped push opens**. It has no dependencies: the app gives the push
service, the display and the storage through three small delegates.

```dart
InAppNotifications.setup(
  messaging: FcmMessaging(),          // MessagingDelegate: Firebase Cloud Messaging, say
  display: LocalDisplay(),            // DisplayDelegate: a local notifications plugin, say
  tokens: FirestoreTokens(),          // TokenStoreDelegate: accounts/{uid}/devices/{token}, say
  onError: (error, stack, where) => crashlytics.recordError(error, stack, reason: where),
  unreachable: (error) => error is TimeoutException,
);
await InAppNotifications.init();      // at launch
InAppNotifications.start(uid);        // at sign-in, or a launch still signed in
await InAppNotifications.clear();     // before sign-out, while the account can still write

InAppNotifications.opened.addListener(() {
  final data = InAppNotifications.take(); // {'page': 'chats', ...}
});
```

## How it works

- **Token**: asked at `start`, saved through `TokenStoreDelegate.save` only when it differs from the copy last saved on
  the phone (`saved` / `remember`), so a launch writes nothing. A refreshed token is saved and the old one removed.
  `clear` removes it from the account and lets it go (`forgetToken`), so pushes to it stop even when the removal
  couldn't reach the server.
- **Shown while open**: each push from `MessagingDelegate.received` with a title or a body goes to
  `DisplayDelegate.show` (which does nothing where the platform shows it itself, as iOS does).
- **Tapped**: a push tapped in the background (`MessagingDelegate.tapped`), one that started the app (`initial`), and
  one shown while open (`DisplayDelegate.tapped` / `initial`) all put their data in `opened`, which waits until the app
  is ready to `take` it.
- **Errors**: every delegate call is caught; `onError` gets it unless `unreachable` says it was only offline.

## Server side

Send to the tokens kept on the account, with the data your app reads in `opened` (a page, an id). A token the push
service says is no longer registered can be deleted there.
