import 'package:flutter/widgets.dart';

/// Which edge of the screen the in-app notification shows at: it comes in from there, and is swiped back out that way.
enum InAppNotificationEdge {
  top,
  bottom;

  /// The way out, in screen terms: up (-1) from the top, down (1) from the bottom.
  double get outward => this == top ? -1 : 1;

  /// Where on the screen it sits.
  AlignmentGeometry get alignment => this == top ? AlignmentDirectional.topCenter : AlignmentDirectional.bottomCenter;

  /// The edge it shrinks toward as it goes.
  Alignment get anchor => this == top ? Alignment.topCenter : Alignment.bottomCenter;

  /// The edge the app shows the in-app notification at, for its parts (the in-app notification, its drag); top when the
  /// app says none.
  static InAppNotificationEdge of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<InAppNotificationEdgeScope>()?.edge ?? top;
}

/// Tells the in-app notification and its drag which edge the app shows it at (an in-app notification at the bottom:
/// [InAppNotificationEdge.bottom]).
class InAppNotificationEdgeScope extends InheritedWidget {
  const InAppNotificationEdgeScope({super.key, required this.edge, required super.child});

  final InAppNotificationEdge edge;

  @override
  bool updateShouldNotify(InAppNotificationEdgeScope oldWidget) => edge != oldWidget.edge;
}
