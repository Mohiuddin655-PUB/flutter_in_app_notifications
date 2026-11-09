# App setup

Everything the app does to use `in_app_notifications`, in order. The package has no dependencies: the app brings the
push service, the display and the storage, and hands them over as three delegates. The examples use Firebase Cloud
Messaging, `flutter_local_notifications`, Firestore and `shared_preferences`; any other works the same way.

Then follow [android_setup.md](android_setup.md) and [ios_setup.md](ios_setup.md) for the platforms.

| Step | Need |
| --- | --- |
| 1 Dependencies, 2 messaging delegate, 3 display delegate, 4 token store, 5 setup/start/clear | **Required** |
| 6 The permission | **Required** (nothing shows on Android 13+ and iOS without it) |
| 7 Opening the right page | **Required** when a tap should open a page |
| 4b Schedule store | Optional: only so a scheduled notification whose time comes while the app is open shows inside it |
| 8 In-app banner (`inApp`, `InAppNotificationGate`) | Optional: without it, a notification while open shows in the notification bar (`system`) |
| 8 Notifications made on the phone (`notify`, `cancel`) | Optional |
| 9 Rich notifications (actions, replies, images, groups, sounds, progress) | Optional, per feature |

## 1. Dependencies

```yaml
dependencies:
  in_app_notifications:
    git:
      url: https://github.com/Mohiuddin655-PUB/flutter_in_app_notifications.git
      ref: <commit>                       # pin a commit; read CHANGELOG.md before moving it
  firebase_core: ^4.0.0
  firebase_messaging: ^16.0.0             # the push service
  flutter_local_notifications: ^23.0.0    # shows a push while open on Android, and notifications made on the phone
  timezone: ^0.11.0                       # a scheduled notification's moment
  cloud_firestore: ^6.0.0                 # where the tokens are kept (or your own backend)
  shared_preferences: ^2.0.0              # the token last saved, on the phone (or your own store)
```

Use **one** local notifications plugin. A plugin that makes itself iOS's notification delegate for every push (such as
`awesome_notifications`) decides how *every* push shows while the app is open, so the system banner can't be turned
off and a push shows twice with `LocalNotificationVisibility.inApp`.

## 2. The messaging delegate (the push service)

```dart
class FcmMessagingDelegate implements NotificationMessagingDelegate {
  const FcmMessagingDelegate();

  static FirebaseMessaging get _fcm => FirebaseMessaging.instance;

  /// An iPhone has no FCM token until Apple has registered it, which can take a moment after launch.
  @override
  Future<String?> token() async {
    if (Platform.isIOS) {
      for (var tries = 0; await _fcm.getAPNSToken() == null; tries++) {
        if (tries == 2) return null; // the refresh stream brings it later
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
    return _fcm.getToken().timeout(const Duration(seconds: 10));
  }

  @override
  Stream<String> get tokenRefreshes => _fcm.onTokenRefresh;

  @override
  Future<void> forgetToken() => _fcm.deleteToken();

  @override
  Stream<PushMessage> get received => FirebaseMessaging.onMessage.map(_message);

  @override
  Stream<PushMessage> get tapped => FirebaseMessaging.onMessageOpenedApp.map(_message);

  @override
  Future<PushMessage?> initial() async {
    final m = await _fcm.getInitialMessage();
    return m == null ? null : _message(m);
  }

  static PushMessage _message(RemoteMessage m) => PushMessage(
    id: m.messageId ?? '${m.sentTime?.millisecondsSinceEpoch}',
    title: m.notification?.title,
    body: m.notification?.body,
    data: {for (final e in m.data.entries) e.key: '${e.value}'},
  );
}
```

## 3. The display delegate (the notification bar)

