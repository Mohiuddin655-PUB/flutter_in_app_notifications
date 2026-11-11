import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:in_app_notifications/in_app_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fcm_messaging_delegate.dart';
import 'firestore_token_store_delegate.dart';
import 'local_display_delegate.dart';
import 'preferences_schedule_store_delegate.dart';
import 'push_background.dart';

/// Notifications, ready at launch: call [init] in `main`, before `runApp`.
///
/// ```dart
/// Future<void> main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await PushSetup.init();
///   runApp(const App());
/// }
/// ```
abstract final class PushSetup {
  /// Where a notification shows while the app is open: `bar` (the phone's), `inApp` (the app's, and quietly in the
  /// bar), or `inAppOnly`.
  static const whileOpen = WhileOpen.inApp;

  static Future<void> init() async {
    await Firebase.initializeApp();
    final prefs = await SharedPreferences.getInstance();
    await InAppNotifications.init(
      // A push while the app isn't in front, handled from here on.
      messaging: const FcmMessagingDelegate(background: PushBackground.pushed),
      display: LocalDisplayDelegate(systemWhileOpen: whileOpen == WhileOpen.bar, background: PushBackground.answered),
      tokens: FirestoreTokenStoreDelegate(prefs),
      schedules: PreferencesScheduleStoreDelegate(prefs),
      whileOpen: whileOpen,
      categories: PushBackground.categories,
      onAction: PushBackground.onAction,
      // Every failure inside is reported here, never thrown: the app starts without pushes. Send it to the app's crash
      // reporting (Crashlytics, say).
      onError: (error, stack, where) => debugPrint('in_app_notifications ($where): $error'),
    );
  }
}
