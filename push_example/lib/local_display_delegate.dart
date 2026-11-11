import 'dart:async' show StreamController;
import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:in_app_notifications/in_app_notifications.dart';
import 'package:timezone/timezone.dart' show TZDateTime, UTC;

import 'local_notification_details.dart';

/// A notification on the phone through flutter_local_notifications: a push that comes while the app is open (Android
/// doesn't show one; iOS shows its own, kept away with [systemWhileOpen] false when the app shows it itself), and the
/// app's own, now or scheduled, with an image, a group, actions (from their category), a sound, a badge or progress.
/// A tap or an action comes back as a [NotificationAnswer].
class LocalDisplayDelegate implements NotificationDisplayDelegate {
  /// [systemWhileOpen]: true only with `WhileOpen.bar` (the phone shows a push while the app is open). [background]: an
  /// action answered while the app isn't running ([PushBackground.answered]).
  const LocalDisplayDelegate({required this.systemWhileOpen, this.background});

  final bool systemWhileOpen;
  final void Function(NotificationResponse response)? background;

  /// The small icon in the bar: `res/drawable/ic_stat.png` (white on transparent), the same as AndroidManifest's.
  static const _icon = 'ic_stat';

  static final _plugin = FlutterLocalNotificationsPlugin();
  static final _answers = StreamController<NotificationAnswer>.broadcast();
  static var _categories = <String, NotificationCategory>{};

  static InitializationSettings _settings(Iterable<NotificationCategory> categories) => InitializationSettings(
    android: const AndroidInitializationSettings(_icon),
    // The permission is asked by the app, when it is needed and saying why; never here.
    iOS: DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: LocalNotificationDetails.darwinCategories(categories),
    ),
  );

  @override
  Future<void> init({List<NotificationCategory> categories = const []}) async {
    _categories = {for (final c in categories) c.id: c};
    await _plugin.initialize(
      settings: _settings(categories),
      onDidReceiveNotificationResponse: (r) => _answers.add(answerOf(r.id, r.actionId, r.input, r.payload)),
      onDidReceiveBackgroundNotificationResponse: background,
    );
    await _android?.createNotificationChannel(
      const AndroidNotificationChannel(LocalNotificationDetails.channel, LocalNotificationDetails.channelName, importance: Importance.high),
    );
    await _android?.createNotificationChannel(
      const AndroidNotificationChannel(LocalNotificationDetails.urgentChannel, LocalNotificationDetails.urgentChannelName, importance: Importance.max),
    );
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(alert: systemWhileOpen, badge: true, sound: true);
  }

  /// Android doesn't show a push while the app is open; iOS does by itself.
  @override
  Future<void> show(PushMessage message) async {
    if (Platform.isAndroid) await _show(message);
  }

  /// Android doesn't keep a push that came while open; iOS keeps it in its list by itself.
  @override
  Future<void> keep(PushMessage message) async {
    if (Platform.isAndroid) await _show(message, quiet: true);
  }

  /// A time already gone shows it now. The phone fires it by its own clock: with a server clock, move [at] by how far
  /// the server is ahead of the phone.
  @override
  Future<void> notify(PushMessage message, {DateTime? at, bool quiet = false}) async {
    if (at == null || !at.isAfter(DateTime.now())) return _show(message, quiet: quiet);
    await _plugin.zonedSchedule(
      id: _id(message.id),
      title: message.title,
      body: message.body,
      scheduledDate: TZDateTime.from(at.toUtc(), UTC),
      notificationDetails: await LocalNotificationDetails.of(message, quiet: false, categories: _categories),
      // Inexact: no exact-alarm permission to ask for; Android may move it by a few minutes.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: _payload(message),
    );
  }

  @override
  Future<void> cancel(String id) => cancelShown(_id(id));

  @override
  Stream<NotificationAnswer> get responses => _answers.stream;

  @override
  Future<NotificationAnswer?> initial() async {
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final r = launch?.notificationResponse;
    return launch?.didNotificationLaunchApp == true && r != null ? answerOf(r.id, r.actionId, r.input, r.payload) : null;
  }

  /// Every notification in the bar, the system's and those shown here.
  @override
  Future<void> clearShown() => _plugin.cancelAll();

  /// The notification shown as [id] taken away, from anywhere (a background isolate included). Android 15+ keeps one
  /// answered with a typed reply and ignores a cancel: still there, it is posted again quietly with a timeout of a
  /// moment, which takes it away, then cancelled.
  static Future<void> cancelShown(int id) async {
    await _plugin.cancel(id: id);
    final android = _android;
    if (android == null) return;
    final still = (await android.getActiveNotifications()).any((n) => n.id == id);
    if (!still) return;
    await _plugin.show(
      id: id,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(LocalNotificationDetails.channel, LocalNotificationDetails.channelName, silent: true, timeoutAfter: 1),
      ),
    );
    await _plugin.cancel(id: id);
  }

  /// Shows [message] from anywhere, a background isolate included (a data-only push while the app is closed).
  static Future<void> showNow(PushMessage message, {List<NotificationCategory> categories = const []}) async {
    if (categories.isNotEmpty) _categories = {for (final c in categories) c.id: c};
    await _plugin.initialize(settings: _settings(_categories.values));
    await _show(message);
  }

  /// A tap or an action as the package takes it, from flutter_local_notifications' answer (a background one too).
  static NotificationAnswer answerOf(int? id, String? actionId, String? input, String? payload) {
    var notificationId = '${id ?? ''}';
    var data = const <String, String>{};
    if (payload != null && payload.isNotEmpty) {
      final map = jsonDecode(payload);
      if (map is Map) {
        notificationId = '${map['id'] ?? notificationId}';
        final raw = map['data'];
        if (raw is Map) data = {for (final e in raw.entries) '${e.key}': '${e.value}'};
      }
    }
    return NotificationAnswer(id: notificationId, actionId: (actionId ?? '').isEmpty ? null : actionId, input: input, data: data);
  }

  static Future<void> _show(PushMessage message, {bool quiet = false}) async {
    await _plugin.show(
      id: _id(message.id),
      title: message.title,
      body: message.body,
      notificationDetails: await LocalNotificationDetails.of(message, quiet: quiet, categories: _categories),
      payload: _payload(message),
    );
  }

  /// The same id shown twice replaces itself.
  static int _id(String id) => id.hashCode & 0x7fffffff;

  /// The notification's own id travels with its data, so an answer knows which one it was.
  static String _payload(PushMessage m) => jsonEncode({'id': m.id, 'data': m.data});

  static AndroidFlutterLocalNotificationsPlugin? get _android => _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
}
