import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show ValueListenable;

import 'delegates/error_reporter.dart';
import 'delegates/notification_action_handler.dart';
import 'delegates/notification_display_delegate.dart';
import 'delegates/notification_messaging_delegate.dart';
import 'delegates/schedule_store_delegate.dart';
import 'delegates/token_store_delegate.dart';
import 'enums/while_open.dart';
import 'models/notification_action.dart';
import 'models/notification_answer.dart';
import 'models/push_message.dart';
import 'parts/banner_state.dart';
import 'parts/kit.dart';
import 'parts/native_actions.dart';

/// Notifications in the app. The banner works on its own: wrap the app in `InAppNotificationGate` and call [show]; no
/// setup. Pushes and the phone's notifications need [setup] once with the app's delegates, [init] at launch, [start]
/// at sign-in and [clear] before sign-out. A tapped one's data waits in [opened] until the app [take]s it.
class InAppNotifications {
  const InAppNotifications._();

  /// The banner's state, there with or without [setup].
  static final _b = BannerState();

  static Kit? _kit;

  /// Each [show] without an id is a banner of its own.
  static var _shown = 0;

  static Kit get _k => _kit ?? (throw StateError('InAppNotifications.setup must be called first (only the banner works without it).'));

  // ---- Setup: only for pushes and the phone's notifications ----

  /// [whileOpen]: where a notification that comes while the app is open shows ([WhileOpen.bar] by default).
  /// [schedules]: where scheduled notifications are kept, so one whose time comes while the app is open shows as
  /// [whileOpen] says too; without it the phone shows them by itself. [now]: the clock scheduled times are read by (the
  /// server's, say). [unreachable]: the error only says the backend couldn't be reached (offline), so it isn't reported.
  static void setup({
    required NotificationMessagingDelegate messaging,
    required NotificationDisplayDelegate display,
    required TokenStoreDelegate tokens,
    ScheduleStoreDelegate? schedules,
    List<NotificationCategory> categories = const [],
    NotificationActionHandler? onAction,
    WhileOpen whileOpen = WhileOpen.bar,
    DateTime Function()? now,
    ErrorReporter? onError,
    bool Function(Object error)? unreachable,
  }) {
    // Once: a second kit would listen again, and show each push twice.
    assert(_kit == null, 'InAppNotifications.setup is called once');
    if (_kit != null) return;
    _kit = Kit(messaging, display, tokens, schedules, categories, _b, whileOpen, now ?? DateTime.now, onError, unreachable)..responses.handler = onAction;
  }

  /// At launch: shows pushes that come while the app is open, and takes the one whose tap started it.
  static Future<void> init() => _k.init();

  /// [uid] is signed in (a login, or a launch still signed in): its token is kept on the account.
  static void start(String uid) => _k.tokens.start(uid);

  /// Before sign-out or deleting the account, while it may still write: its token is taken off and let go, and what it
  /// was told goes with it (a tapped one not yet taken, the banner, those in the notification bar).
  /// Without [setup], only the banner's are let go.
  static Future<void> clear() async {
    final kit = _kit;
    kit == null ? _b.clear() : await kit.clear();
  }

