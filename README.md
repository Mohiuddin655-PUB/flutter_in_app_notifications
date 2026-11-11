# in_app_notifications

Push notifications for any push service and backend: the phone's **token** kept on the signed-in account, a push
**shown while the app is open**, and the **page a tapped push opens**. It has no dependencies: the app gives the push
service, the display and the storage through small delegates.

<p align="center">
  <img src="https://raw.githubusercontent.com/Mohiuddin655-PUB/flutter_in_app_notifications/main/doc/images/banner.png" width="300" alt="An in-app notification with its actions, at the top of an app">
</p>

<sub>An in-app notification, with its actions (the example, Android emulator).</sub>

## What it does

- **Pushes and the phone's own notifications**, the same way: a token kept on the account, shown in the notification
  bar, scheduled, cancelled.
- **Inside the app while it is open**, when the app wants: it says which message to show and when it is held; the app
  draws it where it shows its overlays.
- **A ready in-app notification** (`InAppNotificationView`), moving as Discord's: it comes down fading in and growing,
  a finger holds it, a drag moves it with the finger, a let-go carries it out or springs it back. Every visible part
  is the app's: a style for the look, and a builder for any part.
- **Actions and replies** (Accept, Reject, a typed reply) on the notification and inside the app, handled even when
  the app was closed.
- **Images, groups, sounds, badges, progress, urgent ones**, on Android and iOS.
- **Only notifications**: toasts, popups and other overlays are the app's.

## Use it

1. **[Setup, A to Z](doc/setup.md)**: everything an app does, step by step, in code.
2. [App setup, in depth](doc/app_setup.md): each step explained.
3. [Android setup](doc/android_setup.md): Firebase, desugaring, the manifest, and how Android behaves when testing.
4. [iOS setup](doc/ios_setup.md): the APNs key, Push Notifications and Background Modes, the AppDelegate, a push's
   image, and how iOS behaves when testing.

Ready code to copy: [push_example](push_example/lib) (Firebase Cloud Messaging, flutter_local_notifications,
Firestore, shared_preferences). The [example](example/lib) shows an in-app notification on its own, with actions and a
reply.
