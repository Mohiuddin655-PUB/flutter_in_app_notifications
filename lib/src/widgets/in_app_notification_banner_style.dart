import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

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
    this.dismissible = true,
    this.safeArea = true,
    this.statusBarStyle,
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

  /// False: it can't be swiped away (up).
  final bool dismissible;

  /// Kept clear of the status bar and notch. False draws it from the very top, under the status bar.
  final bool safeArea;

  /// The status bar's icons while it covers them ([safeArea] false): by default dark on a light card and light on a
  /// dark one. Kept clear of it, the page's own stay.
  final SystemUiOverlayStyle? statusBarStyle;
}
