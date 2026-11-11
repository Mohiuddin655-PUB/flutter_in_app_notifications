# In-app notification setup

The notification shown inside the app while it is open. The package says when it shows, how long it stays, and how
it comes and goes; how it looks is entirely the app's.

## 1. `init`

```dart
await InAppNotifications.init(
  ...
  whileOpen: WhileOpen.inAppAndBar,  // or inAppOnly: only inside the app
);
```

Without `init`, `InAppNotifications.show(...)` still shows one inside the app.

## 2. The host

In `MaterialApp`'s `builder`, where the app's theme and text direction are:

```dart
MaterialApp(
  ...
  builder: (context, child) => InAppNotificationHost(
    builder: (context, data) => MyNotification(data),  // required: the app's design
    child: child!,
  ),
);
```

All optional:

```dart
InAppNotificationHost(
  ...
  showFor: const Duration(seconds: 4),                  // how long it stays; stopped while held
  alignmentFor: (look) => Alignment.topCenter,          // where it shows, by its look
  duration: const Duration(milliseconds: 460),          // coming in
  reverseDuration: const Duration(milliseconds: 240),   // going out
  transitionBuilder: (child, animation, alignment) =>   // how it comes and goes (by default it slides in from its edge)
      FadeTransition(opacity: animation, child: child),
  openOnTap: true,                                      // a tap on it opens it
  dismissible: true,                                    // a swipe toward its edge takes it away
);
```

The host also handles what a finger does on it: a tap opens it, a swipe takes it away, and a finger on it or a text
field in it being typed in stops its time. The app's design does none of this.

**Or**, when the app already has its own overlay manager (for its toasts and popups), show it there instead, with no
host. Then the app does the host's work itself:

```dart
Timer? timer;

InAppNotifications.inApp.addListener(() {
  final m = InAppNotifications.inApp.value;               // the one to show, or null when it went
  timer?.cancel();
  if (m == null) return myOverlay.hide('notification');   // the app's own overlay
  myOverlay.show('notification', MyNotification(InAppNotificationData(message: m, remaining: 1)));
  timer = Timer(const Duration(seconds: 4), InAppNotifications.dismiss);   // its time
});

InAppNotifications.holding.addListener(() {               // held (a finger on it, a reply typed): its time stops
  timer?.cancel();
  if (!InAppNotifications.holding.value && InAppNotifications.inApp.value != null) {
    timer = Timer(const Duration(seconds: 4), InAppNotifications.dismiss);
  }
});
```

Without the host, its animation, its place, the time left (`remaining`) and keeping it above the keyboard are the
app's too.

## 3. The design

The builder gets the data; everything visible is the app's:

```dart
data.message                  // title, body, image, data
data.look                     // the look it was given, to pick a design
data.buttons                  // its actions as buttons (Accept, Reject)
data.reply                    // its reply action, if it has one
data.remaining                // 1 → 0: the time it has left, for a progress bar
data.answer(id, input: text)  // a button, or a reply sent
data.dismiss()                // a close button
data.open()                   // a button that opens it
data.hold(true)               // stops its time for anything else of the app's (a menu open on it); false goes on
```

A ready design to copy: [notification_card.dart](../example/lib/notification_card.dart): its image, title and body, a
reply field, its buttons and a progress bar; the look `black` fills the screen.

## 4. Show one

```dart
InAppNotifications.show(title: 'Saved', body: 'Your photo is up');
InAppNotifications.show(title: 'Match!', look: 'black');  // its design picked by its look
```

A push's look comes in its data (`"look": "black"`). A push or `notify(...)` while the app is open shows here too, as
`whileOpen` says.
