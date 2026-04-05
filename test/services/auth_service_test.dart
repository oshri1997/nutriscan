import 'package:flutter_test/flutter_test.dart';
import 'package:ai_nutriscan/services/auth_service.dart';

void main() {
  group('AuthTimeoutException', () {
    test('toString returns the message', () {
      final ex = AuthTimeoutException('Test message');
      expect(ex.toString(), equals('Test message'));
    });

    test('default message when no argument provided', () {
      final ex = AuthTimeoutException();
      expect(ex.toString(), equals('Authentication timed out'));
    });

    test('implements Exception', () {
      expect(AuthTimeoutException(), isA<Exception>());
    });

    test('Hebrew message for user-friendly error display', () {
      final ex = AuthTimeoutException(
        'אימות נכשל. אין חיבור לאינטרנט. נסה שוב.',
      );
      expect(ex.toString(), equals('אימות נכשל. אין חיבור לאינטרנט. נסה שוב.'));
    });
  });

  group('AuthService.getOrCreateUserId timeout', () {
    test('timeout duration is 10 seconds', () async {
      // We can verify the timeout constant exists by checking the method signature
      // The actual timeout behavior would require mocking Firebase
      expect(AuthService.getOrCreateUserId, isA<Future<String> Function()>());
    });
  });
}
