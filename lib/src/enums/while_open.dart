/// Where a notification that comes while the app is open shows, a push or one made on the phone. In the background or
/// closed, the notification bar shows it whatever this says, and `InAppNotifications.show()` always puts its message in
/// the in-app notification.
enum WhileOpen {
  /// In the notification bar, as the phone shows it (the default). The in-app notification shows only what `show()`
  /// sends.
  bar,

  /// Inside the app, and quietly in the notification bar too (no pop-up, no sound), to read there later. Tapping
  /// the in-app notification takes that copy away.
  inApp,

  /// Only inside the app: nothing goes to the notification bar while the app is open.
  inAppOnly;

  /// The app shows it inside itself.
  bool get showsInApp => this != bar;

  /// A copy goes quietly into the notification bar too.
  bool get keepsInBar => this == inApp;
}
