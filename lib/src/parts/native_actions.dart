import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/services.dart' show MethodCall, MethodChannel;

import '../models/notification_answer.dart';

/// The package's own native side. On iOS it hears an action answered on a push (Firebase Messaging only tells of a
/// tap) and takes a push's copy out of Notification Center; elsewhere it does nothing.
class NativeActions {
  const NativeActions._();

  static const _channel = MethodChannel('in_app_notifications');

  static bool get _ios => defaultTargetPlatform == TargetPlatform.iOS;

  /// Each action answered on a push goes to [onAction], those from before the app listened (it was started by one)
  /// first.
  static Future<void> listen(void Function(NotificationAnswer response) onAction) async {
    if (!_ios) return;
    _channel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'action') onAction(_response(call.arguments));
    });
    final pending = await _channel.invokeMethod<List<Object?>>('takeActions') ?? const [];
    for (final answer in pending) {
      onAction(_response(answer));
    }
  }

  /// The push [id] (its `gcm.message_id`) taken out of Notification Center.
  static Future<void> removePush(String id) async {
    if (_ios) await _channel.invokeMethod<int>('removePush', {'id': id});
  }

  static NotificationAnswer _response(Object? raw) {
    final m = (raw as Map?) ?? const {};
    return NotificationAnswer(
      id: '${m['id'] ?? ''}',
      actionId: m['actionId'] as String?,
      input: m['input'] as String?,
      data: {for (final e in ((m['data'] as Map?) ?? const {}).entries) '${e.key}': '${e.value}'},
    );
  }
}
