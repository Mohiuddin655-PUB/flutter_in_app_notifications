import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:in_app_notifications/in_app_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An account's push tokens on Firestore (`accounts/{uid}/devices/{token}`, where the server finds the phones to send
/// to), and the one last saved from this phone in shared_preferences, so a launch writes nothing.
class FirestoreTokenStoreDelegate implements TokenStoreDelegate {
  const FirestoreTokenStoreDelegate(this.prefs);

  final SharedPreferences prefs;

  static DocumentReference<Map<String, dynamic>> _doc(String uid, String token) => FirebaseFirestore.instance.doc('accounts/$uid/devices/$token');

  static String _local(String uid) => 'push_token_$uid';

  @override
  Future<void> save(String uid, String token) => _doc(uid, token).set({'platform': Platform.operatingSystem, 'at': FieldValue.serverTimestamp()});

  /// Short: it runs at sign-out, which waits for it.
  @override
  Future<void> remove(String uid, String token) => _doc(uid, token).delete().timeout(const Duration(seconds: 3));

  @override
  String? saved(String uid) => prefs.getString(_local(uid));

  @override
  Future<void> remember(String uid, String? token) async {
    token == null ? await prefs.remove(_local(uid)) : await prefs.setString(_local(uid), token);
  }
}