  /// A notification made on the phone (a reminder, say), in the notification bar: now, at [at] (a plain time, such as
  /// `DateTime(2026, 11, 10, 10)` for 10am), or [after] a while (scheduled; it shows even when the app is closed).
  /// Times are read by `setup(now:)`'s clock. While the app is open it shows as [WhileOpen] says, as a push does.
  /// [message] says how it shows (an image, a group, a category's actions, a sound, progress); [id], [title], [body] and
  /// [data] are the short way for a plain one. False when it couldn't be made.
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
    final shown = message ?? PushMessage(id: id!, title: title, body: body, data: data);
    final when = at ?? (after == null ? null : _k.now().add(after));
    if (when != null && when.isAfter(_k.now())) return _k.run(() => _k.schedules.add(shown, when), 'schedule');
    return _k.run(() async => _k.present(shown, local: true), 'notify');
  }

  /// The notification made on the phone with [id] taken away, shown or still waiting.
  static Future<bool> cancel(String id) => _k.run(() async {
    await _k.schedules.remove(id);
    await _k.display.cancel(id);
  }, 'cancel');

  // ---- The banner: works without setup ----

  /// [message] in the app's banner (`InAppNotificationGate`), with nothing in the notification bar and no push: a
  /// message the app tells itself (a saved change, a match found). Works without [setup]. Its actions and a tap work as
  /// any other's. [id], [title], [body] and [data] are the short way for a plain one. [look] names how it shows, from
  /// `InAppNotificationGate.looks` ('toast', 'snackbar', 'popup' or the app's own); the gate's own look when null.
  static void show({String? id, String? title, String? body, Map<String, String> data = const {}, PushMessage? message, String? look}) {
    assert(message != null || id != null || title != null, 'show needs a message, an id or a title');
    final shown = message ?? PushMessage(id: id ?? 'banner-${_shown++}', title: title, body: body, data: data);
    _b.inApp.value = look == null ? shown : shown.copyWith(look: look);
  }

  /// What each kind of message offers (its actions), for the banner without [setup]; [setup]'s `categories` set them
  /// too.
  static set categories(List<NotificationCategory> categories) {
    _b.categories
      ..clear()
      ..addAll({for (final c in categories) c.id: c});
  }

  /// The category named [id] (its actions), for the banner to offer them; null when none.
  static NotificationCategory? category(String? id) => id == null ? null : _b.categories[id];

  /// The message showing in the banner now (the newest), until [open]ed or [dismiss]ed.
  static ValueListenable<PushMessage?> get inApp => _b.inApp;

  /// The banner was tapped: it goes, and its data waits in [opened].
  static void open() {
    final message = _b.inApp.value;
    _b.releaseAll();
    _b.inApp.value = null;
    _b.open(message?.data);
    if (message != null) _seen(message.id);
  }

  /// The banner goes untapped.
  static void dismiss() {
    _b.releaseAll();
    _b.inApp.value = null;
  }

  /// An action from the banner: handled as if answered on a notification (`setup(onAction:)`, and [actions]), and the
  /// banner goes.
  static void answer(String actionId, {String? input}) {
    final message = _b.inApp.value;
    if (message == null) return;
    _b.releaseAll();
    _b.inApp.value = null;
    _seen(message.id);
    final answer = NotificationAnswer(id: message.id, actionId: actionId, input: input, data: message.data);
    final kit = _kit;
    kit == null ? _b.actions.add(answer) : unawaited(kit.responses.handle(answer));
  }

  /// Each action answered (a reply, Accept), on the banner or on a notification, while the app runs.
  static Stream<NotificationAnswer> get actions => _b.actions.stream;

  /// The data of the one last tapped (the banner or a notification), until [take]n.
  static ValueListenable<Map<String, String>?> get opened => _b.opened;

  /// The tapped one's data, once.
  static Map<String, String>? take() {
    final data = _b.opened.value;
    _b.opened.value = null;
    return data;
  }

  /// [on]: the banner is in use, so it doesn't go by itself; false lets it go on its time once no other [reason] holds
  /// it (a reply being typed and a finger on it are two reasons).
  static void hold(bool on, {Object reason = 'app'}) => _b.hold(reason, on);

  /// Whether the banner is held ([hold]).
  static ValueListenable<bool> get holding => _b.holding;

  /// Seen in the banner: its copy in the notification bar goes too (with [setup]; on iOS a push's natively).
  static void _seen(String id) {
    final kit = _kit;
    if (kit == null) return;
    unawaited(kit.run(() => kit.display.cancel(id), 'cancel seen'));
    unawaited(kit.run(() => NativeActions.removePush(id), 'remove seen push'));
  }
}
