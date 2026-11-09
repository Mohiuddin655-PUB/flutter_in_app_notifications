/// A notification answered: tapped ([actionId] null), or one of its actions; with what was typed ([input]) for a reply.
class NotificationAnswer {
  const NotificationAnswer({required this.id, this.actionId, this.input, this.data = const {}});

  /// The notification's id (`PushMessage.id`).
  final String id;
  final String? actionId;
  final String? input;
  final Map<String, String> data;

  /// Just tapped, not an action.
  bool get tapped => actionId == null;
}
