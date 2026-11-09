import 'dart:async' show StreamController;

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter/painting.dart' show EdgeInsetsGeometry;

import '../enums/banner_edge.dart';

import '../models/notification_action.dart';
import '../models/notification_answer.dart';
import '../models/push_message.dart';

/// The app's banner and what it is told, there whether or not `InAppNotifications.setup` ran: an app that only uses
/// the banner (`show()`) needs nothing else.
class BannerState {
  BannerState._();

  /// The one there is: `InAppNotifications` and the gate share it.
  static final i = BannerState._();

  /// The message showing in the banner, until opened or dismissed: the main lane's.
  final inApp = ValueNotifier<PushMessage?>(null);

  /// The other lanes (a toast's), by name: each shows its own message beside the main banner, without replacing it.
  final _lanes = <String, ValueNotifier<PushMessage?>>{};

  /// Which lane each look shows in, set by the gate from its looks (`BannerLook.lane`); a look not here is the main
  /// lane's.
  final laneOfLook = <String, String>{};

  /// How a message was asked to show by `show()` (its time, edge, padding), kept with that message.
  final placement = Expando<BannerPlacement>();

  /// The lane named [name]; the main one when null.
  ValueNotifier<PushMessage?> lane(String? name) => name == null ? inApp : _lanes.putIfAbsent(name, () => ValueNotifier(null));

  /// [message] shown in its look's lane, replacing only that lane's.
  void present(PushMessage message) => lane(laneOfLook[message.look]).value = message;

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
    for (final lane in _lanes.values) {
      lane.value = null;
    }
  }

  void open(Map<String, String>? data) {
    if (data != null && data.isNotEmpty) opened.value = data;
  }
}

/// How one message shows, asked by `show()`: [showFor], [edge] and [padding] in place of its look's.
typedef BannerPlacement = ({Duration? showFor, BannerEdge? edge, EdgeInsetsGeometry? padding});
