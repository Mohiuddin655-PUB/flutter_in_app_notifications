# Android setup

What an Android app needs for `in_app_notifications` with Firebase Cloud Messaging and `flutter_local_notifications`
(see [app_setup.md](app_setup.md) for the Dart side).

## 1. Firebase

- Add the Android app in the Firebase console (its package name, and the SHA-1/SHA-256 of every signing key) and put
  `google-services.json` in `android/app/` (per flavor, `android/app/src/<flavor>/`), or use `flutterfire configure`.
- FCM needs Google Play services: test on a real phone or an emulator image **with Google Play**.

## 2. `android/app/build.gradle.kts`

`flutter_local_notifications` needs core library desugaring; the build stops (`checkDebugAarMetadata`) without it.

```kotlin
android {
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
```

## 3. `android/app/src/main/AndroidManifest.xml`

```xml
<manifest ...>
    <!-- Android 13+: nothing shows in the notification bar without it (asked at run time, see app_setup.md step 6). -->
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <!-- Scheduled notifications come back after a restart. -->
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />

    <application ...>
        <!-- Without these two, a scheduled notification's alarm goes off and nothing shows: the plugin doesn't
             declare them itself. -->
        <receiver
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"
            android:exported="false" />
        <receiver
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver"
            android:exported="false">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
            </intent-filter>
        </receiver>

        <!-- What the system uses for a push it shows itself (app in the background or closed). The channel id is the
             one the display delegate creates, so pushes and the app's own notifications share one channel. -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_channel_id"
            android:value="updates" />
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_icon"
            android:resource="@drawable/ic_stat" />
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_color"
            android:resource="@color/notification_color" />
    </application>
</manifest>
```

- `ic_stat` is a **white-on-transparent** small icon in `res/drawable*` (a coloured icon shows as a grey square).
  `AndroidInitializationSettings('ic_stat')` uses the same one.
- `notification_color` lives in `res/values/colors.xml`.
- Exact alarms (a scheduled notification to the second) need `SCHEDULE_EXACT_ALARM` and the user's say-so; the setup
  in app_setup.md uses inexact alarms, which Android may move by a few minutes.

## 4. How Android behaves (for testing)

| State | A push | Tapped |
| --- | --- | --- |
| Open | not shown by the system: the display delegate shows it, or the app's banner (`inApp`) | `display.tapped` / `InAppNotifications.open` |
| Background | the system shows it on the default channel | `messaging.tapped` |
| Closed (swiped away) | the system shows it (FCM starts the app's process to deliver it) | `messaging.initial` at the next launch |
| Force-stopped (Settings › Force stop) | **not delivered**, not even after reopening: Android's rule | — |
| Permission off | nothing in the bar; the in-app banner still shows while open | — |

- Grant or revoke the permission while testing: `adb shell pm grant|revoke <package> android.permission.POST_NOTIFICATIONS`.
- An emulator restored from a snapshot keeps an FCM token the server has dropped (`NotRegistered`): sign out and in
  again (`clear` lets the token go, `start` gets a new one), or cold boot. Real phones don't do this.
- Move the clock for scheduled notifications: `adb shell settings put global auto_time 0`, then
  `adb shell cmd alarm set-time <epoch millis>`; set `auto_time` back to 1 after. A notification whose time the clock
  jumps past shows at once; moving the clock back delays it.
