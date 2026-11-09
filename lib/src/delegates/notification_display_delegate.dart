import '../models/push_message.dart';

/// Shows a push on the phone while the app is open, given by the app (a local notifications plugin, say).
abstract interface class NotificationDisplayDelegate {
  /// Once, before anything is shown (channels, permissions already asked elsewhere).
  Future<void> init();

  /// [message] shown; nothing where the platform shows it by itself (iOS).
  Future<void> show(PushMessage message);

  /// The data of each shown push that is tapped.
  Stream<Map<String, String>> get tapped;

  /// The data of the shown push whose tap started the app; null when none did.
  Future<Map<String, String>?> initial();

  /// Every push the phone still shows for this app taken away (sign-out), so none is tapped for the next account.
  Future<void> clearShown();
}
