# pubspec.yaml

**For the best result**, add:

```yaml
dependencies:
  ...
  in_app_notifications: ^0.17.0         # the latest version (required)
  firebase_core: ^4.0.0                 # the latest version
  firebase_messaging: ^16.0.0           # the latest version (recommended; or another push service)
  flutter_local_notifications: ^23.0.0  # the latest version (recommended; or another local notifications plugin)
  timezone: ^0.11.0                     # the latest version
```

Where tokens are kept is your choice; [push_example](../push_example/lib) uses Firestore and `shared_preferences`.

Then run `flutter pub get`, and set up the native side: [Android](android_setup.md), [iOS](ios_setup.md).
