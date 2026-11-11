import '../models/notification_action.dart';
import '../models/notification_answer.dart';
import '../models/push_message.dart';

/// Shows a push on the phone while the app is open, given by the app (a local notifications plugin, say).
abstract interface class NotificationDisplayDelegate {
  /// Once, before anything is shown: [categories] are the actions notifications may offer (iOS must register them
  /// first; Android reads them when showing one).
  Future<void> init({List<NotificationCategory> categories = const []});

  /// [message] shown; nothing where the platform shows it by itself (iOS).
  Future<void> show(PushMessage message);

  /// Each notification it showed that is tapped or answered with an action, while the app runs.
  Stream<NotificationAnswer> get responses;

  /// The answer that started the app (a tap, or an action that opens it); null when none did.
  Future<NotificationAnswer?> initial();

  /// Every push the phone still shows for this app taken away (sign-out), so none is tapped for the next account.
  Future<void> clearShown();

  /// A notification made on the phone, in the notification bar on every platform: now, or at [at] when given (a time
  /// already gone shows it now). The same [PushMessage.id] replaces one shown or waiting. [quiet]: into the bar without
  /// popping up or sounding, as the app shows its own in-app notification for it. [at] is read by `setup(now:)`'s clock
  /// (the server's, say); the phone's alarm goes by its own, so a display whose clocks differ moves it by the
  /// difference.
  Future<void> notify(PushMessage message, {DateTime? at, bool quiet = false});

  /// A push that came while the app is open, which the app shows itself (`WhileOpen.inApp`): kept in
  /// the notification bar without popping up (Android), or nothing where the platform keeps it itself (iOS, its list).
  Future<void> keep(PushMessage message);

  /// The notification made on the phone with [id] taken away, shown or still waiting.
  Future<void> cancel(String id);
}
