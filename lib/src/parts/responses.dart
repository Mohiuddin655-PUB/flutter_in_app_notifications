import '../delegates/notification_action_handler.dart';
import '../models/notification_answer.dart';
import 'banner_state.dart';

/// Where an answered notification goes: a plain tap opens its data (`InAppNotifications.opened`); an action goes to
/// the app's handler and to [actions], for a screen that wants to know.
class Responses {
  Responses(this._banner, this._run);

  final BannerState _banner;
  final Future<bool> Function(Future<void> Function() step, String where) _run;

  NotificationActionHandler? handler;

  /// Done once the app's handler is.
  Future<void> handle(NotificationAnswer response) async {
    if (response.tapped) return _banner.open(response.data);
    _banner.actions.add(response);
    final handle = handler;
    if (handle != null) await _run(() => handle(response), 'action ${response.actionId}');
  }
}
