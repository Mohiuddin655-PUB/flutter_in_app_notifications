/// A button on a notification (Accept, Reject) or a reply field (Reply), offered by its [NotificationCategory].
class NotificationAction {
  const NotificationAction({
    required this.id,
    required this.title,
    this.input = false,
    this.inputHint,
    this.inputButton,
    this.destructive = false,
    this.opensApp = false,
  });

  /// What `InAppNotifications.onAction` knows it by.
  final String id;
  final String title;

  /// A text field (a reply): what is typed comes in `NotificationAnswer.input`.
  final bool input;
  final String? inputHint;

  /// The send button's title next to the field.
  final String? inputButton;

  /// Shown as dangerous (red on iOS).
  final bool destructive;

  /// Brings the app to the front; otherwise it is handled without opening it (in the background).
  final bool opensApp;
}

/// The actions a kind of notification offers ("chat": Reply; "request": Accept, Reject). Set once in
/// `InAppNotifications.init`: iOS must know them before any notification names them.
class NotificationCategory {
  const NotificationCategory({required this.id, required this.actions});

  final String id;
  final List<NotificationAction> actions;
}
