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
