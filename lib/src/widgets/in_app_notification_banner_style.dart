import 'package:flutter/material.dart';

/// How `InAppNotificationBanner` looks: every value optional; a missing one falls back to the app's theme. Give the
/// app's own design values here, or replace a whole part with the banner's builders.
@immutable
class InAppNotificationBannerStyle {
  const InAppNotificationBannerStyle({
    this.margin,
    this.padding,
    this.decoration,
    this.titleStyle,
    this.bodyStyle,
    this.bodyMaxLines,
    this.imageSize,
    this.imageRadius,
    this.gap,
    this.actionsAlignment,
    this.actionStyle,
    this.destructiveActionStyle,
    this.replyDecoration,
    this.replyTextStyle,
    this.dismissDirection = DismissDirection.up,
    this.dismissible = true,
    this.safeArea = true,
  });

  /// Around the card (from the screen's edges).
  final EdgeInsetsGeometry? margin;

  /// Inside the card.
  final EdgeInsetsGeometry? padding;

  /// The card itself: its colour, corners, border and shadow.
  final BoxDecoration? decoration;

  final TextStyle? titleStyle;
  final TextStyle? bodyStyle;
  final int? bodyMaxLines;

  /// The image's side, shown at the start; null hides it.
  final double? imageSize;
  final BorderRadius? imageRadius;

  /// Between the parts.
  final double? gap;

  final MainAxisAlignment? actionsAlignment;
  final ButtonStyle? actionStyle;
  final ButtonStyle? destructiveActionStyle;

  /// The reply field's look.
  final InputDecoration? replyDecoration;
  final TextStyle? replyTextStyle;

  /// Which way it is swiped away.
  final DismissDirection dismissDirection;

  /// False: it can't be swiped away.
  final bool dismissible;

  /// Kept clear of the status bar and notch.
  final bool safeArea;
}
