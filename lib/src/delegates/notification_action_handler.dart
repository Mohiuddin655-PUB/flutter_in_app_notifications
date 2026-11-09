import '../models/notification_answer.dart';

/// What the app does with an action ([NotificationAnswer.actionId]): a reply sent, a request accepted. It runs
/// whether the app is open, in the background, or was closed (then in a background isolate, so it must be a top-level
/// or static function, and set up what it needs itself, Firebase say). A plain tap goes to `InAppNotifications.opened`.
typedef NotificationActionHandler = Future<void> Function(NotificationAnswer response);
