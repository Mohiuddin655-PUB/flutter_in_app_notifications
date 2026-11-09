import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show ValueListenable;

import 'delegates/notification_action_handler.dart';
import 'delegates/notification_display_delegate.dart';
import 'delegates/error_reporter.dart';
import 'delegates/notification_messaging_delegate.dart';
import 'delegates/schedule_store_delegate.dart';
import 'delegates/token_store_delegate.dart';
import 'enums/local_notification_visibility.dart';
import 'models/notification_action.dart';
import 'models/notification_answer.dart';
import 'models/push_message.dart';
import 'parts/kit.dart';
import 'parts/native_actions.dart';

/// Push notifications, with any push service and backend: [setup] once with the app's delegates, [init] at launch,
/// [start] at sign-in and [clear] before sign-out. A tapped push's data waits in [opened] until the app [take]s it.
class InAppNotifications {
  const InAppNotifications._();

  static Kit? _kit;

  static Kit get _k => _kit ?? (throw StateError('InAppNotifications.setup must be called first.'));

  /// [visibility]: where a notification that comes while the app is open shows, push or made on the phone.
  /// [schedules]: where scheduled notifications are kept, so one whose time comes while the app is open shows inside it
  /// too; without it the phone shows them by itself. [now]: the clock scheduled times are read by (the server's, say).
  /// [unreachable]: the error only says the backend couldn't be reached (offline), so it isn't reported.
  static void setup({
    required NotificationMessagingDelegate messaging,
    required NotificationDisplayDelegate display,
    required TokenStoreDelegate tokens,
    ScheduleStoreDelegate? schedules,
    List<NotificationCategory> categories = const [],
    NotificationActionHandler? onAction,
    LocalNotificationVisibility visibility = LocalNotificationVisibility.system,
    DateTime Function()? now,
    ErrorReporter? onError,
    bool Function(Object error)? unreachable,
  }) {
    _kit = Kit(messaging, display, tokens, schedules, categories, visibility, now ?? DateTime.now, onError, unreachable)
      ..responses.handler = onAction;
  }

  /// Each action answered on a notification while the app runs (a reply, Accept), after `setup(onAction:)` has it.
  static Stream<NotificationAnswer> get actions => _k.responses.actions;

  /// An action from the app's own banner (`InAppNotificationGate`): handled as if answered on the notification, and
  /// the banner and its copy in the bar go.
  static void answer(String actionId, {String? input}) {
    final message = _k.inApp.value;
    if (message == null) return;
    _k.holding.value = false;
    _k.inApp.value = null;
    unawaited(_k.run(() => _k.display.cancel(message.id), 'cancel answered'));
    unawaited(_k.run(() => NativeActions.removePush(message.id), 'remove answered push'));
    _k.responses.handle(NotificationAnswer(id: message.id, actionId: actionId, input: input, data: message.data));
  }

  /// The category named [id] (its actions), for the app's banner to offer them; null when none.
  static NotificationCategory? category(String? id) => id == null ? null : _k.categories[id];

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
  /// [message] says how it shows (an image, a group, a category's actions, a sound, progress); [id], [title], [body] and
  /// [data] are the short way for a plain one.
  static Future<bool> notify({
    String? id,
    String? title,
    String? body,
    Map<String, String> data = const {},
    PushMessage? message,
    DateTime? at,
    Duration? after,
  }) {
    assert(message != null || id != null, 'notify needs an id or a message');
    message ??= PushMessage(id: id!, title: title, body: body, data: data);
    final shown = message;
    final when = at ?? (after == null ? null : _k.now().add(after));
    if (when != null && when.isAfter(_k.now())) return _k.run(() => _k.schedules.add(shown, when), 'schedule');
    return _k.run(() async => _k.present(shown, local: true), 'notify');
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
    _k.holding.value = false;
    _k.inApp.value = null;
    _k.open(message?.data);
    // Seen: its copy in the notification bar goes too (on iOS a push's is the system's, taken away natively).
    if (message != null) {
      unawaited(_k.run(() => _k.display.cancel(message.id), 'cancel opened'));
      unawaited(_k.run(() => NativeActions.removePush(message.id), 'remove opened push'));
    }
  }

  /// The push shown inside the app goes untapped.
  static void dismiss() {
    _k.holding.value = false;
    _k.inApp.value = null;
  }

  /// [on]: the app's banner is in use (a reply being typed), so it doesn't go by itself; false lets it go on its time.
  static void hold(bool on) => _k.holding.value = on;

  /// Whether the app's banner is held ([hold]).
  static ValueListenable<bool> get holding => _k.holding;

  /// The tapped push's data, once.
  static Map<String, String>? take() {
    final data = _k.opened.value;
    _k.opened.value = null;
    return data;
  }
}