```dart
class LocalDisplayDelegate implements NotificationDisplayDelegate {
  /// False when the app shows a push itself while open (LocalNotificationVisibility.inApp).
  const LocalDisplayDelegate({required this.systemWhileOpen});

  final bool systemWhileOpen;

  static const _channel = 'updates'; // the same id as AndroidManifest's default_notification_channel_id
  static final _plugin = FlutterLocalNotificationsPlugin();
  static final _taps = StreamController<Map<String, String>>.broadcast();

  @override
  Future<void> init() async {
    await _plugin.initialize(
      // Ask for the permission yourself, when it is needed and saying why (step 6), never here.
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat'),
        iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
      ),
      onDidReceiveNotificationResponse: (r) => _taps.add(_data(r.payload)),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(_channel, 'Notifications', importance: Importance.high));
    // iOS shows a push itself while open unless told not to; with inApp the app shows it instead.
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(alert: systemWhileOpen, badge: true, sound: true);
  }

  /// Android doesn't show a push while the app is open; iOS does by itself.
  @override
  Future<void> show(PushMessage message) async {
    if (Platform.isAndroid) await _show(message);
  }

  /// Android doesn't keep a push that came while open; iOS keeps it in its list (AppDelegate, ios_setup.md).
  @override
  Future<void> keep(PushMessage message) async {
    if (Platform.isAndroid) await _show(message, quiet: true);
  }

  @override
  Future<void> notify(PushMessage message, {DateTime? at, bool quiet = false}) async {
    if (at == null || !at.isAfter(DateTime.now())) return _show(message, quiet: quiet); // or your server clock, step 8
    await _plugin.zonedSchedule(
      id: _id(message.id),
      title: message.title,
      body: message.body,
      scheduledDate: TZDateTime.from(at.toUtc(), UTC),
      notificationDetails: _details(false),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle, // exact needs a permission
      payload: jsonEncode(message.data),
    );
  }

  @override
  Future<void> cancel(String id) => _plugin.cancel(id: _id(id));

  @override
  Stream<Map<String, String>> get tapped => _taps.stream;

  @override
  Future<Map<String, String>?> initial() async {
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final r = launch?.notificationResponse;
    return launch?.didNotificationLaunchApp == true && r != null ? _data(r.payload) : null;
  }

  /// Every notification the app has in the bar (the system's pushes too), at sign-out.
  @override
  Future<void> clearShown() => _plugin.cancelAll();

  Future<void> _show(PushMessage m, {bool quiet = false}) =>
      _plugin.show(id: _id(m.id), title: m.title, body: m.body, notificationDetails: _details(quiet), payload: jsonEncode(m.data));

  static int _id(String id) => id.hashCode & 0x7fffffff; // the same id replaces itself

  /// [quiet]: into the bar or list only, no pop-up or sound (the app shows its own banner for it).
  static NotificationDetails _details(bool quiet) => NotificationDetails(
    android: AndroidNotificationDetails(_channel, 'Notifications', importance: Importance.high, priority: Priority.high, silent: quiet),
    iOS: DarwinNotificationDetails(presentBanner: !quiet, presentList: true, presentSound: !quiet, presentBadge: true),
  );

  static Map<String, String> _data(String? payload) {
    if (payload == null || payload.isEmpty) return const {};
    final map = jsonDecode(payload);
    return map is Map ? {for (final e in map.entries) '${e.key}': '${e.value}'} : const {};
  }
}
```

## 4. The token store delegate (where the server finds the phones)

```dart
class FirestoreTokenStoreDelegate implements TokenStoreDelegate {
  const FirestoreTokenStoreDelegate(this.prefs);

  final SharedPreferences prefs;

  static DocumentReference _doc(String uid, String token) =>
      FirebaseFirestore.instance.doc('accounts/$uid/devices/$token');

  @override
  Future<void> save(String uid, String token) => _doc(uid, token)
      .set({'platform': Platform.isIOS ? 'ios' : 'android', 'at': FieldValue.serverTimestamp()})
      .timeout(const Duration(seconds: 10));

  /// Short: sign-out waits for it.
  @override
  Future<void> remove(String uid, String token) => _doc(uid, token).delete().timeout(const Duration(seconds: 3));

  @override
  String? saved(String uid) => prefs.getString('push_token_$uid');

  @override
  Future<void> remember(String uid, String? token) =>
      token == null ? prefs.remove('push_token_$uid') : prefs.setString('push_token_$uid', token);
}
```

