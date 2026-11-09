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
    this.look,
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
      look: data[NotificationKeys.look],
    );
  }

  /// The same notification with what is given changed.
  PushMessage copyWith({
    String? id,
    String? title,
    String? body,
    Map<String, String>? data,
    String? image,
    String? group,
    String? category,
    String? channel,
    String? sound,
    int? badge,
    NotificationProgress? progress,
    bool? ongoing,
    bool? expanded,
    bool? urgent,
    String? look,
  }) {
    return PushMessage(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      data: data ?? this.data,
      image: image ?? this.image,
      group: group ?? this.group,
      category: category ?? this.category,
      channel: channel ?? this.channel,
      sound: sound ?? this.sound,
      badge: badge ?? this.badge,
      progress: progress ?? this.progress,
      ongoing: ongoing ?? this.ongoing,
      expanded: expanded ?? this.expanded,
      urgent: urgent ?? this.urgent,
      look: look ?? this.look,
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

  /// The name of the banner look it shows in (`InAppNotificationGate.looks`: 'toast', 'popup'); the gate's own when
  /// null.
  final String? look;

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
