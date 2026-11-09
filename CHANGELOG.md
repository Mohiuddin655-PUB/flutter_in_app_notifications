## 0.1.0

- `InAppNotifications`: `setup` with the app's delegates, `init`, `start`, `clear`, `opened` and `take`.
- The device token kept on the signed-in account: saved only when new or changed, moved on refresh, taken off and let go
  at sign-out.
- A push that comes while the app is open is shown through the app's `DisplayDelegate`; a tapped one (in the
  background, closed, or shown while open) waits in `opened` until the app takes it.
- No dependencies: the push service, the display and the storage are the app's delegates.
