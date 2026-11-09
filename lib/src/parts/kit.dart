import 'dart:async' show unawaited;

import 'package:flutter/widgets.dart' show AppLifecycleListener;

import '../delegates/error_reporter.dart';
import '../delegates/notification_display_delegate.dart';
import '../delegates/notification_messaging_delegate.dart';
import '../delegates/schedule_store_delegate.dart';
import '../delegates/token_store_delegate.dart';
import '../enums/while_open.dart';
import '../models/notification_action.dart';
import '../models/notification_answer.dart';
import '../models/push_message.dart';
import 'banner_state.dart';
import 'native_actions.dart';
import 'responses.dart';
import 'schedules.dart';
import 'tokens.dart';

/// The kit's state behind `InAppNotifications`: its delegates, parts and what the app is told.
class Kit {
  Kit(
    this.messaging,
    this.display,
    TokenStoreDelegate store,
    ScheduleStoreDelegate? scheduleStore,
    List<NotificationCategory> categoryList,
    this.banner,
    this.whileOpen,
    this.now,
    this.onError,
    this.unreachable,
  ) {
    tokens = Tokens(messaging, store, run);
    banner.categories
      ..clear()
      ..addAll({for (final c in categoryList) c.id: c});
    responses = Responses(banner, run);
    schedules = Schedules(display, scheduleStore, now, run, (message) => unawaited(run(() => present(message, local: true), 'due')));
  }

  final NotificationMessagingDelegate messaging;
  final NotificationDisplayDelegate display;
  final BannerState banner;
  final WhileOpen whileOpen;
  final DateTime Function() now;
  final ErrorReporter? onError;
  final bool Function(Object error)? unreachable;
  late final Tokens tokens;
  late final Responses responses;
  late final Schedules schedules;
  bool _onScreen = true;

  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    _ready = true;
    await run(() => display.init(categories: banner.categories.values.toList()), 'display init');
    messaging.received.listen(_received);
    messaging.tapped.listen((message) => banner.open(message.data));
    display.responses.listen(answered);
    await run(() => NativeActions.listen(responses.handle), 'push actions');
    await run(() => NativeActions.keepInList(whileOpen.keepsInBar), 'keep in list');
    await run(() async => banner.open((await messaging.initial())?.data), 'initial push');
    await run(() async {
      final first = await display.initial();
      if (first != null) responses.handle(first);
    }, 'initial shown push');
    // The app in front or not, for schedules and for where a notification shows. Not in front starts at inactive (the
    // app switcher, the notification shade), not hidden: an app swiped away from the switcher is never hidden first, so
    // a schedule left on a timer here would be lost.
    AppLifecycleListener(
      onResume: () {
        _onScreen = true;
        unawaited(run(schedules.shown, 'shown'));
      },
      onInactive: () {
        if (!_onScreen) return;
        _onScreen = false;
        unawaited(run(schedules.hidden, 'hidden'));
      },
    );
    await run(schedules.load, 'load schedules');
  }

  /// How long after a typed reply its notification is taken away once more (Android holds it a moment).
  static const replyCancelDelay = Duration(milliseconds: 1500);

  /// An answer on a notification: an action's notification goes (Android leaves one answered with a reply on screen),
  /// then the answer is handled.
  Future<void> answered(NotificationAnswer answer) async {
    if (!answer.tapped) {
      unawaited(run(() => display.cancel(answer.id), 'cancel answered'));
      unawaited(run(() => NativeActions.removePush(answer.id), 'remove answered push'));
      // Android keeps one answered with a typed reply a moment longer and ignores a cancel made at once: again after.
      if (answer.input != null) {
        unawaited(Future<void>.delayed(replyCancelDelay, () => run(() => display.cancel(answer.id), 'cancel replied')));
      }
    }
    await responses.handle(answer);
  }

  Future<void> clear() async {
    banner.clear();
    await run(schedules.clear, 'clear schedules');
    await run(display.clearShown, 'clear shown');
    await tokens.clear();
  }

  void _received(PushMessage message) {
    if (!message.silent) unawaited(run(() => present(message, local: false), 'show'));
  }

  /// A notification due now while the app may be open: in front, as [whileOpen] says (the app's banner, a quiet copy
  /// in the bar, or the bar alone); otherwise as the platform shows it. [local]: made on the phone, so the bar's copy is
  /// made here; a push's is the system's (or the display's, on Android while open).
  Future<void> present(PushMessage message, {required bool local}) async {
    if (!_onScreen || !whileOpen.inApp) {
      await (local ? display.notify(message) : display.show(message));
      return;
    }
    // A hold stays with the banner that has it: one in use (a reply typed) and replaced lets go as it goes.
    banner.inApp.value = message;
    if (whileOpen.keepsInBar) await (local ? display.notify(message, quiet: true) : display.keep(message));
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