Firestore rules for it: only the owner saves (two fields, the server's time) or removes its own phones.

```
match /accounts/{uid}/devices/{token} {
  allow read: if request.auth.uid == uid;
  allow create, update: if request.auth.uid == uid && token.size() <= 4096
    && request.resource.data.keys().hasOnly(['platform', 'at']) && request.resource.data.keys().hasAll(['platform', 'at'])
    && request.resource.data.platform in ['android', 'ios'] && request.resource.data.at == request.time;
  allow delete: if request.auth.uid == uid;
}
```

## 4b. The schedule store delegate (scheduled notifications while open)

```dart
class PreferencesScheduleStoreDelegate implements ScheduleStoreDelegate {
  const PreferencesScheduleStoreDelegate(this.prefs);

  final SharedPreferences prefs;

  @override
  String? read() => prefs.getString('push_schedules');

  @override
  Future<void> write(String? text) => text == null ? prefs.remove('push_schedules') : prefs.setString('push_schedules', text);
}
```

With it, a scheduled notification whose time comes while the app is open shows like any other (inside the app, and
quietly in the bar): the kit waits on a timer while the app is on screen and gives the time back to the phone's alarm
once it is hidden. Without it, the phone shows it by itself.

## 5. Setup, start, clear

```dart
// At launch, after Firebase.initializeApp. A failure inside is reported, never thrown: the app starts without pushes.
const visibility = LocalNotificationVisibility.inApp; // or system: the notification bar while open too
InAppNotifications.setup(
  messaging: const FcmMessagingDelegate(),
  display: const LocalDisplayDelegate(systemWhileOpen: visibility == LocalNotificationVisibility.system),
  tokens: FirestoreTokenStoreDelegate(prefs),
  schedules: PreferencesScheduleStoreDelegate(prefs),
  visibility: visibility,
  now: () => DateTime.now(), // or the server's clock
  onError: (error, stack, where) => FirebaseCrashlytics.instance.recordError(error, stack, reason: where),
  unreachable: (error) => error is TimeoutException || (error is FirebaseException && error.code == 'unavailable'),
);
await InAppNotifications.init();

// At every sign-in, and at a launch that is still signed in.
InAppNotifications.start(uid);

// Before sign-out and before deleting the account, while the account can still write.
await InAppNotifications.clear();
```

`start` saves the token only when it changed (a launch writes nothing); `clear` removes it from the account, lets it go
on the phone, and takes away every notification in the bar and any tap not yet handled, so nothing opens a page for the
next account.

## 6. The permission

Android 13+ and iOS show nothing in the notification bar without it. Ask when it is needed, saying why (an onboarding
step, say), and remember on the phone that it was asked. **Also ask once on the home page when it was never asked on
this phone**: someone who signs in on a new phone, or after a reinstall, skips the onboarding and would otherwise never
be asked. On Android ask with the system's request (`permission_handler`), then `FirebaseMessaging.requestPermission()`,
which is what asks on iOS. When it is off for good, offer the phone's Settings.

## 7. Opening the right page

A push's data names where it goes (`{'page': 'chats'}`, say). Listen once the home page is up:

```dart
void _openPushed() {
  final data = InAppNotifications.opened.value;
  if (data == null) return;
  InAppNotifications.take();
  // Close whatever is open over the tabs (a page, a sheet, a dialog), so the tab shows.
  final home = ModalRoute.of(context);
  Navigator.of(context).popUntil((r) => r == home || r.isFirst);
  selectTab(data['page']);
}
// initState: _openPushed() for a push that started the app; then InAppNotifications.opened.addListener(_openPushed).
```

Ignore a page your version doesn't have, and compare names exactly.

## 8. Inside the app, and notifications made on the phone

- With `LocalNotificationVisibility.inApp`, wrap the app (in `MaterialApp.builder`) with `InAppNotificationGate` and
  give it the banner's look (`builder`) and motion (`transitionBuilder`); see the README.
- `InAppNotifications.notify(id:, title:, body:, data:, at:)` shows one now, or schedules it for `at` (it shows even when
  the app is closed, and after a restart on Android once the receivers are declared); `cancel(id)` takes it away; a tap
  opens its `data` like a push's. A scheduled one fires by the **phone's** clock: if the app keeps a server clock, move
  `at` by how far the server is ahead of the phone. A phone can only schedule for itself: to reach someone at 10am in
  their time zone, keep their zone with their token and send from the server.

## 9. Rich notifications: actions, replies, images, groups

Everything below is optional; a plain app stops at step 8.

### 9.1 Categories and the action handler

Each kind of notification names its actions once, in `setup`. Every answer (a tap on Accept, a typed reply) comes to
`onAction`, in the background too, so it must be a **top-level or static function** that sets up what it needs itself
(a background isolate has none of the app's state):

```dart
const categories = [
  NotificationCategory(id: 'chat', actions: [
    NotificationAction(id: 'reply', title: 'Reply', input: true, inputHint: 'Message', inputButton: 'Send'),
  ]),
  NotificationCategory(id: 'request', actions: [
    NotificationAction(id: 'accept', title: 'Accept'),
    NotificationAction(id: 'reject', title: 'Reject', destructive: true),
  ]),
];

@pragma('vm:entry-point')
Future<void> handleAction(NotificationAnswer a) async {
  if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  switch (a.actionId) {
    case 'reply': await sendMessage(a.data['chatId']!, a.input ?? '');
    case 'accept': await acceptRequest(a.data['from']!);
    case 'reject': await rejectRequest(a.data['from']!);
  }
}

InAppNotifications.setup(
  // ...the delegates of steps 2 to 5
  categories: categories,
  onAction: handleAction,
);
InAppNotifications.actions.listen((a) { /* a screen that wants to know, while the app runs */ });
```

### 9.2 The display delegate, rich

`init` takes the categories (iOS must register them first; Android puts them on each notification), and an answer
comes back as a `NotificationAnswer`. Keep the notification's own id in the payload, so an answer knows which one it
was, and pass flutter_local_notifications a **static** background callback for an action answered while the app isn't
running:

```dart
class LocalDisplayDelegate implements NotificationDisplayDelegate {
  const LocalDisplayDelegate({required this.systemWhileOpen, this.background});

  final bool systemWhileOpen;
  final void Function(NotificationResponse r)? background; // flutter_local_notifications' response

  static final _plugin = FlutterLocalNotificationsPlugin();
  static final _answers = StreamController<NotificationAnswer>.broadcast();
  static var _categories = <String, NotificationCategory>{};

  @override
  Future<void> init({List<NotificationCategory> categories = const []}) async {
    _categories = {for (final c in categories) c.id: c};
    await _plugin.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings('ic_stat'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false,
          notificationCategories: [
            for (final c in categories)
              DarwinNotificationCategory(c.id, actions: [
                for (final a in c.actions)
                  a.input
                      ? DarwinNotificationAction.text(a.id, a.title, buttonTitle: a.inputButton ?? a.title, placeholder: a.inputHint)
                      : DarwinNotificationAction.plain(a.id, a.title, options: {
                          if (a.destructive) DarwinNotificationActionOption.destructive,
                          if (a.opensApp) DarwinNotificationActionOption.foreground,
                        }),
              ]),
          ],
        ),
      ),
      onDidReceiveNotificationResponse: (r) => _answers.add(answerOf(r.id, r.actionId, r.input, r.payload)),
      onDidReceiveBackgroundNotificationResponse: background,
    );
    // ...the channel and setForegroundNotificationPresentationOptions, as in step 3
  }

  @override
  Stream<NotificationAnswer> get responses => _answers.stream;

  @override
  Future<NotificationAnswer?> initial() async {
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final r = launch?.notificationResponse;
    return launch?.didNotificationLaunchApp == true && r != null ? answerOf(r.id, r.actionId, r.input, r.payload) : null;
  }

  static String _payload(PushMessage m) => jsonEncode({'id': m.id, 'data': m.data});

  static NotificationAnswer answerOf(int? id, String? actionId, String? input, String? payload) {
    final map = payload == null || payload.isEmpty ? const {} : jsonDecode(payload) as Map;
    final data = map['data'] is Map ? {for (final e in (map['data'] as Map).entries) '${e.key}': '${e.value}'} : const <String, String>{};
    return NotificationAnswer(id: '${map['id'] ?? id}', actionId: (actionId ?? '').isEmpty ? null : actionId, input: input, data: data);
  }
  // show, keep, notify, cancel, clearShown as in step 3, building their details from the message (9.3)
}
```

### 9.3 A message's details

Build each notification's details from the `PushMessage`, so every field shows:

| `PushMessage` | Android (`AndroidNotificationDetails`) | iOS (`DarwinNotificationDetails`) |
| --- | --- | --- |
| `image` (download an https one to a file first) | `styleInformation: BigPictureStyleInformation(FilePathAndroidBitmap(path))`, `largeIcon` | `attachments: [DarwinNotificationAttachment(path)]` |
| `group` | `groupKey` | `threadIdentifier` |
| `category` | `actions:` its `AndroidNotificationAction`s (`inputs: [AndroidNotificationActionInput(label:)]` for `input`, `showsUserInterface: opensApp`) | `categoryIdentifier` |
| `channel` | the channel id | — |
| `sound` | `RawResourceAndroidNotificationSound(sound)` (`res/raw`) | `sound` (a file in the app bundle) |
| `badge` | `number` | `badgeNumber` |
| `progress` | `showProgress`, `maxProgress`, `progress`, `indeterminate` | — (say it in the body) |
| `ongoing` | `ongoing` | — |
| `expanded` | `BigTextStyleInformation(body)` | — (iOS expands by itself) |
| `urgent` | `Importance.max`, `Priority.max` | `interruptionLevel: InterruptionLevel.timeSensitive` (with the Time Sensitive capability) |
| `quiet` (from the kit) | `silent: true` | `presentBanner: false, presentSound: false, presentList: true` |

### 9.4 A push while the app isn't in front

- **iOS** shows a push itself, with its actions from `aps.category` and its image through the extension
  (ios_setup.md §4).
- **Android** shows only plain pushes by itself: one with actions or an image must come **data-only** (its `title` and
  `body` in the data, with `category`, `image`, `group`...), and the app shows it from a background handler, registered
  at launch:

```dart
@pragma('vm:entry-point')
Future<void> pushInBackground(RemoteMessage m) async {
  final message = PushMessage.fromData(id: m.messageId ?? '', title: m.data['title'], body: m.data['body'],
      data: {for (final e in m.data.entries) e.key: '${e.value}'});
  if (m.notification != null || message.silent) return; // the system showed a plain one itself
  await LocalDisplayDelegate.showNow(message, categories: categories); // initialize the plugin, then show
}

FirebaseMessaging.onBackgroundMessage(pushInBackground); // at launch, before runApp
```

- The messaging delegate reads a push with `PushMessage.fromData` (title and body from the data when the push has no
  notification part), so a push shows the same way while the app is open.

### 9.5 What the server sends

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

Android gets it data-only (the app shows it, with its actions and image); iOS shows the `aps` part itself, with the
category's actions and, through the extension, the image.

### 9.6 The app's own banner

`InAppNotificationGate`'s builder gets the message: offer its actions with `InAppNotifications.category(message.category)`
and answer one with `InAppNotifications.answer(actionId, input:)`, which goes to `onAction` like an answer on the
notification and takes the banner and its copy in the bar away.
