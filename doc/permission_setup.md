# Permission setup

Only the notification permission (Android 13+ and iOS). Ask it with any one of these.

## firebase_messaging (recommended)

Nothing more to add: the app has it already.

```dart
await FirebaseMessaging.instance.requestPermission();
```

## Or permission_handler

```dart
await Permission.notification.request();
```

On iOS, turn it on in `ios/Podfile`, or it always says denied:

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    ...
    target.build_configurations.each do |config|
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['$(inherited)', 'PERMISSION_NOTIFICATIONS=1']
    end
  end
end
```

## Or flutter_local_notifications

```dart
final plugin = FlutterLocalNotificationsPlugin();
await plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
    ?.requestNotificationsPermission();                                     // Android 13+
await plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
    ?.requestPermissions(alert: true, badge: true, sound: true);            // iOS
```
