import 'dart:async' show Timer;

import 'package:flutter/material.dart';

import '../../keys/notification_keys.dart';
import '../in_app_notifications.dart';
import '../models/in_app_notification_data.dart';
import '../models/push_message.dart';

/// Shows `InAppNotifications.inApp` over the app's pages: when it comes, how long it stays ([showFor]), where
/// ([alignmentFor]) and how it comes and goes ([transitionBuilder]). It also handles what a finger does on it: a tap
/// opens it ([openOnTap]), a swipe toward its edge takes it away ([dismissible]), and a finger on it or a text field
/// typed in stops its time. How it looks, and what its buttons do, is the app's [builder].
/// Put it in `MaterialApp.builder`, where the app's theme and text direction are:
///
/// ```dart
/// MaterialApp(builder: (context, child) => InAppNotificationHost(builder: (context, data) => MyCard(data), child: child!));
/// ```
class InAppNotificationHost extends StatefulWidget {
  const InAppNotificationHost({
    super.key,
    required this.builder,
    required this.child,
    this.showFor = const Duration(seconds: 4),
    this.alignmentFor,
    this.duration = const Duration(milliseconds: 460),
    this.reverseDuration = const Duration(milliseconds: 240),
    this.transitionBuilder,
    this.openOnTap = true,
    this.dismissible = true,
  });

  /// The in-app notification, drawn by the app from its data.
  final Widget Function(BuildContext context, InAppNotificationData data) builder;

  /// The app's pages.
  final Widget child;

  /// How long it stays.
  final Duration showFor;

  /// Where it shows, by its look: at the top when null.
  final Alignment Function(String? look)? alignmentFor;

  /// Coming in, and going out.
  final Duration duration;
  final Duration reverseDuration;

  /// How it comes and goes: by default it slides in from its edge (fading in the middle).
  final Widget Function(Widget child, Animation<double> animation, Alignment alignment)? transitionBuilder;

  /// A tap on it opens it (`InAppNotifications.open`); its own buttons still take their taps.
  final bool openOnTap;

  /// A swipe toward its edge (up at the top, down at the bottom, either in the middle) takes it away.
  final bool dismissible;

  /// Slides in from the edge it shows at, and fades; in the middle, fades and grows.
  static Widget slide(Widget child, Animation<double> animation, Alignment alignment) {
    final fade = FadeTransition(opacity: animation, child: child);
    if (alignment.y == 0) return ScaleTransition(scale: Tween(begin: 0.9, end: 1.0).animate(animation), child: fade);
    final from = Offset(0, alignment.y < 0 ? -1 : 1);
    return SlideTransition(
      position: Tween(begin: from, end: Offset.zero).animate(animation),
      child: fade,
    );
  }

  @override
  State<InAppNotificationHost> createState() => _InAppNotificationHostState();
}

class _InAppNotificationHostState extends State<InAppNotificationHost> with SingleTickerProviderStateMixin {
  late final _time = AnimationController(vsync: this, duration: widget.showFor)..addStatusListener(_ended);

  /// Whether its layer is over the pages: from when one comes until the last has finished leaving. Without one, the
  /// host is only the pages.
  late bool _layer = InAppNotifications.inApp.value != null;
  Timer? _gone;

  @override
  void initState() {
    super.initState();
    InAppNotifications.inApp.addListener(_restart);
    InAppNotifications.holding.addListener(_held);
    _restart();
  }

  @override
  void didUpdateWidget(InAppNotificationHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _time.duration = widget.showFor;
  }

  @override
  void dispose() {
    InAppNotifications.inApp.removeListener(_restart);
    InAppNotifications.holding.removeListener(_held);
    _gone?.cancel();
    _time.dispose();
    super.dispose();
  }

  /// A new one starts its time from the full; the layer goes once the last has left.
  void _restart() {
    _time.reset();
    _held();
    _gone?.cancel();
    if (InAppNotifications.inApp.value != null) {
      if (!_layer) setState(() => _layer = true);
    } else if (_layer) {
      _gone = Timer(widget.reverseDuration, () {
        if (mounted && InAppNotifications.inApp.value == null) setState(() => _layer = false);
      });
    }
  }

