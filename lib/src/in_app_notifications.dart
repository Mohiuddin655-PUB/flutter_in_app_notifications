import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;

import 'delegates/notification_display_delegate.dart';
import 'delegates/error_reporter.dart';
import 'delegates/notification_messaging_delegate.dart';
import 'delegates/token_store_delegate.dart';
import 'enums/local_notification_visibility.dart';
import 'models/push_message.dart';
import 'parts/tokens.dart';

/// Push notifications, with any push service and backend: [setup] once with the app's delegates, [init] at launch,
/// [start] at sign-in and [clear] before sign-out. A tapped push's data waits in [opened] until the app [take]s it.
class InAppNotifications {
  const InAppNotifications._();

  static _Kit? _kit;

  static _Kit get _k => _kit ?? (throw StateError('InAppNotifications.setup must be called first.'));

  /// [visibility]: where a push that comes while the app is open shows. [unreachable]: the error only says the backend
  /// couldn't be reached (offline), so it isn't reported.
  static void setup({
    required NotificationMessagingDelegate messaging,
    required NotificationDisplayDelegate display,
    required TokenStoreDelegate tokens,
    LocalNotificationVisibility visibility = LocalNotificationVisibility.system,
    ErrorReporter? onError,
    bool Function(Object error)? unreachable,
  }) {
    _kit = _Kit(messaging, display, tokens, visibility, onError, unreachable);
  }

  /// At launch: shows pushes that come while the app is open, and takes the one whose tap started it.
  static Future<void> init() => _k.init();

  /// [uid] is signed in (a login, or a launch still signed in): its token is kept on the account.
  static void start(String uid) => _k.tokens.start(uid);

  /// Before sign-out or deleting the account, while it may still write: its token is taken off and let go.
  static Future<void> clear() => _k.tokens.clear();

  /// The data of the push last tapped, until [take]n.
  static ValueListenable<Map<String, String>?> get opened => _k.opened;

  /// With [LocalNotificationVisibility.inApp]: the push to show inside the app now (the newest), until [open]ed or
  /// [dismiss]ed.
  static ValueListenable<PushMessage?> get inApp => _k.inApp;

  /// The push shown inside the app was tapped: it goes, and its data waits in [opened].
  static void open() {
    final message = _k.inApp.value;
    _k.inApp.value = null;
    _k.open(message?.data);
  }

  /// The push shown inside the app goes untapped.
  static void dismiss() => _k.inApp.value = null;

  /// The tapped push's data, once.
  static Map<String, String>? take() {
    final data = _k.opened.value;
    _k.opened.value = null;
    return data;
  }
}

class _Kit {
  _Kit(this.messaging, this.display, TokenStoreDelegate store, this.visibility, this.onError, this.unreachable) {
    tokens = Tokens(messaging, store, run);
  }

  final NotificationMessagingDelegate messaging;
  final NotificationDisplayDelegate display;
  final LocalNotificationVisibility visibility;
  final ErrorReporter? onError;
  final bool Function(Object error)? unreachable;
  late final Tokens tokens;
  final opened = ValueNotifier<Map<String, String>?>(null);
  final inApp = ValueNotifier<PushMessage?>(null);
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    _ready = true;
    await run(display.init, 'display init');
    messaging.received.listen(_received);
    messaging.tapped.listen((message) => open(message.data));
    display.tapped.listen(open);
    await run(() async => open((await messaging.initial())?.data), 'initial push');
    await run(() async => open(await display.initial()), 'initial shown push');
  }

  void _received(PushMessage message) {
    if (message.silent) return;
    switch (visibility) {
      case LocalNotificationVisibility.system:
        unawaited(run(() => display.show(message), 'show'));
      case LocalNotificationVisibility.inApp:
        inApp.value = message;
    }
  }

  void open(Map<String, String>? data) {
    if (data != null && data.isNotEmpty) opened.value = data;
  }

  Future<bool> run(Future<void> Function() step, String where) async {
    try {
      await step();
      return true;
    } catch (error, stack) {
      if (!(unreachable?.call(error) ?? false)) onError?.call(error, stack, where);
      return false;
    }
  }
}
