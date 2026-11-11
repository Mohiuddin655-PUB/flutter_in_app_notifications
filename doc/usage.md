# Usage

Each step of [setup.md](setup.md) after init, explained.

## 1. Sending one

`notify(id:, title:, body:, data:)` shows one now; with `at:` or `after:` it is scheduled, and shows even when the app
is closed. `cancel(id)` takes it away. `show()` shows one only inside the app. A scheduled one fires by the **phone's**
clock: with a server clock, move `at` by how far the server is ahead. A phone schedules only for itself: to reach
someone at 10am in their time zone, send from the server.

To another phone, the server sends to the tokens kept on its account ([tokens](../push_example/lib/firestore_token_store_delegate.dart)): [server_setup.md](server_setup.md).

A push while the app isn't in front: iOS shows it itself (its actions from `aps.category`, its image through the
extension in [ios_setup.md](ios_setup.md)); Android shows only plain ones itself, so one with actions or an image comes
data-only, and [push_background.dart](../push_example/lib/push_background.dart) shows it.

## 2. A tap opens its page

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

## 3. Actions and replies

The kinds of notification and their actions, and what the app does with an answer, are in
[push_background.dart](../push_example/lib/push_background.dart) (`categories`, `onAction`): fixed in code, because
an action answered while the app isn't running runs in a background isolate with none of the app's state. While the app
runs, a screen can also listen to `InAppNotifications.actions`.

An answer takes its notification away; a reply's text is in `input`, the notification's data in `data`.

## 4. Check it works

1. A local one: `await InAppNotifications.notify(id: 'test', title: 'Local works');` shows in the notification bar.
2. A push: print this phone's token (`FirebaseMessaging.instance.getToken()`), then send to it from the Firebase console
   (Messaging › New campaign › Send test message). In the background it shows in the notification bar; while open, as
   `whileOpen` says; a tap opens its page (§2).
3. An action: a push with `category` in its data shows its buttons; an answer reaches `onAction`.
