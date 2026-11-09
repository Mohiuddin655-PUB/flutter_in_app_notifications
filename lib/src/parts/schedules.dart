import 'dart:async' show Timer, unawaited;
import 'dart:convert' show jsonDecode, jsonEncode;

import '../delegates/notification_display_delegate.dart';
import '../delegates/schedule_store_delegate.dart';
import '../models/push_message.dart';

/// The notifications scheduled on the phone. The phone's own alarm is always set, so one shows even if the app dies
/// in front (a crash, a kill). While the app is in front a timer here also waits: just before the time it takes the
/// phone's alarm away ([_handOver] early) and at the time shows it inside the app ([_due]). When the app leaves the
/// front the alarms are set again. Kept in [_store] between launches.
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

  /// How long before its time the phone's alarm is taken away while the app is in front.
  static const _handOver = Duration(seconds: 2);

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
    await _run(() => _display.notify(message, at: at), 'schedule');
    if (_open) _wait(message.id);
  }

  Future<void> remove(String id) async {
    _timers.remove(id)?.cancel();
    if (_pending.remove(id) != null) await _save();
  }

  /// The app is in front: timers here wait too. One whose time went by while it was away has been shown by the phone.
  Future<void> shown() async {
    _open = true;
    final now = _now();
    for (final id in _pending.keys.toList()) {
      if (!_pending[id]!.at.isAfter(now)) {
        _pending.remove(id);
        continue;
      }
      _wait(id);
    }
    await _save();
  }

  /// The app left the front: the timers stop, and every alarm is set again (one may have been taken away just before
  /// its time).
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

  /// [_handOver] before the time the phone's alarm goes, so it doesn't pop up over the app; at the time it shows here.
  void _wait(String id) {
    final p = _pending[id];
    if (p == null) return;
    _timers.remove(id)?.cancel();
    final left = p.at.difference(_now());
    final handOver = left - _handOver;
    _timers[id] = Timer(handOver.isNegative ? Duration.zero : handOver, () {
      unawaited(_run(() => _display.cancel(id), 'schedule to app'));
      _timers[id] = Timer(left.isNegative ? Duration.zero : (handOver.isNegative ? left : _handOver), () {
        _timers.remove(id);
        if (_pending.remove(id) == null) return;
        unawaited(_save());
        _due(p.message);
      });
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
