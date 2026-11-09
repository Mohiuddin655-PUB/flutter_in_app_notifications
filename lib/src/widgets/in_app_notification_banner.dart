import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

import '../in_app_notifications.dart';
import '../models/notification_action.dart';
import '../models/push_message.dart';
import '../enums/banner_edge.dart';
import 'in_app_notification_banner_style.dart';
import 'in_app_notification_drag.dart';
import 'in_app_notification_motion.dart';
import 'in_app_notification_reply_field.dart';

/// Builds one action's button: [onPressed] answers with it.
typedef InAppNotificationActionBuilder = Widget Function(BuildContext context, NotificationAction action, VoidCallback onPressed);

/// Builds the reply field: [send] answers with the typed text; [controller] and [focus] are the field's (focusing it
/// holds the banner).
typedef InAppNotificationReplyBuilder = Widget Function(
  BuildContext context,
  NotificationAction action,
  TextEditingController controller,
  FocusNode focus,
  VoidCallback send,
);

/// A ready banner for `InAppNotificationGate`'s builder: the message's title and body, its image, its category's actions
/// as buttons and a reply field (holding the banner while typed in); a tap opens it, a swipe dismisses it. Everything
/// it shows can be changed from the app: [style] for its look, and a builder for any part to replace it whole
/// ([leading], [content], [actionBuilder], [replyBuilder], [container]).
class InAppNotificationBanner extends StatelessWidget {
  const InAppNotificationBanner({
    super.key,
    required this.message,
    required this.onOpen,
    required this.onDismiss,
    this.style = const InAppNotificationBannerStyle(),
    this.leading,
    this.content,
    this.trailing,
    this.actionBuilder,
    this.replyBuilder,
    this.container,
    this.showActions = true,
  });

  final PushMessage message;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;
  final InAppNotificationBannerStyle style;

  /// In place of the image at the start (the app's icon, an avatar).
  final Widget Function(BuildContext context, PushMessage message)? leading;

  /// In place of the title and body.
  final Widget Function(BuildContext context, PushMessage message)? content;

  /// At the end of the first row (a time, a close button).
  final Widget Function(BuildContext context, PushMessage message)? trailing;

  final InAppNotificationActionBuilder? actionBuilder;
  final InAppNotificationReplyBuilder? replyBuilder;

  /// In place of the card around everything: gets what it holds.
  final Widget Function(BuildContext context, Widget child)? container;

  /// False shows no actions or reply field.
  final bool showActions;

