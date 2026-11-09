import 'dart:async' show Timer, unawaited;
import 'dart:convert' show jsonDecode, jsonEncode;

import '../delegates/notification_display_delegate.dart';
import '../delegates/schedule_store_delegate.dart';
import '../models/push_message.dart';

/// The notifications scheduled on the phone. While the app is in front they wait on timers here, and the phone's own
/// alarms are taken away, so their time shows them inside the app ([_due]); once it leaves the front (the app switcher
/// too) they go back to the phone, which shows them even when the app is closed. Kept in [_store] between launches.
class Schedules {
  Schedules(this._display, this._store, this._now, this._run, this._due);

  final NotificationDisplayDelegate _display;
  final ScheduleStoreDelegate? _store;
  final DateTime Function() _now;
  final Future<bool> Function(Future<void> Function() step, String where) _run;
  final void Function(PushMessage message) _due;

  final _pending = <String, ({PushMessage message, DateTime at})>{};
  final _timers = <String, Timer>{};
  bool _open = true;

  /// At launch, the app on screen: what is still to come waits here.
  Future<void> load() async {
    final text = _store?.read();
    if (text != null && text.isNotEmpty) {
      for (final e in jsonDecode(text) as List) {
        final m = e as Map;
        final message = PushMessage(
          id: '${m['id']}',
          title: m['title'] as String?,
          body: m['body'] as String?,
          data: {for (final d in (m['data'] as Map? ?? const {}).entries) '${d.key}': '${d.value}'},
        );
        _pending[message.id] = (message: message, at: DateTime.fromMillisecondsSinceEpoch(m['at'] as int, isUtc: true));
      }
    }
    await shown();
  }

  Future<void> add(PushMessage message, DateTime at) async {
    _timers.remove(message.id)?.cancel();
    _pending[message.id] = (message: message, at: at.toUtc());
    await _save();
    _open ? _wait(message.id) : await _run(() => _display.notify(message, at: at), 'schedule');
  }

  Future<void> remove(String id) async {
    _timers.remove(id)?.cancel();
    if (_pending.remove(id) != null) await _save();
  }

  /// The app is on screen: the phone's alarms are taken away, and timers here wait instead. One whose time went by
  /// while it was hidden has been shown by the phone.
  Future<void> shown() async {
    _open = true;
    final now = _now();
    for (final id in _pending.keys.toList()) {
      if (!_pending[id]!.at.isAfter(now)) {
        _pending.remove(id);
        continue;
      }
      await _run(() => _display.cancel(id), 'schedule to app');
      _wait(id);
    }
    await _save();
  }

  /// The app is hidden: what is still to come goes back to the phone.
  Future<void> hidden() async {
    _open = false;
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    for (final p in _pending.values) {
      await _run(() => _display.notify(p.message, at: p.at), 'schedule to phone');
    }
  }

  /// Sign-out: nothing scheduled stays.
  Future<void> clear() async {
    for (final id in _pending.keys.toList()) {
      await _run(() => _display.cancel(id), 'cancel');
    }
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    _pending.clear();
    await _save();
  }

  void _wait(String id) {
    final p = _pending[id];
    if (p == null) return;
    final left = p.at.difference(_now());
    _timers[id] = Timer(left.isNegative ? Duration.zero : left, () {
      _timers.remove(id);
      if (_pending.remove(id) == null) return;
      unawaited(_save());
      _due(p.message);
    });
  }

  Future<void> _save() async {
    final store = _store;
    if (store == null) return;
    final list = [
      for (final p in _pending.values)
        {'id': p.message.id, 'title': p.message.title, 'body': p.message.body, 'data': p.message.data, 'at': p.at.millisecondsSinceEpoch},
    ];
    await _run(() => store.write(list.isEmpty ? null : jsonEncode(list)), 'save schedules');
  }
}
