/// Where a notification that comes while the app is open shows, a push or one made on the phone. In the background or
/// closed, the notification bar shows it whatever this says, and `InAppNotifications.show()` always puts its message in
/// the app's banner.
enum WhileOpen {
  /// In the notification bar, as the phone shows it (the default). The banner shows only what `show()` sends.
  bar,

  /// In the app's banner, and quietly in the notification bar too (no pop-up, no sound), to read there later. Tapping
  /// the banner takes that copy away.
  banner,

  /// Only in the app's banner: nothing goes to the notification bar while the app is open.
  bannerOnly;

  /// The app shows it in its own banner.
  bool get inApp => this != bar;

  /// A copy goes quietly into the notification bar too.
  bool get keepsInBar => this == banner;
}
