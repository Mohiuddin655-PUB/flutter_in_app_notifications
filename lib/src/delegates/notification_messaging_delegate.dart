import '../models/push_message.dart';

/// The push service, given by the app (Firebase Cloud Messaging, say).
abstract interface class NotificationMessagingDelegate {
  /// At `InAppNotifications.init`, first: what the push service needs before anything else (its handler for a push
  /// while the app isn't in front, say).
  Future<void> init();

  /// This phone's token now; null while it has none yet.
  Future<String?> token();

  /// Each new token the phone is given in place of the one before.
  Stream<String> get tokenRefreshes;

  /// The token let go: pushes to it stop, and the next one asked for is new.
  Future<void> forgetToken();

  /// Each push that comes while the app is open.
  Stream<PushMessage> get received;

  /// Each push tapped while the app was in the background.
  Stream<PushMessage> get tapped;

  /// The push whose tap started the app; null when none did.
  Future<PushMessage?> initial();
}
