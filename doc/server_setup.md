# Server setup

To send a push to another phone, the server sends to the tokens kept on its account.

## 1. The key

Firebase console (<https://console.firebase.google.com>) › Project settings › Service accounts › **Generate new
private key**: a JSON file the server signs in with. Keep it on the server only, never in the app.

## 2. Send

With the Firebase Admin SDK (Node.js here; Python, Go, Java and C# work the same way):

```js
const admin = require('firebase-admin');
admin.initializeApp({credential: admin.credential.cert(require('./service-account.json'))});

async function sendTo(uid) {
  const devices = await admin.firestore().collection(`accounts/${uid}/devices`).get(); // the tokens the app kept
  const tokens = devices.docs.map((d) => d.id);
  if (tokens.length === 0) return;

  const res = await admin.messaging().sendEachForMulticast({
    tokens,
    data: {title: 'Nadia', body: 'Are you coming?', category: 'chat', group: 'chat-42',
           image: 'https://…/photo.jpg', page: 'chats', chatId: '42'},   // Android: data-only, the app shows it
    android: {priority: 'high'},
    apns: {payload: {aps: {alert: {title: 'Nadia', body: 'Are you coming?'},   // iOS shows this part itself
                           category: 'chat', 'thread-id': 'chat-42', 'mutable-content': 1}},
           fcmOptions: {imageUrl: 'https://…/photo.jpg'}},
  });

  // A token no longer registered (the app removed, or signed out without clear()): delete it.
  res.responses.forEach((r, i) => {
    if (r.error?.code === 'messaging/registration-token-not-registered') devices.docs[i].ref.delete();
  });
}
```

- `data`: every value a string. `page` and the rest reach `InAppNotifications.take()` when it is tapped.
- `category`: the same id as one of the app's categories, so it shows that kind's actions.
- Without the Admin SDK: `POST https://fcm.googleapis.com/v1/projects/{project-id}/messages:send`, one token a call,
  with an OAuth token made from the same key.