  /// The motion, as Discord's: see [InAppNotificationMotion].
  static const arrive = InAppNotificationMotion.arrive;
  static const leave = InAppNotificationMotion.leave;
  static Widget transition(Widget child, Animation<double> animation) => InAppNotificationMotion.transition(child, animation);
  static Widget slideTransition(Widget child, Animation<double> animation) => InAppNotificationMotion.slide(child, animation);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gap = style.gap ?? 8;
    final actions = showActions ? InAppNotifications.category(message.category)?.actions ?? const <NotificationAction>[] : const <NotificationAction>[];
    final reply = actions.where((a) => a.input).firstOrNull;
    final buttons = actions.where((a) => !a.input).toList();
    final image = _image(context);

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (leading != null) ...[leading!(context, message), SizedBox(width: gap)] else if (image != null) ...[image, SizedBox(width: gap)],
        Expanded(child: content?.call(context, message) ?? _texts(theme)),
        if (trailing != null) trailing!(context, message),
      ],
    );

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // A hold isn't a tap: let go after one, it goes on its time instead of opening.
        GestureDetector(behavior: HitTestBehavior.opaque, onTap: onOpen, onLongPress: () {}, child: row),
        if (reply != null) ...[SizedBox(height: gap), InAppNotificationReplyField(action: reply, style: style, builder: replyBuilder)],
        if (buttons.isNotEmpty) ...[
          SizedBox(height: gap / 2),
          // Side by side; one under another when they don't fit across.
          OverflowBar(
            alignment: style.actionsAlignment ?? MainAxisAlignment.end,
            overflowAlignment: switch (style.actionsAlignment) {
              MainAxisAlignment.start => OverflowBarAlignment.start,
              MainAxisAlignment.center => OverflowBarAlignment.center,
              _ => OverflowBarAlignment.end,
            },
            children: [for (final a in buttons) _button(context, a)],
          ),
        ],
      ],
    );

    final decoration =
        style.decoration ??
        BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 4))],
        );
    final card =
        container?.call(context, body) ??
        Container(margin: style.margin ?? const EdgeInsets.all(12), padding: style.padding ?? const EdgeInsets.all(14), decoration: decoration, child: body);
    // Under the status bar, its icons follow the banner while it covers them, and the page's again once it has gone
    // (the region moves with it, dragged or leaving). Kept clear of it, the page's stay.
    final covered = style.safeArea || BannerEdge.of(context) != BannerEdge.top
        ? card
        : AnnotatedRegion<SystemUiOverlayStyle>(value: style.statusBarStyle ?? _statusBarFor(_tone(decoration) ?? theme.colorScheme.surface), child: card);

    // The gate sits above the app's pages, outside any Material: the reply field and buttons need one.
    // Its own layer, under the drag: moved, faded or dragged, the card is drawn once and its picture moved, and the
    // page under it isn't drawn again.
    final material = RepaintBoundary(
      child: Material(type: MaterialType.transparency, child: covered),
    );
    final shown = InAppNotificationDrag(key: ValueKey(message.id), enabled: style.dismissible, onDismiss: onDismiss, child: material);
    return style.safeArea ? SafeArea(child: shown) : shown;
  }

  /// The card's colour under the status bar: its colour, or its gradient's colours mixed.
  static Color? _tone(BoxDecoration decoration) {
    final colors = decoration.gradient?.colors;
    if (decoration.color != null || colors == null || colors.isEmpty) return decoration.color;
    var r = 0.0, g = 0.0, b = 0.0;
    for (final c in colors) {
      r += c.r;
      g += c.g;
      b += c.b;
    }
    return Color.from(alpha: 1, red: r / colors.length, green: g / colors.length, blue: b / colors.length);
  }

  /// Dark icons on a light card, light on a dark one.
  static SystemUiOverlayStyle _statusBarFor(Color card) {
    final light = card.computeLuminance() > 0.5;
    return (light ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light).copyWith(statusBarColor: const Color(0x00000000));
  }

  Widget? _image(BuildContext context) {
    final size = style.imageSize ?? 44;
    final src = message.image;
    if (src == null || src.isEmpty) return null;
    // Decoded at the width it shows, not the picture's own; its height follows, so it isn't squashed.
    final pixels = (size * MediaQuery.devicePixelRatioOf(context)).round();
    final image = src.startsWith('http')
        ? Image.network(src, width: size, height: size, fit: BoxFit.cover, cacheWidth: pixels)
        : Image.file(File(src), width: size, height: size, fit: BoxFit.cover, cacheWidth: pixels);
    return ClipRRect(borderRadius: style.imageRadius ?? BorderRadius.circular(8), child: image);
  }

  Widget _texts(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if ((message.title ?? '').isNotEmpty) Text(message.title!, style: style.titleStyle ?? theme.textTheme.titleSmall),
        if ((message.body ?? '').isNotEmpty)
          Text(message.body!, style: style.bodyStyle ?? theme.textTheme.bodyMedium, maxLines: style.bodyMaxLines ?? 2, overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _button(BuildContext context, NotificationAction action) {
    void press() => InAppNotifications.answer(action.id);
    final custom = actionBuilder;
    if (custom != null) return custom(context, action, press);
    return TextButton(
      style: action.destructive
          ? style.destructiveActionStyle ?? TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error)
          : style.actionStyle,
      onPressed: press,
      child: Text(action.title),
    );
  }
}
