/// A push as the app hands it over: its [title] and [body] when it has them, and its [data] (all strings, as push
/// services send them).
class PushMessage {
  const PushMessage({required this.id, this.title, this.body, this.data = const {}});

  /// The same push keeps the same id, so showing it twice replaces it.
  final String id;
  final String? title;
  final String? body;
  final Map<String, String> data;

  /// Nothing to show: a data-only push.
  bool get silent => (title ?? '').isEmpty && (body ?? '').isEmpty;
}
