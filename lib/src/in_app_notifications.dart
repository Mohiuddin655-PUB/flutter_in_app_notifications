import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:flutter/widgets.dart' show AppLifecycleListener;

import 'delegates/notification_display_delegate.dart';
import 'delegates/error_reporter.dart';
import 'delegates/notification_messaging_delegate.dart';
import 'delegates/schedule_store_delegate.dart';
import 'delegates/token_store_delegate.dart';
import 'enums/local_notification_visibility.dart';
import 'models/push_message.dart';
import 'parts/schedules.dart';
import 'parts/tokens.dart';

/// Push notifications, with any push service and backend: [setup] once with the app's delegates, [init] at launch,
/// [start] at sign-in and [clear] before sign-out. A tapped push's data waits in [opened] until the app [take]s it.
class InAppNotifications {
  const InAppNotifications._();

  static _Kit? _kit;

  static _Kit get _k => _kit ?? (throw StateError('InAppNotifications.setup must be called first.'));

  /// [visibility]: where a notification that comes while the app is open shows, push or made on the phone.
  /// [schedules]: where scheduled notifications are kept, so one whose time comes while the app is open shows inside it
  /// too; without it the phone shows them by itself. [now]: the clock scheduled times are read by (the server's, say).
  /// [unreachable]: the error only says the backend couldn't be reached (offline), so it isn't reported.
  static void setup({
    required NotificationMessagingDelegate messaging,
    required NotificationDisplayDelegate display,
    required TokenStoreDelegate tokens,
    ScheduleStoreDelegate? schedules,
    LocalNotificationVisibility visibility = LocalNotificationVisibility.system,
    DateTime Function()? now,
    ErrorReporter? onError,
    bool Function(Object error)? unreachable,
  }) {
    _kit = _Kit(messaging, display, tokens, schedules, visibility, now ?? DateTime.now, onError, unreachable);
  }

  /// At launch: shows pushes that come while the app is open, and takes the one whose tap started it.
  static Future<void> init() => _k.init();

  /// [uid] is signed in (a login, or a launch still signed in): its token is kept on the account.
  static void start(String uid) => _k.tokens.start(uid);

  /// Before sign-out or deleting the account, while it may still write: its token is taken off and let go, and what it
  /// was told goes with it (a tapped push not yet taken, the one showing inside the app, those in the notification bar).
  static Future<void> clear() => _k.clear();

  /// The data of the push last tapped, until [take]n.
  static ValueListenable<Map<String, String>?> get opened => _k.opened;

  /// A notification made on the phone (a reminder, say), in the notification bar: now, at [at] (a plain time, such as
  /// `DateTime(2026, 11, 10, 10)` for 10am), or [after] a while (scheduled; it shows even when the app is closed).
  /// Times are read by `setup(now:)`'s clock, and the display delegate turns them into the phone's. [id] names it, to replace or [cancel] it; a tap puts [data] in [opened], as a push's.
  /// False when it couldn't be made.
  /// While the app is open, with [LocalNotificationVisibility.inApp], it shows inside the app and goes into the bar
  /// quietly, as a push does.
  static Future<bool> notify({
    required String id,
    String? title,
    String? body,
    Map<String, String> data = const {},
    DateTime? at,
    Duration? after,
  }) {
    final message = PushMessage(id: id, title: title, body: body, data: data);
    final when = at ?? (after == null ? null : _k.now().add(after));
    if (when != null && when.isAfter(_k.now())) return _k.run(() => _k.schedules.add(message, when), 'schedule');
    return _k.run(() async => _k.present(message, local: true), 'notify');
  }

  /// The notification made on the phone with [id] taken away, shown or still waiting.
  static Future<bool> cancel(String id) => _k.run(() async {
    await _k.schedules.remove(id);
    await _k.display.cancel(id);
  }, 'cancel');

  /// With [LocalNotificationVisibility.inApp]: the push to show inside the app now (the newest), until [open]ed or
  /// [dismiss]ed.
  static ValueListenable<PushMessage?> get inApp => _k.inApp;

  /// The push shown inside the app was tapped: it goes, and its data waits in [opened].
  static void open() {
    final message = _k.inApp.value;
    _k.inApp.value = null;
    _k.open(message?.data);
    // Seen: its copy in the notification bar goes too.
    if (message != null) unawaited(_k.run(() => _k.display.cancel(message.id), 'cancel opened'));
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
  _Kit(
    this.messaging,
    this.display,
    TokenStoreDelegate store,
    ScheduleStoreDelegate? scheduleStore,
    this.visibility,
    this.now,
    this.onError,
    this.unreachable,
  ) {
    tokens = Tokens(messaging, store, run);
    schedules = Schedules(display, scheduleStore, now, run, (message) => unawaited(run(() => present(message, local: true), 'due')));
  }

  final NotificationMessagingDelegate messaging;
  final NotificationDisplayDelegate display;
  final LocalNotificationVisibility visibility;
  final DateTime Function() now;
  final ErrorReporter? onError;
  final bool Function(Object error)? unreachable;
  late final Tokens tokens;
  late final Schedules schedules;
  bool _onScreen = true;
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
    // The app on screen or not, for schedules and for where a notification shows.
    AppLifecycleListener(
      onShow: () {
        _onScreen = true;
        unawaited(run(schedules.shown, 'shown'));
      },
      onHide: () {
        _onScreen = false;
        unawaited(run(schedules.hidden, 'hidden'));
      },
    );
    await run(schedules.load, 'load schedules');
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
