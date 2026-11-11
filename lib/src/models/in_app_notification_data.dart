import '../../keys/notification_keys.dart';
import '../in_app_notifications.dart';
import 'notification_action.dart';
import 'push_message.dart';

/// What `InAppNotificationHost`'s builder gets to draw the in-app notification with: the message, its actions, the
/// time it has left, and what to call. How it looks is entirely the app's.
class InAppNotificationData {
  const InAppNotificationData({required this.message, required this.remaining});

  /// Its title, body, image and data.
  final PushMessage message;

  /// The time it has left on screen, from 1 (just shown) to 0 (going): a progress bar's value. It stops while held.
  final double remaining;

  /// The look the app gave it (`show(look:)`, or a push's `look` in its data), to pick its design; null when none.
  String? get look => message.data[NotificationKeys.look];

  List<NotificationAction> get _actions => InAppNotifications.category(message.category)?.actions ?? const [];

  /// Its category's actions shown as buttons (Accept, Reject).
  List<NotificationAction> get buttons => [for (final a in _actions) if (!a.input) a];

  /// Its category's reply action, if it has one: draw a text field for it.
  NotificationAction? get reply => _actions.where((a) => a.input).firstOrNull;

  /// Opens it (the host does it on a tap): it goes, and its data waits in `InAppNotifications.opened`.
  void open() => InAppNotifications.open();

  /// Takes it away (a close button; the host does it on a swipe).
  void dismiss() => InAppNotifications.dismiss();

  /// A button pressed, or a reply sent with [input].
  void answer(String actionId, {String? input}) => InAppNotifications.answer(actionId, input: input);

  /// True stops its time; false lets it go on. The host already does it for a finger on it and a text field typed in:
  /// this is for anything else of the app's (a menu open on it, say).
  void hold(bool on) => InAppNotifications.hold(on, reason: ('app', message.id));
}
