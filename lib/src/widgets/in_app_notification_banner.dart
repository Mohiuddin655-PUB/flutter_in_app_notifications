import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

import '../in_app_notifications.dart';
import '../models/notification_action.dart';
import '../models/push_message.dart';
import 'in_app_notification_banner_style.dart';
import 'in_app_notification_drag.dart';
import 'in_app_notification_reply_field.dart';

/// Builds one action's button: [onPressed] answers with it.
typedef InAppNotificationActionBuilder = Widget Function(BuildContext context, NotificationAction action, VoidCallback onPressed);

/// Builds the reply field: [send] answers with the typed text; [controller] and [focus] are the field's (focusing it
/// holds the banner).
typedef InAppNotificationReplyBuilder =
    Widget Function(BuildContext context, NotificationAction action, TextEditingController controller, FocusNode focus, VoidCallback send);

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

  /// How it comes: down from above its place, growing from a little smaller and fading in, a touch past its place and
  /// back, so it lands softly.
  static const arrive = Cubic(0.16, 1.22, 0.3, 1);

  /// How it goes: up, shrinking a little and fading out, quicker at the end.
  static const leave = Cubic(0.55, 0, 0.75, 0.6);

  /// Its coming and going, as Discord's: for `InAppNotificationGate.transitionBuilder` (the gate's default). Built
  /// from transitions, so a frame only repaints and moves it, nothing is built again.
  static Widget transition(Widget child, Animation<double> animation) {
    final move = CurvedAnimation(parent: animation, curve: arrive, reverseCurve: leave.flipped);
    final fade = CurvedAnimation(parent: animation, curve: const Interval(0, 0.6, curve: Curves.easeOut), reverseCurve: Curves.easeIn);
    return SlideTransition(
      position: Tween(begin: const Offset(0, -1), end: Offset.zero).animate(move),
      child: FadeTransition(
        opacity: fade,
        child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(move), alignment: Alignment.topCenter, child: child),
      ),
    );
  }

  /// A plain slide down from the top, and back up.
  static Widget slideTransition(Widget child, Animation<double> animation) {
    return SlideTransition(
      position: Tween(begin: const Offset(0, -1), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: child,
    );
  }

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
        GestureDetector(behavior: HitTestBehavior.opaque, onTap: onOpen, child: row),
        if (reply != null) ...[
          SizedBox(height: gap),
          InAppNotificationReplyField(action: reply, style: style, builder: replyBuilder),
        ],
        if (buttons.isNotEmpty) ...[
          SizedBox(height: gap / 2),
          Row(
            mainAxisAlignment: style.actionsAlignment ?? MainAxisAlignment.end,
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
        Container(
          margin: style.margin ?? const EdgeInsets.all(12),
          padding: style.padding ?? const EdgeInsets.all(14),
          decoration: decoration,
          child: body,
        );
    // Under the status bar, its icons follow the banner while it covers them, and the page's again once it has gone
    // (the region moves with it, dragged or leaving). Kept clear of it, the page's stay.
    final covered = style.safeArea
        ? card
        : AnnotatedRegion<SystemUiOverlayStyle>(value: style.statusBarStyle ?? _statusBarFor(decoration.color ?? theme.colorScheme.surface), child: card);

    // The gate sits above the app's pages, outside any Material: the reply field and buttons need one.
    final material = Material(type: MaterialType.transparency, child: covered);
    final shown = InAppNotificationDrag(key: ValueKey(message.id), enabled: style.dismissible, onDismiss: onDismiss, child: material);
    // Its own layer: moving, fading or dragged, it repaints alone, not the page under it.
    final layered = RepaintBoundary(child: shown);
    return style.safeArea ? SafeArea(child: layered) : layered;
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
    // Decoded at the size it shows, not the picture's own.
    final pixels = (size * MediaQuery.devicePixelRatioOf(context)).round();
    final image = src.startsWith('http')
        ? Image.network(src, width: size, height: size, fit: BoxFit.cover, cacheWidth: pixels, cacheHeight: pixels)
        : null;
    if (image == null) return null;
    return ClipRRect(borderRadius: style.imageRadius ?? BorderRadius.circular(8), child: image);
  }

  Widget _texts(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if ((message.title ?? '').isNotEmpty) Text(message.title!, style: style.titleStyle ?? theme.textTheme.titleSmall),
        if ((message.body ?? '').isNotEmpty)
          Text(
            message.body!,
            style: style.bodyStyle ?? theme.textTheme.bodyMedium,
            maxLines: style.bodyMaxLines ?? 2,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }

  Widget _button(BuildContext context, NotificationAction action) {
    void press() => InAppNotifications.answer(action.id);
    final custom = actionBuilder;
    if (custom != null) return custom(context, action, press);
    return TextButton(
      style: action.destructive ? style.destructiveActionStyle ?? TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error) : style.actionStyle,
      onPressed: press,
      child: Text(action.title),
    );
  }
}
