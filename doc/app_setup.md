# App setup, in depth

Each step of [setup.md](setup.md), explained; the dependencies are in [pubspec_setup.md](pubspec_setup.md). The ready
code is in [push_example](../push_example/lib): copy its files into the app and change only what is yours (the channels,
the categories, the Firestore path). It uses Firebase Cloud Messaging, flutter_local_notifications, Firestore and
shared_preferences; any other push service, display or storage works the same way, through the same delegates.

## 1. The messaging delegate (the push service)

[fcm_messaging_delegate.dart](../push_example/lib/fcm_messaging_delegate.dart): the token, a push received while open,
tapped, or that started the app.

- `init` sets the handler for a push while the app isn't in front (`background`), so `InAppNotifications.init` does it.
- An iPhone has no token until Apple has registered it: `token` waits a moment, and `tokenRefreshes` brings it later.
- iOS sends a push's category and thread in `aps`, not in the data: it adds them, so a push offers the same actions
  inside the app.
- A data-only push carries its title and body in its data (`NotificationKeys.title`, `body`).

## 2. The display delegate (the notification bar)

[local_display_delegate.dart](../push_example/lib/local_display_delegate.dart) and
[local_notification_details.dart](../push_example/lib/local_notification_details.dart): shows, keeps, schedules and
cancels notifications on the phone; a tap or an action comes back as a `NotificationAnswer`.

- `systemWhileOpen`: true only with `WhileOpen.bar`; otherwise iOS doesn't show a push itself while the app is open.
- Android doesn't show a push while the app is open: `show` shows it, and `keep` puts it in the bar quietly.
- Each notification's id travels in its payload, so an answer knows which one it was.
- The channels' ids and names, and the small icon, are the app's to change.
- A message's details: its `image` (downloaded to a file first), `group`, `category` (its actions), `channel`, `sound`
  (`res/raw` on Android, the app bundle on iOS), `badge`, `progress`, `expanded` and `urgent`, on both platforms.
- Android 15+ keeps one answered with a typed reply on screen: `cancelShown` takes it away.

## 3. The token store delegate (where the server finds the phones)

[firestore_token_store_delegate.dart](../push_example/lib/firestore_token_store_delegate.dart): an account's tokens at
`accounts/{uid}/devices/{token}`, and the one last saved from this phone, so a launch writes nothing. Guard the path
with security rules: only the account itself writes its own devices.

## 4. The schedule store delegate (scheduled notifications while open)

[preferences_schedule_store_delegate.dart](../push_example/lib/preferences_schedule_store_delegate.dart): optional.
With it, a scheduled notification whose time comes while the app is open shows inside the app as `whileOpen` says;
without it, the phone shows it by itself.

## 5. Init, at launch

[push_setup.dart](../push_example/lib/push_setup.dart): call `PushSetup.init()` in `main`, before `runApp`. It starts
Firebase and gives `InAppNotifications.init` everything, once. A failure inside goes to `onError`, never thrown: the
app starts without pushes.

| `whileOpen` | While the app is open | In the background or closed |
| --- | --- | --- |
| `bar` (default) | In the notification bar | In the notification bar |
| `inApp` | Inside the app (§8), and quietly in the notification bar | In the notification bar |
| `inAppOnly` | Only inside the app (§8) | In the notification bar |

A push while the app isn't in front: iOS shows it itself (its actions from `aps.category`, its image through the
extension in [ios_setup.md](ios_setup.md)); Android shows only plain ones itself, so one with actions or an image comes
data-only, and [push_background.dart](../push_example/lib/push_background.dart) shows it.

## 6. With the account

`start(uid)` at every sign-in, and at a launch still signed in: the token is saved on the account when it changed.
`clear()` before sign-out and before deleting the account, while the account can still write: no token stays on it,
nothing stays in the notification bar, and no tap is left to open a page for the next account.

## 7. The permission

Android 13+ and iOS show nothing in the notification bar without it. Ask when it is needed, saying why (an onboarding
step, say), and remember on the phone that it was asked. **Also ask once on the home page when it was never asked on
this phone**: someone who signs in on a new phone, or after a reinstall, skips the onboarding. On Android ask with the
system's request (`permission_handler`), then `FirebaseMessaging.requestPermission()`, which is what asks on iOS. When
it is off for good, offer the phone's Settings.

