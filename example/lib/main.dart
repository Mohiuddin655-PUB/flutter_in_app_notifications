import 'package:flutter/material.dart';
import 'package:in_app_notifications/in_app_notifications.dart';

/// The banner of in_app_notifications on its own: no setup, no pushes. Wrap the app in [InAppNotificationGate], call
/// [InAppNotifications.show].
void main() {
  // Optional: what a kind of message offers.
  InAppNotifications.categories = const [
    NotificationCategory(id: 'request', actions: [
      NotificationAction(id: 'accept', title: 'Accept'),
      NotificationAction(id: 'reject', title: 'Reject', destructive: true),
    ]),
    NotificationCategory(id: 'chat', actions: [
      NotificationAction(id: 'reply', title: 'Reply', input: true, inputHint: 'Message', inputButton: 'Send'),
    ]),
  ];
  runApp(const ExampleApp());
}

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  var _edge = BannerEdge.top;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Banner example',
      theme: ThemeData(colorSchemeSeed: const Color(0xFFFF704D)),
      builder: (context, child) => InAppNotificationGate(
        edge: _edge,
        builder: (context, message, onOpen, onDismiss) => InAppNotificationBanner(message: message, onOpen: onOpen, onDismiss: onDismiss),
        child: child!,
      ),
      home: _Home(edge: _edge, onEdge: (edge) => setState(() => _edge = edge)),
    );
  }
}

class _Home extends StatefulWidget {
  const _Home({required this.edge, required this.onEdge});

  final BannerEdge edge;
  final ValueChanged<BannerEdge> onEdge;

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
          SegmentedButton<BannerEdge>(
            segments: const [
              ButtonSegment(value: BannerEdge.top, label: Text('Top')),
              ButtonSegment(value: BannerEdge.bottom, label: Text('Bottom')),
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
          const SizedBox(height: 24),
          Text(_last, key: const Key('last'), style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
