import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;

  /// Returns current user UID, signing in anonymously if needed.
  /// Throws if anonymous sign-in fails.
  static Future<String> getOrCreateUserId() async {
    User? user = _auth.currentUser;
    if (user == null) {
      final credential = await _auth.signInAnonymously();
      user = credential.user;
    }
    if (user == null) {
      throw Exception('Authentication failed. Please enable Anonymous auth in Firebase Console.');
    }
    return user.uid;
  }

  static String get currentUserId => _auth.currentUser?.uid ?? '';
}
