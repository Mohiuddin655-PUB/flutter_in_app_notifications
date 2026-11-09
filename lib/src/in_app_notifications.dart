import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;

import 'delegates/display_delegate.dart';
import 'delegates/error_reporter.dart';
import 'delegates/messaging_delegate.dart';
import 'delegates/token_store_delegate.dart';
import 'parts/tokens.dart';

/// Push notifications, with any push service and backend: [setup] once with the app's delegates, [init] at launch,
/// [start] at sign-in and [clear] before sign-out. A tapped push's data waits in [opened] until the app [take]s it.
class InAppNotifications {
  const InAppNotifications._();

  static _Kit? _kit;

  static _Kit get _k => _kit ?? (throw StateError('InAppNotifications.setup must be called first.'));

  /// [unreachable]: the error only says the backend couldn't be reached (offline), so it isn't reported.
  static void setup({
    required MessagingDelegate messaging,
    required DisplayDelegate display,
    required TokenStoreDelegate tokens,
    ErrorReporter? onError,
    bool Function(Object error)? unreachable,
  }) {
    _kit = _Kit(messaging, display, tokens, onError, unreachable);
  }

  /// At launch: shows pushes that come while the app is open, and takes the one whose tap started it.
  static Future<void> init() => _k.init();

  /// [uid] is signed in (a login, or a launch still signed in): its token is kept on the account.
  static void start(String uid) => _k.tokens.start(uid);

  /// Before sign-out or deleting the account, while it may still write: its token is taken off and let go.
  static Future<void> clear() => _k.tokens.clear();

  /// The data of the push last tapped, until [take]n.
  static ValueListenable<Map<String, String>?> get opened => _k.opened;

  /// The tapped push's data, once.
  static Map<String, String>? take() {
    final data = _k.opened.value;
    _k.opened.value = null;
    return data;
  }
}

class _Kit {
  _Kit(this.messaging, this.display, TokenStoreDelegate store, this.onError, this.unreachable) {
    tokens = Tokens(messaging, store, run);
  }

  final MessagingDelegate messaging;
  final DisplayDelegate display;
  final ErrorReporter? onError;
  final bool Function(Object error)? unreachable;
  late final Tokens tokens;
  final opened = ValueNotifier<Map<String, String>?>(null);
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    _ready = true;
    await run(display.init, 'display init');
    messaging.received.listen((message) {
      if (!message.silent) unawaited(run(() => display.show(message), 'show'));
    });
    messaging.tapped.listen((message) => _open(message.data));
    display.tapped.listen(_open);
    await run(() async => _open((await messaging.initial())?.data), 'initial push');
    await run(() async => _open(await display.initial()), 'initial shown push');
  }

  void _open(Map<String, String>? data) {
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
