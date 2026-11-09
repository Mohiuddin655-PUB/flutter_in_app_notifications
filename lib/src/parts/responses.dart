import 'dart:async' show StreamController;

import '../delegates/notification_action_handler.dart';
import '../models/notification_answer.dart';

/// Where an answered notification goes: a plain tap opens its data (`InAppNotifications.opened`); an action goes to
/// the app's handler and to [actions], for a screen that wants to know.
class Responses {
  Responses(this._open, this._run);

  final void Function(Map<String, String>? data) _open;
  final Future<bool> Function(Future<void> Function() step, String where) _run;

  NotificationActionHandler? handler;
  final _actions = StreamController<NotificationAnswer>.broadcast();

  Stream<NotificationAnswer> get actions => _actions.stream;

  /// Done once the app's handler is.
  Future<void> handle(NotificationAnswer response) async {
    if (response.tapped) return _open(response.data);
    _actions.add(response);
    final handle = handler;
    if (handle != null) await _run(() => handle(response), 'action ${response.actionId}');
  }
}
