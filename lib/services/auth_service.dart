import 'package:firebase_auth/firebase_auth.dart';

class AuthTimeoutException implements Exception {
  final String message;
  AuthTimeoutException([this.message = 'Authentication timed out']);
  @override
  String toString() => message;
}

class AuthService {
  static final _auth = FirebaseAuth.instance;
  static const _timeout = Duration(seconds: 10);

  /// Returns current user UID, signing in anonymously if needed.
  /// Throws if anonymous sign-in fails or times out after 10 seconds.
  static Future<String> getOrCreateUserId() async {
    Future<String> getUserId() async {
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

    return getUserId().timeout(
      _timeout,
      onTimeout: () => throw AuthTimeoutException(
        'אימות נכשל. אין חיבור לאינטרנט. נסה שוב.',
      ),
    );
  }

  /// Returns the current authenticated user ID.
  /// Throws if no user is authenticated (no silent fallback to empty string).
  static String get currentUserId {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('User not authenticated. Please restart the app.');
    }
    return uid;
  }
}
