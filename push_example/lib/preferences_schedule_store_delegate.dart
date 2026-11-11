import 'package:in_app_notifications/in_app_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The notifications scheduled on this phone, kept in shared_preferences between launches. Optional: with it, one whose
/// time comes while the app is open shows as `whileOpen` says; without it, the phone shows it by itself.
class PreferencesScheduleStoreDelegate implements ScheduleStoreDelegate {
  const PreferencesScheduleStoreDelegate(this.prefs);

  final SharedPreferences prefs;

  static const _key = 'push_schedules';

  @override
  String? read() => prefs.getString(_key);

  @override
  Future<void> write(String? text) async {
    text == null ? await prefs.remove(_key) : await prefs.setString(_key, text);
  }
}
