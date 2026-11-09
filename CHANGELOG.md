## 0.12.8

- The README links the banner's looks as a live page (raw.githack), to open in a browser and play its arrival.

## 0.12.7

- **Sharper README pictures**: the banner's looks at three times the resolution, three to a row, and the real app's at
  its own size.

## 0.12.6

- **The README shows the banner**: every look of it, each with the call that makes it (`doc/images/banner_looks.png`,
  and `doc/banner_looks.html` to play its arrival in a browser), the same looks in a real app, and what the package
  does; both pictures are pub.dev screenshots too.

## 0.12.5

- **The status bar follows a gradient card too**: under the status bar, a card with a gradient sets its icons by its
  colours mixed (before, only a plain colour counted, so a bright gradient kept dark icons by the theme's surface).

## 0.12.4

- **The banner follows the finger exactly from the first touch**: it tracks the finger's own position, not the drag's
  deltas, which only start once a drag is recognised (about 18 pt in) and left the banner that far behind; the drag is
  still claimed, so a dragged banner isn't also tapped.
- **A hold isn't a tap**: let go after holding the banner, it goes on its time instead of opening.

## 0.12.3

- The banner's motion is `InAppNotificationMotion` (`arrive`, `leave`, `transition`, `slide`), and the drag's
  paint-only follower `InAppNotificationFollow`, each in its own file; `InAppNotificationBanner.transition` and the
  rest stay as they were.

## 0.12.2

- **Lighter on the device**: the banner's coming, going and drag are transitions and a paint-only translate, so a
  frame moves, fades and scales it without building anything again; the banner paints on its own layer, so the page
  under it isn't repainted while it moves; its image is decoded at the size it shows.

## 0.12.1

- **The status bar follows the banner while it covers it**: with `safeArea: false` (drawn under the status bar) its
  icons are dark on a light card and light on a dark one (`statusBarStyle` to choose), and the page's again once the
  banner has moved off it, dragged or leaving. Kept clear of it, nothing changes.

## 0.12.0

- **`InAppNotifications.show()`: the banner alone**: shows a message in the app's banner (`InAppNotificationGate`)
  with nothing in the notification bar and no push, whatever the visibility; its actions and a tap work as any
  other's.

## 0.11.1

- **Android: a notification answered with a typed reply goes**: Android holds one a moment after a direct reply and
  ignores a cancel made at once, so it is taken away once more 1.5 s later. A background handler does the same (the
  guide shows it).

## 0.11.0

- **The banner moves as Discord's**: it comes down from above, fading in and growing from a little smaller, a touch
  past its place and back (`InAppNotificationBanner.arrive`); it goes up, shrinking and fading
  (`InAppNotificationBanner.leave`). This is the gate's default transition (`InAppNotificationBanner.transition`;
  enter 460 ms, exit 240 ms).
- **Held and dragged** (`InAppNotificationDrag`): a finger on it holds it; dragged it follows the finger exactly (up
  one to one, down only a little); let go far enough up or flung, it carries on out from where it is at the finger's
  speed, fading and shrinking as far as it has gone; let go short of that, it springs back from where it is.
- **Breaking**: `InAppNotifications.hold(on, reason:)` holds by reason (a reply being typed and a finger on it are two),
  and `InAppNotificationBannerStyle.dismissDirection` is gone (it is swiped up; `dismissible: false` turns it off).

## 0.10.1

- **The banner's reply field works**: `InAppNotificationBanner` brings its own `Material` (the gate sits outside the
  app's pages, and a text field needs one); before, a banner with a reply field showed an error.
- **iOS**: an action on a push carries its category and thread in the data (from `aps`), as on Android.

## 0.10.0

- **`InAppNotificationBanner`, a ready banner for the gate**: the message's title and body, its image, its category's
  actions as buttons and a reply field (`InAppNotificationReplyField`, holding the banner while typed in); a tap opens
  it, a swipe dismisses it. Every visible part is the app's to change: `InAppNotificationBannerStyle` (margins,
  padding, the card's decoration, text styles, image size and corners, gaps, button styles, the reply field's
  decoration, swipe direction, safe area), and builders that replace a part whole (`leading`, `content`, `trailing`,
  `actionBuilder`, `replyBuilder`, `container`). `InAppNotificationBanner.slideTransition` for the gate.

