import '../../keys/notification_keys.dart';

/// A notification, a push's or one made on the phone: its [title] and [body] when it has them, its [data] (all
/// strings, as push services send them), and how it shows.
class PushMessage {
  const PushMessage({
    required this.id,
    this.title,
    this.body,
    this.data = const {},
    this.image,
    this.group,
    this.category,
    this.channel,
    this.sound,
    this.badge,
    this.progress,
    this.ongoing = false,
    this.expanded = false,
    this.urgent = false,
  });

  /// From a push's [data], whose [NotificationKeys] shape it.
  factory PushMessage.fromData({required String id, String? title, String? body, Map<String, String> data = const {}}) {
    return PushMessage(
      id: id,
      title: title,
      body: body,
      data: data,
      image: data[NotificationKeys.image],
      group: data[NotificationKeys.group],
      category: data[NotificationKeys.category],
      channel: data[NotificationKeys.channel],
      sound: data[NotificationKeys.sound],
      badge: int.tryParse(data[NotificationKeys.badge] ?? ''),
      expanded: data[NotificationKeys.expanded] == 'true',
      urgent: data[NotificationKeys.urgent] == 'true',
    );
  }

  /// The same notification keeps the same id, so showing it twice replaces it.
  final String id;
  final String? title;
  final String? body;
  final Map<String, String> data;

  /// An image's address (https) or a file's path.
  final String? image;

  /// Notifications that belong together (a chat's thread), grouped in the bar.
  final String? group;

  /// Which `NotificationCategory` it is: the actions it offers.
  final String? category;

  /// The Android channel it shows on (the display's own when null).
  final String? channel;

  /// A sound bundled with the app (the default when null).
  final String? sound;

  /// The number on the app's icon.
  final int? badge;

  /// A bar of how far something has got (a download, an upload).
  final NotificationProgress? progress;

  /// Stays until the app takes it away (Android); the user can't swipe it away.
  final bool ongoing;

  /// Its whole body shows when expanded.
  final bool expanded;

  /// Breaks through Focus (iOS time-sensitive) and pops up (Android).
  final bool urgent;

  /// Nothing to show: a data-only push.
  bool get silent => (title ?? '').isEmpty && (body ?? '').isEmpty;
}

/// How far something has got: [value] of [max], or [indeterminate] while unknown.
class NotificationProgress {
  const NotificationProgress({this.value = 0, this.max = 100, this.indeterminate = false});

  final int value;
  final int max;
  final bool indeterminate;
}
