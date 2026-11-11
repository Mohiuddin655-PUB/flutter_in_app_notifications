import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show ValueListenable;

import '../keys/notification_keys.dart';
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
import 'parts/in_app_notification_state.dart';
import 'parts/kit.dart';
import 'parts/native_actions.dart';

/// Notifications in the app. The in-app notification works on its own: `InAppNotificationHost` shows [inApp] with
/// the app's own design, and the app calls [show]; no init. Pushes and the phone's notifications need [init] once at launch with the app's delegates, [start]
/// at sign-in and [clear] before sign-out. A tapped one's data waits in [opened] until the app [take]s it.
class InAppNotifications {
  const InAppNotifications._();

  /// The in-app notification's state, there with or without [init].
  static final _b = InAppNotificationState.i;

  static Kit? _kit;

  /// Each [show] without an id is an in-app notification of its own.
  static var _shown = 0;

  static Kit get _k => _kit ?? (throw StateError('InAppNotifications.init must be called first (only the in-app notification works without it).'));

  // ---- Init: only for pushes and the phone's notifications ----

  /// At launch, once (after Firebase is up): keeps the app's delegates, then shows pushes that come while the app is
  /// open and takes the one whose tap started it. [whileOpen]: where a notification that comes while the app is open
  /// shows ([WhileOpen.bar] by default). [schedules]: where scheduled notifications are kept, so one whose time comes
  /// while the app is open shows as [whileOpen] says too; without it the phone shows them by itself. [now]: the clock
  /// scheduled times are read by (the server's, say). [unreachable]: the error only says the backend couldn't be
  /// reached (offline), so it isn't reported.
  static Future<void> init({
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
    assert(_kit == null, 'InAppNotifications.init is called once');
    _kit ??= Kit(messaging, display, tokens, schedules, categories, _b, whileOpen, now ?? DateTime.now, onError, unreachable)..responses.handler = onAction;
    return _k.init();
  }

  /// [uid] is signed in (a login, or a launch still signed in): its token is kept on the account.
  static void start(String uid) => _k.tokens.start(uid);

  /// Before sign-out or deleting the account, while it may still write: its token is taken off and let go, and what it
  /// was told goes with it (a tapped one not yet taken, the in-app notification, those in the notification bar).
  /// Without [init], only the in-app notification's are let go.
  static Future<void> clear() async {
    final kit = _kit;
    kit == null ? _b.clear() : await kit.clear();
  }

  /// A notification made on the phone (a reminder, say), in the notification bar: now, at [at] (a plain time, such as
  /// `DateTime(2026, 11, 10, 10)` for 10am), or [after] a while (scheduled; it shows even when the app is closed).
  /// Times are read by `init(now:)`'s clock. While the app is open it shows as [WhileOpen] says, as a push does.
  /// [message] says how it shows (an image, a group, a category's actions, a sound, progress); [id], [title], [body]
  /// and [data] are the short way for a plain one. False when it couldn't be made.
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

  // ---- The in-app notification: works without init ----

  /// [message] inside the app ([inApp]), with nothing in the notification bar and no push: a message the app tells
  /// itself (a saved change, a match found). Works without [init]. Its actions and a tap work as any other's. [id],
  /// [title], [body] and [data] are the short way for a plain one; [look] picks its design in the app's builder.
  static void show({String? id, String? title, String? body, Map<String, String> data = const {}, String? look, PushMessage? message}) {
    assert(message != null || id != null || title != null, 'show needs a message, an id or a title');
    final shown = message ?? PushMessage(id: id ?? 'banner-${_shown++}', title: title, body: body, data: data);
    _b.present(look == null ? shown : shown.copyWith(data: {...shown.data, NotificationKeys.look: look}));
  }

  /// What each kind of message offers (its actions), for the in-app notification without [init]; [init]'s
  /// `categories` set them too.
  static set categories(List<NotificationCategory> categories) {
    _b.categories
      ..clear()
      ..addAll({for (final c in categories) c.id: c});
  }

  /// The category named [id] (its actions), for the in-app notification to offer them; null when none.
  static NotificationCategory? category(String? id) => id == null ? null : _b.categories[id];

  /// The message showing in the in-app notification now (the newest), until [open]ed or [dismiss]ed.
  static ValueListenable<PushMessage?> get inApp => _b.inApp;

  /// The in-app notification was tapped: it goes, and its data waits in [opened].
  static void open() {
    final message = _b.inApp.value;
    _b.releaseAll();
    _b.inApp.value = null;
    _b.open(message?.data);
    if (message != null) _seen(message.id);
  }

  /// The in-app notification goes untapped.
  static void dismiss() {
    _b.releaseAll();
    _b.inApp.value = null;
  }

  /// An action from the in-app notification: handled as if answered on a notification (`init(onAction:)`, and
  /// [actions]), and the in-app notification goes.
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

  /// Each action answered (a reply, Accept), on the in-app notification or on a notification, while the app runs.
  static Stream<NotificationAnswer> get actions => _b.actions.stream;

  /// The data of the one last tapped (the in-app notification or a notification), until [take]n.
  static ValueListenable<Map<String, String>?> get opened => _b.opened;

  /// The tapped one's data, once.
  static Map<String, String>? take() {
    final data = _b.opened.value;
    _b.opened.value = null;
    return data;
  }

  /// [on]: the in-app notification is in use, so it doesn't go by itself; false lets it go on its time once no other
  /// [reason] holds it (a reply being typed and a finger on it are two reasons).
  static void hold(bool on, {Object reason = 'app'}) => _b.hold(reason, on);

  /// Whether the in-app notification is held ([hold]).
  static ValueListenable<bool> get holding => _b.holding;

  /// Seen in the in-app notification: its copy in the notification bar goes too (with [init]; on iOS a push's
  /// natively).
  static void _seen(String id) {
    final kit = _kit;
    if (kit == null) return;
    unawaited(kit.run(() => kit.display.cancel(id), 'cancel seen'));
    unawaited(kit.run(() => NativeActions.removePush(id), 'remove seen push'));
  }
}
