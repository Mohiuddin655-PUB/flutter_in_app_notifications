import 'dart:io' show Directory, File, HttpClient;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:in_app_notifications/in_app_notifications.dart';

/// How a [PushMessage] shows on each platform, through flutter_local_notifications: its image, group, actions (from
/// its [NotificationCategory]), sound, badge, progress and urgency.
abstract final class LocalNotificationDetails {
  /// The Android channels: change their ids and names to the app's own (the default one is also
  /// `default_notification_channel_id` in AndroidManifest.xml).
  static const channel = 'updates';
  static const channelName = 'Notifications';
  static const urgentChannel = 'urgent';
  static const urgentChannelName = 'Urgent';

  /// iOS must know every category, with its actions, before a notification names one.
  static List<DarwinNotificationCategory> darwinCategories(Iterable<NotificationCategory> categories) => [
    for (final c in categories)
      DarwinNotificationCategory(
        c.id,
        actions: [
          for (final a in c.actions)
            a.input
                ? DarwinNotificationAction.text(a.id, a.title, buttonTitle: a.inputButton ?? a.title, placeholder: a.inputHint, options: _options(a))
                : DarwinNotificationAction.plain(a.id, a.title, options: _options(a)),
        ],
      ),
  ];

  static Set<DarwinNotificationActionOption> _options(NotificationAction a) => {
    if (a.destructive) DarwinNotificationActionOption.destructive,
    if (a.opensApp) DarwinNotificationActionOption.foreground,
  };

  /// [quiet]: into the bar or list only, without popping up or sounding (the app shows it inside itself).
  static Future<NotificationDetails> of(PushMessage m, {required bool quiet, required Map<String, NotificationCategory> categories}) async {
    final image = await _file(m.image);
    final category = categories[m.category];
    final body = m.body ?? '';
    final StyleInformation? style = image != null
        ? BigPictureStyleInformation(FilePathAndroidBitmap(image), contentTitle: m.title, summaryText: body)
        : m.expanded
        ? BigTextStyleInformation(body, contentTitle: m.title)
        : null;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        m.channel ?? (m.urgent ? urgentChannel : channel),
        m.urgent ? urgentChannelName : channelName,
        importance: m.urgent ? Importance.max : Importance.high,
        priority: m.urgent ? Priority.max : Priority.high,
        silent: quiet,
        styleInformation: style,
        largeIcon: image == null ? null : FilePathAndroidBitmap(image),
        groupKey: m.group,
        sound: m.sound == null ? null : RawResourceAndroidNotificationSound(m.sound),
        number: m.badge,
        ongoing: m.ongoing,
        showProgress: m.progress != null,
        maxProgress: m.progress?.max ?? 0,
        progress: m.progress?.value ?? 0,
        indeterminate: m.progress?.indeterminate ?? false,
        actions: [
          for (final a in category?.actions ?? const <NotificationAction>[])
            AndroidNotificationAction(
              a.id,
              a.title,
              showsUserInterface: a.opensApp,
              inputs: a.input ? [AndroidNotificationActionInput(label: a.inputHint)] : const [],
            ),
        ],
      ),
      iOS: DarwinNotificationDetails(
        presentBanner: !quiet,
        presentList: true,
        presentSound: !quiet,
        presentBadge: true,
        threadIdentifier: m.group,
        categoryIdentifier: m.category,
        sound: m.sound,
        badgeNumber: m.badge,
        interruptionLevel: m.urgent ? InterruptionLevel.timeSensitive : InterruptionLevel.active,
        attachments: image == null ? null : [DarwinNotificationAttachment(image)],
      ),
    );
  }

  /// An image's address downloaded to a file (the platforms show only files); a path is used as it is. Null when it
  /// can't be had: the notification shows without it.
  static Future<String?> _file(String? image) async {
    if (image == null || image.isEmpty) return null;
    if (!image.startsWith('http')) return image;
    try {
      final file = File('${Directory.systemTemp.path}/push_${image.hashCode & 0x7fffffff}');
      if (await file.exists()) return file.path;
      final request = await HttpClient().getUrl(Uri.parse(image)).timeout(const Duration(seconds: 10));
      final response = await request.close().timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      await response.pipe(file.openWrite());
      return file.path;
    } catch (_) {
      return null;
    }
  }
}