## 0.9.6

- **An answered notification goes**: after an action (a reply, Accept), its notification is taken away; Android left
  one answered with a reply on screen, spinning. A background handler does the same itself (the guide shows how).
- **The app's banner can stay while in use**: `InAppNotifications.hold(true)` keeps it (a reply being typed) until
  `hold(false)`, an answer, a tap or a dismiss; `holding` tells the banner.
- **iOS**: a push action's data leaves out the push's own keys (`gcm.*`, `google.*`), as Android's does.

## 0.9.5

- **iOS: an action on a push answered while the app was closed is handled at once**: the plugin keeps the app running
  (a background task, up to 25 s) until the Dart handler is done, instead of telling iOS it was done at once, which
  suspended the app until the user opened it.

## 0.9.4

- **Android: actions work**: the package's manifest declares flutter_local_notifications' `ActionBroadcastReceiver`;
  without it a notification's buttons and reply did nothing.
- **Docs**: background handlers' class needs `@pragma('vm:entry-point')` too; `urgent` on Android needs a channel of its
  own with high importance (a channel's importance can't change once made); Android 14+ lets users swipe away an
  `ongoing` one.

## 0.9.3

- **Docs say what is required and what is optional**: the README's native checklist and the app setup guide's steps
  each marked Required, Recommended, Optional or For <feature>.

## 0.9.2

- **App setup guide, step 9**: categories and the action handler, the rich display delegate, each field's details on
  Android and iOS, a push while the app isn't in front (Android data-only and its background handler), what the server
  sends, and the app's own banner with actions.

## 0.9.1

- **iOS: a push's image from the package**: `InAppNotificationService` (pod `InAppNotificationsService`, no Flutter)
  does the work of the app's Notification Service Extension; the app's extension is one line,
  `class NotificationService: InAppNotificationService {}`, and its Podfile adds the pod to that target.

## 0.9.0

