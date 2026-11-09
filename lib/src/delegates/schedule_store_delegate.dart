/// Where the notifications scheduled on the phone are kept between launches, given by the app (its preferences, say),
/// so the app can show them itself when their time comes while it is open.
abstract interface class ScheduleStoreDelegate {
  /// The text last [write]n; null when none.
  String? read();

  /// [text] kept in place of what was there; null forgets it.
  Future<void> write(String? text);
}
