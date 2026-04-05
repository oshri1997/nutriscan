import 'package:flutter_test/flutter_test.dart';
import 'package:ai_nutriscan/config/env_config.dart';

void main() {
  group('EnvConfig', () {
    tearDown(() {
      // Reset EnvConfig state between tests
      EnvConfig.initialize(
        geminiApiKey: '',
        revenueCatApiKey: '',
      );
    });

    group('initialize', () {
      test('stores provided API keys', () {
        EnvConfig.initialize(
          geminiApiKey: 'test_gemini_key',
          revenueCatApiKey: 'test_revenuecat_key',
        );

        expect(EnvConfig.geminiApiKey, 'test_gemini_key');
        expect(EnvConfig.revenueCatApiKey, 'test_revenuecat_key');
      });

      test('isConfigured returns true when all keys are provided', () {
        EnvConfig.initialize(
          geminiApiKey: 'test_gemini_key',
          revenueCatApiKey: 'test_revenuecat_key',
        );

        expect(EnvConfig.isConfigured, true);
      });

      test('isConfigured returns false when keys are missing', () {
        EnvConfig.initialize(
          geminiApiKey: '',
          revenueCatApiKey: '',
        );

        expect(EnvConfig.isConfigured, false);
      });
    });

    group('missingVariables', () {
      test('returns empty list when all keys are provided', () {
        EnvConfig.initialize(
          geminiApiKey: 'test_gemini_key',
          revenueCatApiKey: 'test_revenuecat_key',
        );

        expect(EnvConfig.missingVariables, isEmpty);
      });

      test('returns missing variable names when keys are empty', () {
        EnvConfig.initialize(
          geminiApiKey: '',
          revenueCatApiKey: '',
        );

        expect(EnvConfig.missingVariables, contains('GEMINI_API_KEY'));
        expect(EnvConfig.missingVariables, contains('REVENUECAT_API_KEY'));
      });

      test('returns only missing variable name when one key is provided', () {
        EnvConfig.initialize(
          geminiApiKey: 'test_gemini_key',
          revenueCatApiKey: '',
        );

        expect(EnvConfig.missingVariables, isNot(contains('GEMINI_API_KEY')));
        expect(EnvConfig.missingVariables, contains('REVENUECAT_API_KEY'));
      });
    });

    group('geminiApiKey', () {
      test('throws StateError when not configured', () {
        EnvConfig.initialize(
          geminiApiKey: '',
          revenueCatApiKey: 'test_revenuecat_key',
        );

        expect(
          () => EnvConfig.geminiApiKey,
          throwsA(isA<StateError>()),
        );
      });

      test('returns configured value', () {
        EnvConfig.initialize(
          geminiApiKey: 'test_gemini_key',
          revenueCatApiKey: 'test_revenuecat_key',
        );

        expect(EnvConfig.geminiApiKey, 'test_gemini_key');
      });
    });

    group('revenueCatApiKey', () {
      test('throws StateError when not configured', () {
        EnvConfig.initialize(
          geminiApiKey: 'test_gemini_key',
          revenueCatApiKey: '',
        );

        expect(
          () => EnvConfig.revenueCatApiKey,
          throwsA(isA<StateError>()),
        );
      });

      test('returns configured value', () {
        EnvConfig.initialize(
          geminiApiKey: 'test_gemini_key',
          revenueCatApiKey: 'test_revenuecat_key',
        );

        expect(EnvConfig.revenueCatApiKey, 'test_revenuecat_key');
      });
    });
  });
}