  /// Its time stops while held, and goes on after.
  void _held() {
    if (InAppNotifications.inApp.value == null || InAppNotifications.holding.value) {
      _time.stop();
    } else {
      _time.forward();
    }
  }

  void _ended(AnimationStatus status) {
    if (status == AnimationStatus.completed) InAppNotifications.dismiss();
  }

  @override
  Widget build(BuildContext context) {
    // The pages keep their place; the layer is added over them only while one shows.
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_layer) _Layer(host: this),
      ],
    );
  }

  Widget _placed(PushMessage message) {
    final alignment = widget.alignmentFor?.call(message.data[NotificationKeys.look]) ?? Alignment.topCenter;
    return _Placed(
      key: ValueKey(message),
      alignment: alignment,
      child: _Handled(
        message: message,
        alignment: alignment,
        openOnTap: widget.openOnTap,
        dismissible: widget.dismissible,
        child: AnimatedBuilder(
          animation: _time,
          builder: (context, _) => widget.builder(context, InAppNotificationData(message: message, remaining: 1 - _time.value)),
        ),
      ),
    );
  }
}

/// The in-app notification where it shows; the transition reads its [alignment].
class _Placed extends StatelessWidget {
  const _Placed({super.key, required this.alignment, required this.child});

  final Alignment alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) => Align(alignment: alignment, child: child);
}

/// What a finger does on the in-app notification, around the app's design: a finger on it or a text field in it
/// focused stops its time, a tap opens it, a swipe toward its edge takes it away.
class _Handled extends StatefulWidget {
  const _Handled({required this.message, required this.alignment, required this.openOnTap, required this.dismissible, required this.child});

  final PushMessage message;
  final Alignment alignment;
  final bool openOnTap;
  final bool dismissible;
  final Widget child;

  @override
  State<_Handled> createState() => _HandledState();
}

class _HandledState extends State<_Handled> {
  void _hold(String reason, bool on) => InAppNotifications.hold(on, reason: (reason, widget.message.id));

  @override
  void dispose() {
    _hold('finger', false);
    _hold('typing', false);
    super.dispose();
  }

  void _swiped(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    final y = widget.alignment.y;
    final away = y < 0 ? v < -300 : (y > 0 ? v > 300 : v.abs() > 300);
    if (away) InAppNotifications.dismiss();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (on) => _hold('typing', on), // a text field inside it focused
      child: Listener(
        onPointerDown: (_) => _hold('finger', true),
        onPointerUp: (_) => _hold('finger', false),
        onPointerCancel: (_) => _hold('finger', false),
        child: GestureDetector(
          onTap: widget.openOnTap ? InAppNotifications.open : null,
          // A hold isn't a tap: let go, it goes on its time instead of opening.
          onLongPress: widget.openOnTap ? () {} : null,
          onVerticalDragEnd: widget.dismissible ? _swiped : null,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Over the pages while an in-app notification shows: above the keyboard, with an Overlay and a Material of its own
/// (the app's text fields and buttons work in it). Its first frame is empty, so the first one comes in animated.
class _Layer extends StatefulWidget {
  const _Layer({required this.host});

  final _InAppNotificationHostState host;

  @override
  State<_Layer> createState() => _LayerState();
}

class _LayerState extends State<_Layer> {
  var _entered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _entered = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final host = widget.host;
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final transition = host.widget.transitionBuilder ?? InAppNotificationHost.slide;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: MediaQuery(
        data: media.removeViewInsets(removeBottom: true).removePadding(removeBottom: keyboard > 0),
        child: Overlay.wrap(
          child: Material(
            type: MaterialType.transparency,
            child: ValueListenableBuilder<PushMessage?>(
              valueListenable: InAppNotifications.inApp,
              builder: (context, message, _) => AnimatedSwitcher(
                duration: host.widget.duration,
                reverseDuration: host.widget.reverseDuration,
                // The card itself moves (by its own size), placed where it shows.
                transitionBuilder: (child, animation) =>
                    child is _Placed ? Align(alignment: child.alignment, child: transition(child.child, animation, child.alignment)) : child,
                layoutBuilder: (current, previous) => Stack(fit: StackFit.expand, children: [...previous, ?current]),
                child: message == null || !_entered ? const SizedBox.shrink() : host._placed(message),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
