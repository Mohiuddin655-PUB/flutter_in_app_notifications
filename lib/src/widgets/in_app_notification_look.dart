import 'package:flutter/material.dart';

import '../enums/banner_edge.dart';
import 'in_app_notification_banner.dart';
import 'in_app_notification_banner_style.dart';
import 'in_app_notification_gate.dart';
import 'in_app_notification_motion.dart';

/// A named way the same banner shows, kept in `InAppNotificationGate.looks` and picked by name
/// (`InAppNotifications.show(look: 'toast')`, or a push's `look` in its data). Every value is optional: one left out is
/// the gate's own. [BannerLook.toast], [BannerLook.snackbar] and [BannerLook.popup] are ready ones, each changed with
/// its arguments or [copyWith].
@immutable
class BannerLook {
  const BannerLook({this.builder, this.edge, this.alignment, this.transitionBuilder, this.showFor, this.stays = false, this.enter, this.exit});

  /// A toast: small, dark and short, at the bottom; its title and body only, gone after [showFor] (2s).
  factory BannerLook.toast({InAppNotificationBannerStyle? style, BannerEdge edge = BannerEdge.bottom, Duration showFor = const Duration(seconds: 2)}) {
    return BannerLook(
      edge: edge,
      showFor: showFor,
      builder: (context, message, onOpen, onDismiss) {
        final colors = Theme.of(context).colorScheme;
        final text = Theme.of(context).textTheme;
        return InAppNotificationBanner(
          message: message,
          onOpen: onOpen,
          onDismiss: onDismiss,
          showActions: false,
          style:
              style ??
              InAppNotificationBannerStyle(
                margin: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(color: colors.inverseSurface, borderRadius: BorderRadius.circular(24)),
                titleStyle: text.labelLarge?.copyWith(color: colors.onInverseSurface),
                bodyStyle: text.bodySmall?.copyWith(color: colors.onInverseSurface),
                imageSize: 24,
              ),
        );
      },
    );
  }

  /// A snackbar: across the bottom, dark, with its actions at the end; gone after [showFor] (4s).
  factory BannerLook.snackbar({InAppNotificationBannerStyle? style, BannerEdge edge = BannerEdge.bottom, Duration showFor = const Duration(seconds: 4)}) {
    return BannerLook(
      edge: edge,
      showFor: showFor,
      builder: (context, message, onOpen, onDismiss) {
        final colors = Theme.of(context).colorScheme;
        final text = Theme.of(context).textTheme;
        return InAppNotificationBanner(
          message: message,
          onOpen: onOpen,
          onDismiss: onDismiss,
          style:
              style ??
              InAppNotificationBannerStyle(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                decoration: BoxDecoration(color: colors.inverseSurface, borderRadius: BorderRadius.circular(4)),
                titleStyle: text.titleSmall?.copyWith(color: colors.onInverseSurface),
                bodyStyle: text.bodyMedium?.copyWith(color: colors.onInverseSurface),
                actionStyle: TextButton.styleFrom(foregroundColor: colors.inversePrimary),
                destructiveActionStyle: TextButton.styleFrom(foregroundColor: colors.inversePrimary),
                replyTextStyle: text.bodyMedium?.copyWith(color: colors.onInverseSurface),
              ),
        );
      },
    );
  }

  /// A popup: in the middle of the screen, growing in; it stays until tapped, answered or swiped away ([stays]).
  factory BannerLook.popup({InAppNotificationBannerStyle? style, bool stays = true, Duration showFor = const Duration(seconds: 6)}) {
    return BannerLook(
      alignment: Alignment.center,
      transitionBuilder: InAppNotificationMotion.pop,
      stays: stays,
      showFor: showFor,
      builder: (context, message, onOpen, onDismiss) {
        final colors = Theme.of(context).colorScheme;
        return InAppNotificationBanner(
          message: message,
          onOpen: onOpen,
          onDismiss: onDismiss,
          style:
              style ??
              InAppNotificationBannerStyle(
                margin: const EdgeInsets.all(32),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 32, offset: Offset(0, 8))],
                ),
                bodyMaxLines: 6,
                imageSize: 56,
              ),
        );
      },
    );
  }

  /// What it shows (`InAppNotificationBanner` with its own style, say); the gate's builder when null.
  final InAppNotificationBuilder? builder;

  /// The edge it comes in from and is swiped out to; the gate's when null.
  final BannerEdge? edge;

  /// Where it sits; at its [edge] when null.
  final AlignmentGeometry? alignment;

  /// Its coming and going; from its [edge] as Discord's when null.
  final AnimatedSwitcherTransitionBuilder? transitionBuilder;

  /// How long it shows; the gate's when null.
  final Duration? showFor;

  /// True: it doesn't go by itself, only tapped, answered or swiped away.
  final bool stays;

  /// How long it takes to come and to go; the gate's when null.
  final Duration? enter;
  final Duration? exit;

  /// This look with what is given changed.
  BannerLook copyWith({
    InAppNotificationBuilder? builder,
    BannerEdge? edge,
    AlignmentGeometry? alignment,
    AnimatedSwitcherTransitionBuilder? transitionBuilder,
    Duration? showFor,
    bool? stays,
    Duration? enter,
    Duration? exit,
  }) {
    return BannerLook(
      builder: builder ?? this.builder,
      edge: edge ?? this.edge,
      alignment: alignment ?? this.alignment,
      transitionBuilder: transitionBuilder ?? this.transitionBuilder,
      showFor: showFor ?? this.showFor,
      stays: stays ?? this.stays,
      enter: enter ?? this.enter,
      exit: exit ?? this.exit,
    );
  }
}
