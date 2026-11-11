import 'package:flutter/material.dart';
import 'package:in_app_notifications/in_app_notifications.dart';

import 'in_app_notification_host.dart';

/// The in-app notification of in_app_notifications on its own: no setup, no pushes. The app draws
/// [InAppNotifications.inApp] where it shows its overlays ([InAppNotificationHost] here) and calls [InAppNotifications.show].
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
  var _edge = InAppNotificationEdge.top;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Banner example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFFFF704D)),
      builder: (context, child) => InAppNotificationHost(edge: _edge, child: child!),
      home: _Home(edge: _edge, onEdge: (edge) => setState(() => _edge = edge)),
    );
  }
}

class _Home extends StatefulWidget {
  const _Home({required this.edge, required this.onEdge});

  final InAppNotificationEdge edge;
  final ValueChanged<InAppNotificationEdge> onEdge;

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
          SegmentedButton<InAppNotificationEdge>(
            segments: const [
              ButtonSegment(value: InAppNotificationEdge.top, label: Text('Top')),
              ButtonSegment(value: InAppNotificationEdge.bottom, label: Text('Bottom')),
            ],
            selected: {widget.edge},
            onSelectionChanged: (s) => widget.onEdge(s.first),
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
          const SizedBox(height: 24),
          Text(_last, key: const Key('last'), style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
