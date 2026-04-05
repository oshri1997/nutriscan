import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'config/env_config.dart';
import 'firebase_options.dart';
import 'providers/user_provider.dart';
import 'providers/diary_provider.dart';
import 'services/database_service.dart';
import 'services/auth_service.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'utils/theme.dart';
import 'utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize environment configuration for API keys
  // In production, pass values via environment variables or CI/CD secrets
  EnvConfig.initialize(
    geminiApiKey: const String.fromEnvironment('GEMINI_API_KEY'),
    revenueCatApiKey: const String.fromEnvironment('REVENUECAT_API_KEY'),
  );

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  ));

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Enable offline persistence — reads return instantly from cache
  // Note: 50MB cache size may need adjustment based on usage patterns
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: 50 * 1024 * 1024, // 50MB — bounded for production
  );

  // Initialize RevenueCat with public SDK key
  // The key is the same for iOS and Android (RevenueCat public key)
  await Purchases.configure(
    PurchasesConfiguration(EnvConfig.revenueCatApiKey),
  );

  // Auth in background — don't block UI
  AuthService.getOrCreateUserId();

  final db = DatabaseService();

  // Set up Crashlytics error handlers before runApp
  FlutterError.onError = (details) {
    FirebaseCrashlytics.instance.recordError(
      details.exceptionAsString(),
      details.stack,
      fatal: true,
    );
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(
      error.toString(),
      stack,
      fatal: true,
    );
    return true;
  };

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider(db)..load()),
        ChangeNotifierProvider(create: (_) => DiaryProvider(db)),
      ],
      child: const NutriScanApp(),
    ),
  );
}

class _AppEntry extends StatefulWidget {
  const _AppEntry();

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  bool _showSplash = true;

  void _retry() {
    context.read<UserProvider>().load();
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return SplashScreen(
        onComplete: () => setState(() => _showSplash = false),
      );
    }
    return Consumer<UserProvider>(
      builder: (_, userProvider, __) {
        if (userProvider.isLoading) {
          return const Scaffold(
            backgroundColor: Color(0xFF0A0E1A),
            body: Center(child: CircularProgressIndicator(color: Color(0xFF00E676))),
          );
        }
        if (userProvider.error != null && userProvider.user == null) {
          return Scaffold(
            backgroundColor: const Color(0xFF0A0E1A),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      color: Color(0xFFFF5252), size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'No internet connection. Please try again.',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _retry,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        if (userProvider.isOnboarded) return const HomeScreen();
        return const OnboardingScreen();
      },
    );
  }
}

class NutriScanApp extends StatelessWidget {
  const NutriScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI NutriScan',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: const _AppEntry(),
    );
  }
}
