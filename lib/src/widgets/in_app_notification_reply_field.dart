import 'package:flutter/material.dart';

import '../in_app_notifications.dart';
import '../models/notification_action.dart';
import 'in_app_notification_banner.dart';
import 'in_app_notification_banner_style.dart';

/// The banner's reply field: focusing it holds the banner (`InAppNotifications.hold`), sending answers with the text.
/// Its look comes from the banner's style, or the app's [builder] replaces it whole.
class InAppNotificationReplyField extends StatefulWidget {
  const InAppNotificationReplyField({super.key, required this.action, required this.style, this.builder});

  final NotificationAction action;
  final InAppNotificationBannerStyle style;
  final InAppNotificationReplyBuilder? builder;

  @override
  State<InAppNotificationReplyField> createState() => _InAppNotificationReplyFieldState();
}

class _InAppNotificationReplyFieldState extends State<InAppNotificationReplyField> {
  final _text = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_held);
  }

  void _held() => InAppNotifications.hold(_focus.hasFocus, reason: _focus);

  @override
  void dispose() {
    _focus.removeListener(_held);
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send() {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    InAppNotifications.answer(widget.action.id, input: text);
  }

  @override
  Widget build(BuildContext context) {
    final custom = widget.builder;
    if (custom != null) return custom(context, widget.action, _text, _focus, _send);
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _text,
            focusNode: _focus,
            style: widget.style.replyTextStyle,
            textInputAction: TextInputAction.send,
            decoration: widget.style.replyDecoration ?? InputDecoration(hintText: widget.action.inputHint, isDense: true),
            onSubmitted: (_) => _send(),
          ),
        ),
        TextButton(style: widget.style.actionStyle, onPressed: _send, child: Text(widget.action.inputButton ?? widget.action.title)),
      ],
    );
  }
}
