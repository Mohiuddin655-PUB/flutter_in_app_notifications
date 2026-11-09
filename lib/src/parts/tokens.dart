import 'dart:async' show StreamSubscription, unawaited;

import '../delegates/notification_messaging_delegate.dart';
import '../delegates/token_store_delegate.dart';

/// The signed-in account's token on this phone: saved when new or changed, moved when the phone is given another, and
/// taken off at sign-out.
class Tokens {
  Tokens(this._messaging, this._store, this._run);

  final NotificationMessagingDelegate _messaging;
  final TokenStoreDelegate _store;

  /// Runs a step; false when it failed (reported by the caller's rules).
  final Future<bool> Function(Future<void> Function() step, String where) _run;

  String _uid = '';
  StreamSubscription<String>? _refreshes;

  void start(String uid) {
    if (uid.isEmpty || uid == _uid) return;
    _uid = uid;
    unawaited(_refreshes?.cancel());
    _refreshes = _messaging.tokenRefreshes.listen((token) => unawaited(_save(token)));
    unawaited(_sync());
  }

  Future<void> clear() async {
    final uid = _uid;
    _uid = '';
    await _refreshes?.cancel();
    _refreshes = null;
    if (uid.isEmpty) return;
    final saved = _store.saved(uid);
    await _run(() => _store.remember(uid, null), 'forget saved token');
    if (saved != null) await _run(() => _store.remove(uid, saved), 'remove token');
    // A removal that didn't reach the server is harmless: the token it names stops working with this.
    await _run(_messaging.forgetToken, 'forget token');
  }

  Future<void> _sync() async {
    String? token;
    await _run(() async => token = await _messaging.token(), 'token');
    final now = token;
    if (now != null && now.isNotEmpty) await _save(now);
  }

  Future<void> _save(String token) async {
    final uid = _uid;
    if (uid.isEmpty) return;
    final before = _store.saved(uid);
    if (before == token) return;
    // Not taken (offline, say): the next launch saves it again, which does no harm.
    if (!await _run(() => _store.save(uid, token), 'save token') || uid != _uid) return;
    await _run(() => _store.remember(uid, token), 'remember token');
    if (before != null) unawaited(_run(() => _store.remove(uid, before), 'remove old token'));
  }
}