- **Rich notifications**: `PushMessage` carries an `image`, a `group` (a chat's thread), a `category` (its actions), a
  `channel`, a `sound`, a `badge`, `progress`, `ongoing`, `expanded` and `urgent`; `PushMessage.fromData` reads them
  from a push's data (`NotificationKeys`). `InAppNotifications.notify(message:)` shows such a one.
- **Actions and replies**: `setup(categories: [NotificationCategory(...)])` names what each kind offers
  (`NotificationAction`: a button, or a text field with `input: true`); `setup(onAction:)` gets each answer as a
  `NotificationAnswer` (its `actionId` and typed `input`), in the background too; `InAppNotifications.actions` streams
  them while the app runs; the app's banner offers them through `InAppNotifications.category` and `answer`.
- **iOS: actions on a push** reach the app (Firebase Messaging only tells of a tap), even one that started it.
- **Breaking**: `NotificationDisplayDelegate.init(categories:)`, `responses` (in place of `tapped`) and `initial()`
  giving a `NotificationAnswer`.

## 0.8.6

- **iOS: tapping the in-app banner of a push takes its Notification Center copy away too.** iOS shows a push under an
  id of its own, so the display's cancel missed it; the plugin now finds it by its `gcm.message_id`.

## 0.8.5

- **A schedule survives the app dying in front** (a crash, a kill): the phone's alarm stays set while the app is in
  front too, and is taken away just before the time (2s), when the app shows it itself.

## 0.8.4

- **A schedule survives the app being swiped away**: it goes back to the phone's alarm as soon as the app leaves the
  front (inactive: the app switcher, the notification shade), not only once hidden. An app swiped away from the
  switcher is never hidden first, so a schedule waiting on a timer was lost.

## 0.8.3

- **iOS**: the plugins still hear of a notification while the app is open (Firebase Messaging's `onMessage` comes from
  there); 0.8.0 to 0.8.2 answered without passing it on, so the app never heard of a push while open.

## 0.8.2

- Fixes 0.8.1, which didn't compile (`notify(after:)`).

## 0.8.1

- **Plain times to schedule**: `notify(at:)` takes a plain `DateTime` (`DateTime(2026, 11, 10, 10)` for 10am), and
  `notify(after: Duration)` a while from now; both are read by `setup(now:)`'s clock, so callers never reach for it.

## 0.8.0

- **A plugin, so the app's native side stays small**: Android's `POST_NOTIFICATIONS` and `RECEIVE_BOOT_COMPLETED`
  permissions and flutter_local_notifications' scheduled-notification receivers come in through the package's
  manifest; on iOS the package answers how a notification shows while the app is open (no AppDelegate override). Still
  no dependencies. Apps drop those lines from their own manifest and AppDelegate.

## 0.7.0

- **Every notification shows the same way while the app is open**, push or made on the phone: with
  `LocalNotificationVisibility.inApp` it shows inside the app (`inApp`) **and** goes into the notification bar quietly
  (no pop-up, no sound), so it can be read there later; tapping the banner takes the bar's copy away.
- **Scheduled notifications show inside the app too**: `setup(schedules: ScheduleStoreDelegate)` keeps them between
  launches; while the app is open they wait on timers (the phone's alarms are taken away) and show like the rest, and
  once it is hidden they go back to the phone. `setup(now:)` is the clock their times are read by.
- **Breaking**: `NotificationDisplayDelegate.notify(message, at:, quiet:)` and `keep(message)` (a push that came while
  open, into the bar quietly).

## 0.6.3

- **iOS guide**: the AppDelegate answers how a notification made on the phone shows while the app is open; otherwise
  Firebase Messaging answers for it with the push options and, with `inApp`, it shows nowhere.

## 0.6.2

- **Native checklist** in the README: every Android and iOS file to change, and what goes in it.

## 0.6.1

- **Setup guides**: `doc/app_setup.md` (the delegates and everything the app wires up), `doc/android_setup.md` and
  `doc/ios_setup.md` (the platform setup and how each behaves when testing), linked from the README.

## 0.6.0

- **Notifications made on the phone**: `InAppNotifications.notify(id:, title:, body:, data:, at:)` shows one in the
  notification bar now, or schedules it for `at` (shown even when the app is closed); `cancel(id)` takes it away. A tap
  puts its `data` in `opened`, as a push's.
- **Breaking**: `NotificationDisplayDelegate.notify(message, at:)` and `cancel(id)`, the app's way to make them.

## 0.5.0

- **Sign-out forgets what the account was told**: `InAppNotifications.clear()` also drops a tapped push not yet taken
  and the one showing inside the app, and asks the display to take away every push still in the notification bar, so
  none opens a page for the next account.
- **Breaking**: `NotificationDisplayDelegate.clearShown()`, the app's way to take its shown pushes away.

## 0.4.0

- **`InAppNotificationGate`**: wraps the app and shows a push that comes while it is open
  (`LocalNotificationVisibility.inApp`) with the app's own `builder`: the newest replaces the one showing, it goes by
  itself after `showFor`, and comes and goes through the app's `transitionBuilder` (`enter`, `exit`), at once with
  animations turned off on the phone. `alignment` places it (the top by default).

## 0.3.0

- **Breaking**: `DisplayDelegate` is `NotificationDisplayDelegate` and `MessagingDelegate` is
  `NotificationMessagingDelegate`, so their names say what they are for next to the app's other delegates.

## 0.2.0

- **Where a push shows while the app is open**: `setup(visibility: LocalNotificationVisibility.inApp)` puts it in
  `InAppNotifications.inApp` (the newest) for the app to show inside itself, a banner at its top, say, instead of the
  notification bar; `open()` when it is tapped (its data goes to `opened`), `dismiss()` when it goes. `system` (the
  default) shows it in the notification bar, as before. In the background or closed, the system shows it either way.

## 0.1.0

- `InAppNotifications`: `setup` with the app's delegates, `init`, `start`, `clear`, `opened` and `take`.
- The device token kept on the signed-in account: saved only when new or changed, moved on refresh, taken off and let go
  at sign-out.
- A push that comes while the app is open is shown through the app's `DisplayDelegate`; a tapped one (in the
  background, closed, or shown while open) waits in `opened` until the app takes it.
- No dependencies: the push service, the display and the storage are the app's delegates.
