import 'dart:async' show TimeoutException;
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:in_app_notifications/in_app_notifications.dart';

/// Pushes through Firebase Cloud Messaging.
class FcmMessagingDelegate implements NotificationMessagingDelegate {
  /// [background]: a push while the app isn't in front, a top-level or static function ([PushBackground.pushed]).
  const FcmMessagingDelegate({this.background});

  final Future<void> Function(RemoteMessage message)? background;

  static FirebaseMessaging get _fcm => FirebaseMessaging.instance;

  static const _timeout = Duration(seconds: 10);

  /// [background] handles a push while the app isn't in front, from now on.
  @override
  Future<void> init() async {
    final background = this.background;
    if (background != null) FirebaseMessaging.onBackgroundMessage(background);
  }

  /// An iPhone has no token until Apple has registered it, which can take a moment after launch: then
  /// [tokenRefreshes] brings it.
  @override
  Future<String?> token() async {
    if (Platform.isIOS) {
      for (var tries = 0; await _fcm.getAPNSToken() == null; tries++) {
        if (tries == 2) return null;
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
    return _fcm.getToken().timeout(_timeout, onTimeout: () => throw TimeoutException('push token'));
  }

  @override
  Stream<String> get tokenRefreshes => _fcm.onTokenRefresh;

  @override
  Future<void> forgetToken() => _fcm.deleteToken().timeout(_timeout);

  @override
  Stream<PushMessage> get received => FirebaseMessaging.onMessage.map(message);

  @override
  Stream<PushMessage> get tapped => FirebaseMessaging.onMessageOpenedApp.map(message);

  @override
  Future<PushMessage?> initial() async {
    final first = await _fcm.getInitialMessage();
    return first == null ? null : message(first);
  }

  /// A push as the package takes it: its data shapes how it shows (an image, a group, a category's actions); a
  /// data-only push carries its title and body in its data.
  static PushMessage message(RemoteMessage m) {
    final data = {
      for (final e in m.data.entries) e.key: '${e.value}',
      // iOS sends a push's category and thread in aps, not in the data.
      if (m.category != null) NotificationKeys.category: m.category!,
      if (m.threadId != null) NotificationKeys.group: m.threadId!,
    };
    return PushMessage.fromData(
      id: m.messageId ?? '${m.sentTime?.millisecondsSinceEpoch}',
      title: m.notification?.title ?? data[NotificationKeys.title],
      body: m.notification?.body ?? data[NotificationKeys.body],
      data: data,
    );
  }
}
