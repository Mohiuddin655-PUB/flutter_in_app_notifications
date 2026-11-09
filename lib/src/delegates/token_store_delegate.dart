/// Where an account's tokens are kept, given by the app: on the server, where it finds the phones to send to, and the
/// copy last saved on this phone, so a launch writes nothing when the token hasn't changed.
abstract interface class TokenStoreDelegate {
  /// [token] kept on [uid]'s account. Doing it twice does no harm.
  Future<void> save(String uid, String token);

  /// [token] taken off [uid]'s account.
  Future<void> remove(String uid, String token);

  /// The token last saved on [uid]'s account from this phone; null when none.
  String? saved(String uid);

  /// [token] noted as the one last saved for [uid]; null forgets it.
  Future<void> remember(String uid, String? token);
}
