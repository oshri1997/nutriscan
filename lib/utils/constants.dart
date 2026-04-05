import '../config/env_config.dart';

class AppConstants {
  // Gemini model configuration
  static const geminiModel = 'gemini-2.5-flash';

  // Note: geminiApiKey and revenueCatApiKey have been moved to
  // environment variables. Access them via EnvConfig:
  //   EnvConfig.geminiApiKey
  //   EnvConfig.revenueCatApiKey
  //
  // Configure via .env file or environment variables.
  // See .env.example for required variables.

  static const maxFreeScansPerDay = 3;
  static const appName = 'NutriSnap';

  // RevenueCat entitlement ID
  static const proEntitlementId = 'nutiration Pro';

  // Product IDs as configured in RevenueCat (monthly/yearly packages)
  static const monthlyProductId = 'monthly';
  static const yearlyProductId = 'yearly';
}
