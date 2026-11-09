/// Where a push that comes while the app is open shows. In the background or closed, the system always shows it.
enum LocalNotificationVisibility {
  /// In the notification bar, through the app's `DisplayDelegate`.
  system,

  /// Inside the app (a banner at its top, say), from `InAppNotifications.inApp`; not in the notification bar.
  inApp,
}
