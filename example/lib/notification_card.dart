import 'package:flutter/material.dart';
import 'package:in_app_notifications/in_app_notifications.dart';

/// The app's own design for the in-app notification, ready to copy: its image, title and body, its reply field, its
/// buttons, and a bar for the time it has left. Its look `black` fills the screen instead. A tap, a swipe, a finger on
/// it and typing are the host's.
class NotificationCard extends StatelessWidget {
  const NotificationCard(this.data, {super.key});

  final InAppNotificationData data;

  @override
  Widget build(BuildContext context) {
    final black = data.look == 'black';
    final theme = Theme.of(context);
    final text = black ? Colors.white : theme.colorScheme.onSurface;
    final m = data.message;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (m.image != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    m.image!,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox(width: 44, height: 44), // a broken link shows nothing
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (m.title != null) Text(m.title!, style: theme.textTheme.titleSmall?.copyWith(color: text)),
                    if (m.body != null)
                      Text(
                        m.body!,
                        style: theme.textTheme.bodyMedium?.copyWith(color: text),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (data.reply != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: _ReplyField(data, color: text),
          ),
        if (data.buttons.isNotEmpty || black)
          OverflowBar(
            alignment: MainAxisAlignment.end,
            children: [
              for (final a in data.buttons)
                TextButton(
                  style: a.destructive ? TextButton.styleFrom(foregroundColor: theme.colorScheme.error) : null,
                  onPressed: () => data.answer(a.id),
                  child: Text(a.title),
                ),
              if (black) TextButton(onPressed: data.dismiss, child: const Text('Close')),
            ],
          ),
        LinearProgressIndicator(value: data.remaining, minHeight: 2),
      ],
    );

    if (black) return Container(color: Colors.black, alignment: Alignment.center, padding: const EdgeInsets.all(24), child: content);
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 4))],
        ),
        child: content,
      ),
    );
  }
}

/// The reply field: sending answers with the text, and an empty one sends nothing.
class _ReplyField extends StatefulWidget {
  const _ReplyField(this.data, {required this.color});

  final InAppNotificationData data;
  final Color color;

  @override
  State<_ReplyField> createState() => _ReplyFieldState();
}

class _ReplyFieldState extends State<_ReplyField> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _send() {
    final text = _text.text.trim();
    if (text.isNotEmpty) widget.data.answer(widget.data.reply!.id, input: text);
  }

  @override
  Widget build(BuildContext context) {
    final reply = widget.data.reply!;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _text,
            style: TextStyle(color: widget.color),
            textInputAction: TextInputAction.send,
            decoration: InputDecoration(hintText: reply.inputHint, isDense: true),
            onSubmitted: (_) => _send(),
          ),
        ),
        TextButton(onPressed: _send, child: Text(reply.inputButton ?? reply.title)),
      ],
    );
  }
}
