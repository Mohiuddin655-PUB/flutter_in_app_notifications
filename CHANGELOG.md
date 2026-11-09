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
