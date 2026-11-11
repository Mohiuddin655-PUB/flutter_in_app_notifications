import 'package:flutter/material.dart';
import 'package:in_app_notifications/in_app_notifications.dart';

import 'notification_card.dart';

/// The in-app notification of in_app_notifications on its own: no setup, no pushes. [InAppNotificationHost] shows it
/// with the app's own design ([NotificationCard]), and the app calls [InAppNotifications.show].
void main() {
  // Optional: what a kind of message offers.
  InAppNotifications.categories = const [
    NotificationCategory(
      id: 'request',
      actions: [
        NotificationAction(id: 'accept', title: 'Accept'),
        NotificationAction(id: 'reject', title: 'Reject', destructive: true),
      ],
    ),
    NotificationCategory(
      id: 'many',
      actions: [
        NotificationAction(id: 'like', title: 'Like'),
        NotificationAction(id: 'save', title: 'Save for later'),
        NotificationAction(id: 'share', title: 'Share with friends'),
        NotificationAction(id: 'mute', title: 'Mute'),
        NotificationAction(id: 'report', title: 'Report', destructive: true),
      ],
    ),
    NotificationCategory(
      id: 'undo',
      actions: [NotificationAction(id: 'undo', title: 'Undo')],
    ),
    NotificationCategory(
      id: 'chat',
      actions: [NotificationAction(id: 'reply', title: 'Reply', input: true, inputHint: 'Message', inputButton: 'Send')],
    ),
  ];
  runApp(const ExampleApp());
}

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  var _top = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Banner example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFFFF704D)),
      builder: (context, child) => InAppNotificationHost(
        builder: (context, data) => NotificationCard(data),
        alignmentFor: (look) => look == 'black' ? Alignment.center : (_top ? Alignment.topCenter : Alignment.bottomCenter),
        child: child!,
      ),
      home: _Home(top: _top, onTop: (top) => setState(() => _top = top)),
    );
  }
}

class _Home extends StatefulWidget {
  const _Home({required this.top, required this.onTop});

  final bool top;
  final ValueChanged<bool> onTop;

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  String _last = 'Nothing yet';

  @override
  void initState() {
    super.initState();
    InAppNotifications.actions.listen((a) => setState(() => _last = 'Action: ${a.actionId}${a.input == null ? '' : ' "${a.input}"'}'));
    InAppNotifications.opened.addListener(() {
      final data = InAppNotifications.take();
      if (data != null) setState(() => _last = 'Opened: $data');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Banner, no setup')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Top')),
              ButtonSegment(value: false, label: Text('Bottom')),
            ],
            selected: {widget.top},
            onSelectionChanged: (s) => widget.onTop(s.first),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => InAppNotifications.show(title: 'Saved', body: 'Your profile is up to date', data: const {'page': 'profile'}),
            child: const Text('Plain'),
          ),
          FilledButton(
            onPressed: () => InAppNotifications.show(
              message: const PushMessage(id: 'req', title: 'Rafi wants to connect', body: 'Accept or reject', category: 'request'),
            ),
            child: const Text('With actions'),
          ),
          FilledButton(
            onPressed: () => InAppNotifications.show(
              message: const PushMessage(id: 'chat', title: 'Nadia', body: 'Are you coming tonight?', category: 'chat'),
            ),
            child: const Text('With a reply'),
          ),
          FilledButton(
            onPressed: () => InAppNotifications.show(
              message: const PushMessage(id: 'post', title: 'New post from Nadia', category: 'many'),
            ),
            child: const Text('Many actions'),
          ),
          FilledButton(
            onPressed: () => InAppNotifications.show(title: 'A black page', body: 'Its own look', look: 'black'),
            child: const Text('Look: black'),
          ),
          const SizedBox(height: 24),
          Text(_last, key: const Key('last'), style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
