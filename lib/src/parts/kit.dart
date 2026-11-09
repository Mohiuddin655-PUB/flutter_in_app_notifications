import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter/widgets.dart' show AppLifecycleListener;

import '../delegates/error_reporter.dart';
import '../delegates/notification_display_delegate.dart';
import '../delegates/notification_messaging_delegate.dart';
import '../delegates/schedule_store_delegate.dart';
import '../delegates/token_store_delegate.dart';
import '../enums/local_notification_visibility.dart';
import '../models/notification_action.dart';
import '../models/notification_answer.dart';
import '../models/push_message.dart';
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
    this.visibility,
    this.now,
    this.onError,
    this.unreachable,
  ) {
    tokens = Tokens(messaging, store, run);
    categories = {for (final c in categoryList) c.id: c};
    responses = Responses(open, run);
    schedules = Schedules(display, scheduleStore, now, run, (message) => unawaited(run(() => present(message, local: true), 'due')));
  }

  final NotificationMessagingDelegate messaging;
  final NotificationDisplayDelegate display;
  final LocalNotificationVisibility visibility;
  final DateTime Function() now;
  final ErrorReporter? onError;
  final bool Function(Object error)? unreachable;
  late final Tokens tokens;
  late final Map<String, NotificationCategory> categories;
  late final Responses responses;
  late final Schedules schedules;
  bool _onScreen = true;
  final opened = ValueNotifier<Map<String, String>?>(null);
  final inApp = ValueNotifier<PushMessage?>(null);

  /// The app's banner is being used (a reply typed, a finger on it): it doesn't go by itself until every reason has
  /// let go.
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

  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    _ready = true;
    await run(() => display.init(categories: categories.values.toList()), 'display init');
    messaging.received.listen(_received);
    messaging.tapped.listen((message) => open(message.data));
    display.responses.listen(answered);
    await run(() => NativeActions.listen(responses.handle), 'push actions');
    await run(() async => open((await messaging.initial())?.data), 'initial push');
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
    opened.value = null;
    inApp.value = null;
    await run(schedules.clear, 'clear schedules');
    await run(display.clearShown, 'clear shown');
    await tokens.clear();
  }

  void _received(PushMessage message) {
    if (!message.silent) unawaited(run(() => present(message, local: false), 'show'));
  }

  /// A notification due now while the app may be open: with [LocalNotificationVisibility.inApp] and the app on screen,
  /// inside the app and quietly into the notification bar; otherwise as the platform shows it. [local]: made on the
  /// phone, so the bar's copy is made here; a push's is the system's (or the display's, on Android while open).
  Future<void> present(PushMessage message, {required bool local}) async {
    if (visibility == LocalNotificationVisibility.inApp && _onScreen) {
      inApp.value = message;
      await (local ? display.notify(message, quiet: true) : display.keep(message));
    } else {
      await (local ? display.notify(message) : display.show(message));
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
