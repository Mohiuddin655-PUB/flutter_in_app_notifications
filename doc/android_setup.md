# Android setup

## 1. Firebase

Add the Android app in the Firebase console (<https://console.firebase.google.com>) and put `google-services.json` in `android/app/` (or run
`flutterfire configure`). Test on a phone or an emulator **with Google Play**.

## 2. `android/app/build.gradle.kts`

```kotlin
android {
    ...
    compileOptions {
        ...
        isCoreLibraryDesugaringEnabled = true  // turns on desugaring: flutter_local_notifications needs it, or the build stops
    }
}

dependencies {
    ...
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")  // the library that runs newer Java on older Android; 2.1.4 or newer: if the app already has a newer one, keep it
}
```

## 3. `android/app/src/main/AndroidManifest.xml` (recommended)

The permissions and receivers come with the package. Add only the defaults for a push the system shows:

```xml
<application ...>
    ...
    <!-- A push the system shows (the app in the background or closed) goes to the app's channel. -->
    <meta-data
        android:name="com.google.firebase.messaging.default_notification_channel_id"
        android:value="updates" />
    <!-- Its small icon: without it, the app's icon shows as a grey square. -->
    <meta-data
        android:name="com.google.firebase.messaging.default_notification_icon"
        android:resource="@drawable/ic_stat" />
    <!-- Its colour. -->
    <meta-data
        android:name="com.google.firebase.messaging.default_notification_color"
        android:resource="@color/notification_color" />
</application>
```

- `updates`: the same channel id as the display delegate's.

Create both resources, or the build stops:
- `res/drawable/ic_stat.png`: a **white-on-transparent** icon.
- `notification_color` in `res/values/colors.xml`: `<color name="notification_color">#FF704D</color>`.
