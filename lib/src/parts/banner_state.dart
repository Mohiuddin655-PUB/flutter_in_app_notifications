import 'dart:async' show StreamController;

import 'package:flutter/foundation.dart' show ValueNotifier;

import '../models/notification_action.dart';
import '../models/notification_answer.dart';
import '../models/push_message.dart';

/// The app's banner and what it is told, there whether or not `InAppNotifications.setup` ran: an app that only uses
/// the banner (`show()`) needs nothing else. The app draws [inApp] where it shows its overlays.
class BannerState {
  BannerState._();

  /// The one there is.
  static final i = BannerState._();

  /// The message showing in the banner, until opened or dismissed; a new one replaces it.
  final inApp = ValueNotifier<PushMessage?>(null);

  /// [message] in the banner, replacing the one showing.
  void present(PushMessage message) => inApp.value = message;

  /// The data of the one last tapped (a banner or a notification), until taken.
  final opened = ValueNotifier<Map<String, String>?>(null);

  /// Each action answered (a reply, Accept), on the banner or a notification.
  final actions = StreamController<NotificationAnswer>.broadcast();

  /// What each kind offers, by id: from `setup(categories:)` or `InAppNotifications.categories`.
  final categories = <String, NotificationCategory>{};

  /// The banner is in use (a reply typed, a finger on it): it doesn't go by itself until every reason has let go.
  final holding = ValueNotifier<bool>(false);
  final _holds = <Object>{};

  void hold(Object reason, bool on) {
    on ? _holds.add(reason) : _holds.remove(reason);
    holding.value = _holds.isNotEmpty;
  }

  void releaseAll() {
    _holds.clear();
    holding.value = false;
  }

  /// Sign-out: nothing of the last account's stays (its tapped one, its banner).
  void clear() {
    opened.value = null;
    releaseAll();
    inApp.value = null;
  }

  void open(Map<String, String>? data) {
    if (data != null && data.isNotEmpty) opened.value = data;
  }
}