## 8. Shown inside the app

With `inApp` or `inAppOnly`, the package says which message is in it (`InAppNotifications.inApp`) and when it is held
(`InAppNotifications.holding`); the app draws it where it shows its overlays, and:

- shows `InAppNotificationView` for it, coming and going with `InAppNotificationMotion.transitionAt(edge)`;
- calls `InAppNotifications.dismiss()` after a few seconds, but not while `holding` (a finger on it, a reply typed);
- keeps it above the keyboard, and gives it its own `Overlay` (`Overlay.wrap`) so its reply field can be focused;
- at the bottom, puts `InAppNotificationEdgeScope(edge: InAppNotificationEdge.bottom)` around it.

The example's [InAppNotificationHost](../example/lib/in_app_notification_host.dart) does all of this in one small
widget, ready to copy:

```dart
MaterialApp(builder: (context, child) => InAppNotificationHost(edge: InAppNotificationEdge.top, child: child!));
```

It works without `init` too: `show()` and `InAppNotifications.categories = [...]` need nothing else.

## 9. Sending one

`notify(id:, title:, body:, data:)` shows one now; with `at:` or `after:` it is scheduled, and shows even when the app
is closed. `cancel(id)` takes it away. `show()` shows one only inside the app. A scheduled one fires by the **phone's**
clock: with a server clock, move `at` by how far the server is ahead. A phone schedules only for itself: to reach
someone at 10am in their time zone, send from the server.

To another phone, the server sends to the tokens kept on its account (§3):

```json
{"message": {
  "token": "…",
  "data": {"title": "Nadia", "body": "Are you coming?", "category": "chat", "group": "chat-42",
           "image": "https://…/photo.jpg", "page": "chats", "chatId": "42"},
  "android": {"priority": "high"},
  "apns": {"payload": {"aps": {"alert": {"title": "Nadia", "body": "Are you coming?"},
                               "category": "chat", "thread-id": "chat-42", "mutable-content": 1}},
           "fcm_options": {"image": "https://…/photo.jpg"}}
}}
```

Android gets it data-only (the app shows it, with its actions and image); iOS shows the `aps` part itself. A token the
push service says is no longer registered can be deleted there.

## 10. A tap opens its page

```dart
void _openPushed() {
  final data = InAppNotifications.take();      // {'page': 'chats', ...}
  if (data == null) return;
  final home = ModalRoute.of(context);
  Navigator.of(context).popUntil((r) => r == home || r.isFirst); // close what is open over the tabs
  selectTab(data['page']);                     // ignore a page this version doesn't have
}
// initState: _openPushed() for a push that started the app; then InAppNotifications.opened.addListener(_openPushed)
```

## 11. Actions and replies

The kinds of notification and their actions, and what the app does with an answer, are in
[push_background.dart](../push_example/lib/push_background.dart) (`categories`, `onAction`): fixed in code, because
an action answered while the app isn't running runs in a background isolate with none of the app's state. While the app
runs, a screen can also listen to `InAppNotifications.actions`.

An answer takes its notification away; a reply's text is in `input`, the notification's data in `data`.

## 12. Its own look

`InAppNotificationView` takes a `style` (`InAppNotificationStyle`: margins, padding, the card's decoration, text styles,
image size and corners, gaps, button styles, the reply field's decoration, swipe direction, safe area) and builders
that replace a part whole (`leading`, `content`, `trailing`, `actionBuilder`, `replyBuilder`, `container`). Or draw one
entirely the app's own: offer its actions with `InAppNotifications.category(message.category)`, answer with
`InAppNotifications.answer(actionId, input:)`, and `InAppNotifications.hold(true)` while a reply is typed.

## 13. Check it works

1. A local one: `await InAppNotifications.notify(id: 'test', title: 'Local works');` shows in the notification bar.
2. A push: print this phone's token (`FirebaseMessaging.instance.getToken()`), then send to it from the Firebase console
   (Messaging › New campaign › Send test message). In the background it shows in the notification bar; while open, as
   `whileOpen` says; a tap opens its page (§10).
3. An action: a push with `category` in its data shows its buttons; an answer reaches `onAction`.
