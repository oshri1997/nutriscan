import 'package:flutter/foundation.dart';

/// Secure environment configuration for API keys and sensitive credentials.
///
/// All secrets should be provided via environment variables or .env file.
/// Keys are read at runtime to avoid hardcoding sensitive values.
class EnvConfig {
  static String _geminiApiKey = '';
  static String _revenueCatApiKey = '';

  /// Initialize environment configuration.
  /// Call this at app startup before using any API keys.
  static void initialize({
    String? geminiApiKey,
    String? revenueCatApiKey,
  }) {
    _geminiApiKey = geminiApiKey ?? const String.fromEnvironment(
      'GEMINI_API_KEY',
      defaultValue: '',
    );
    _revenueCatApiKey = revenueCatApiKey ?? const String.fromEnvironment(
      'REVENUECAT_API_KEY',
      defaultValue: '',
    );
  }

  /// Gemini API key for AI food scanning.
  /// Get your key from: https://aistudio.google.com/app/apikey
  static String get geminiApiKey {
    if (_geminiApiKey.isEmpty) {
      throw StateError(
        'GEMINI_API_KEY not configured. '
        'Set GEMINI_API_KEY environment variable or pass it to initialize().',
      );
    }
    return _geminiApiKey;
  }

  /// RevenueCat API key for subscription management.
  /// Get your key from: RevenueCat Dashboard > Project Settings > API Keys
  static String get revenueCatApiKey {
    if (_revenueCatApiKey.isEmpty) {
      throw StateError(
        'REVENUECAT_API_KEY not configured. '
        'Set REVENUECAT_API_KEY environment variable or pass it to initialize().',
      );
    }
    return _revenueCatApiKey;
  }

  /// Whether all required environment variables are configured.
  static bool get isConfigured {
    return _geminiApiKey.isNotEmpty && _revenueCatApiKey.isNotEmpty;
  }

  /// List of missing required environment variables.
  static List<String> get missingVariables {
    final missing = <String>[];
    if (_geminiApiKey.isEmpty) missing.add('GEMINI_API_KEY');
    if (_revenueCatApiKey.isEmpty) missing.add('REVENUECAT_API_KEY');
    return missing;
  }
}
