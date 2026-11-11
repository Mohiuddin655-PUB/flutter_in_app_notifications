import 'package:flutter/widgets.dart';

/// Which edge of the screen the banner shows at: it comes in from there, and is swiped back out that way.
enum BannerEdge {
  top,
  bottom;

  /// The way out, in screen terms: up (-1) from the top, down (1) from the bottom.
  double get outward => this == top ? -1 : 1;

  /// Where on the screen it sits.
  AlignmentGeometry get alignment => this == top ? AlignmentDirectional.topCenter : AlignmentDirectional.bottomCenter;

  /// The edge it shrinks toward as it goes.
  Alignment get anchor => this == top ? Alignment.topCenter : Alignment.bottomCenter;

  /// The edge the app shows the banner at, for its parts (the banner, its drag); top when the app says none.
  static BannerEdge of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<BannerEdgeScope>()?.edge ?? top;
}

/// Tells the banner and its drag which edge the app shows it at (a banner at the bottom: [BannerEdge.bottom]).
class BannerEdgeScope extends InheritedWidget {
  const BannerEdgeScope({super.key, required this.edge, required super.child});

  final BannerEdge edge;

  @override
  bool updateShouldNotify(BannerEdgeScope oldWidget) => edge != oldWidget.edge;
}
