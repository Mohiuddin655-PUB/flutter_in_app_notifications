/// The keys a push's data may carry to shape its notification (`PushMessage.fromData`); the rest is the app's own.
abstract final class NotificationKeys {
  /// A data-only push's title and body (one that has no notification part, so the app shows it itself).
  static const title = 'title';
  static const body = 'body';

  /// The look the app gave it, for `InAppNotificationHost`'s builder to pick its design.
  static const look = 'look';

  /// An image's address (https) shown with it.
  static const image = 'image';

  /// Notifications that belong together (a chat's thread): grouped in the bar.
  static const group = 'group';

  /// Which of the app's `NotificationCategory`s it is: the actions it offers (iOS reads `aps.category` instead).
  static const category = 'category';

  /// The Android channel it shows on.
  static const channel = 'channel';

  /// A sound's name, bundled with the app.
  static const sound = 'sound';

  /// Its badge number on the app's icon.
  static const badge = 'badge';

  /// `true`: it breaks through Focus (iOS time-sensitive) and pops up on Android.
  static const urgent = 'urgent';

  /// `true`: its whole body shows when expanded.
  static const expanded = 'expanded';
}
