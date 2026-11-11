import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:in_app_notifications/in_app_notifications.dart';

import 'fcm_messaging_delegate.dart';
import 'local_display_delegate.dart';

/// Notifications while the app isn't in front, each in a background isolate: a data-only push shown by the app itself
/// (on Android the system shows only plain pushes, so one with actions or an image comes data-only), and an action
/// answered without opening the app.
// Native code calls into this class from a background isolate: the class needs the pragma too, not only its methods.
@pragma('vm:entry-point')
abstract final class PushBackground {
  /// The app's kinds of notification and their actions, fixed in code: a background isolate has none of what the app
  /// sets at runtime. Change them to the app's own.
  static const categories = [
    NotificationCategory(
      id: 'chat',
      actions: [NotificationAction(id: 'reply', title: 'Reply', input: true, inputHint: 'Message', inputButton: 'Send')],
    ),
    NotificationCategory(
      id: 'request',
      actions: [
        NotificationAction(id: 'accept', title: 'Accept'),
        NotificationAction(id: 'reject', title: 'Reject', destructive: true),
      ],
    ),
  ];

  /// What the app does with an action, while it runs or answered without opening it (a reply, Accept). It may run in
  /// a background isolate, with none of the app's state: it sets up what it needs itself.
  @pragma('vm:entry-point')
  static Future<void> onAction(NotificationAnswer a) async {
    await _firebase();
    switch (a.actionId) {
      case 'reply':
      // send a.input to the chat in a.data
      case 'accept':
      // accept the request in a.data
      case 'reject':
      // reject it
    }
  }

  static Future<void> _firebase() async {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
  }

  /// A push that came while the app wasn't in front.
  @pragma('vm:entry-point')
  static Future<void> pushed(RemoteMessage m) async {
    // A plain push the system showed itself; a data-only one with nothing to say is for the app's own use.
    final message = FcmMessagingDelegate.message(m);
    if (m.notification != null || message.silent) return;
    await _firebase();
    await LocalDisplayDelegate.showNow(message, categories: categories);
  }

  /// An action answered on a notification while the app wasn't running.
  @pragma('vm:entry-point')
  static Future<void> answered(NotificationResponse r) async {
    // Answered: it goes (Android leaves one answered with a reply on screen); the package does it when the app runs.
    if (r.id != null) await LocalDisplayDelegate.cancelShown(r.id!);
    await onAction(LocalDisplayDelegate.answerOf(r.id, r.actionId, r.input, r.payload));
    // Android holds one answered with a typed reply a moment and ignores a cancel made at once: again after.
    if (r.id != null && r.input != null) {
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      await LocalDisplayDelegate.cancelShown(r.id!);
    }
  }
}
