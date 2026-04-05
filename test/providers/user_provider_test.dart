import 'package:flutter_test/flutter_test.dart';
import 'package:ai_nutriscan/models/user_profile.dart';
import 'package:ai_nutriscan/providers/user_provider.dart';
import 'package:ai_nutriscan/services/database_service.dart';

// ---------------------------------------------------------------------------
// Stub DatabaseService for UserProvider tests
// ---------------------------------------------------------------------------

class _FakeDB extends DatabaseService {
  UserProfile? stubbedUser;
  bool shouldThrowOnLoad = false;
  bool shouldThrowOnSave = false;
  final List<UserProfile> savedProfiles = [];

  @override
  Future<UserProfile?> getUser() async {
    if (shouldThrowOnLoad) throw Exception('db error');
    return stubbedUser;
  }

  @override
  Future<void> saveUser(UserProfile user) async {
    if (shouldThrowOnSave) throw Exception('db save error');
    savedProfiles.add(user);
    stubbedUser = user;
  }
}

// ---------------------------------------------------------------------------
// Fixture helper
// ---------------------------------------------------------------------------

UserProfile _profile({
  bool isPro = false,
  int dailyScanCount = 0,
  DateTime? lastScanDate,
}) =>
    UserProfile(
      id: 'u1',
      name: 'Avi',
      age: 30,
      gender: Gender.male,
      heightCm: 180,
      weightKg: 80,
      targetWeightKg: 75,
      activityLevel: ActivityLevel.sedentary,
      goal: Goal.maintain,
      isPro: isPro,
      dailyScanCount: dailyScanCount,
      lastScanDate: lastScanDate,
      createdAt: DateTime(2024, 1, 1),
    );

// ---------------------------------------------------------------------------

void main() {
  late _FakeDB fakeDb;
  late UserProvider provider;

  setUp(() {
    fakeDb = _FakeDB();
    provider = UserProvider(fakeDb);
  });

  // ---------------------------------------------------------------------------
  group('UserProvider – initial state', () {
    test('isLoading is true before load() is called', () {
      expect(provider.isLoading, isTrue);
    });

    test('isOnboarded is false before load() is called', () {
      expect(provider.isOnboarded, isFalse);
    });

    test('user is null before load() is called', () {
      expect(provider.user, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  group('UserProvider – load()', () {
    test('isLoading becomes false after successful load', () async {
      fakeDb.stubbedUser = _profile();
      await provider.load();
      expect(provider.isLoading, isFalse);
    });

    test('isOnboarded is true when db returns a profile', () async {
      fakeDb.stubbedUser = _profile();
      await provider.load();
      expect(provider.isOnboarded, isTrue);
    });

    test('user is populated after successful load', () async {
      final p = _profile();
      fakeDb.stubbedUser = p;
      await provider.load();
      expect(provider.user, isNotNull);
      expect(provider.user!.id, equals('u1'));
    });

    test('isOnboarded is false when db returns null', () async {
      fakeDb.stubbedUser = null;
      await provider.load();
      expect(provider.isOnboarded, isFalse);
      expect(provider.user, isNull);
    });

    test('isLoading becomes false even when db throws', () async {
      fakeDb.shouldThrowOnLoad = true;
      await provider.load();
      expect(provider.isLoading, isFalse);
    });

    test('user is null when db throws', () async {
      fakeDb.shouldThrowOnLoad = true;
      await provider.load();
      expect(provider.user, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  group('UserProvider – saveProfile()', () {
    test('updates in-memory user', () async {
      final p = _profile();
      await provider.saveProfile(p);
      expect(provider.user, isNotNull);
      expect(provider.user!.name, equals('Avi'));
    });

    test('persists profile to db', () async {
      final p = _profile();
      await provider.saveProfile(p);
      expect(fakeDb.savedProfiles, contains(p));
    });

    test('isOnboarded becomes true after first saveProfile', () async {
      await provider.saveProfile(_profile());
      expect(provider.isOnboarded, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  group('UserProvider – incrementScanCount()', () {
    test('increments dailyScanCount by 1', () async {
      fakeDb.stubbedUser = _profile(dailyScanCount: 0, lastScanDate: DateTime.now());
      await provider.load();

      await provider.incrementScanCount();
      expect(provider.user!.dailyScanCount, equals(1));
    });

    test('increments dailyScanCount multiple times cumulatively', () async {
      fakeDb.stubbedUser = _profile(dailyScanCount: 1, lastScanDate: DateTime.now());
      await provider.load();

      await provider.incrementScanCount();
      await provider.incrementScanCount();
      expect(provider.user!.dailyScanCount, equals(3));
    });

    test('persists updated scan count to db', () async {
      fakeDb.stubbedUser = _profile(dailyScanCount: 2, lastScanDate: DateTime.now());
      await provider.load();

      await provider.incrementScanCount();
      final lastSaved = fakeDb.savedProfiles.last;
      expect(lastSaved.dailyScanCount, equals(3));
    });

    test('does nothing when user is null', () async {
      // No load() called, user remains null
      await provider.incrementScanCount();
      expect(provider.user, isNull);
      expect(fakeDb.savedProfiles, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  group('UserProvider – resetDailyScanCount()', () {
    test('resets dailyScanCount to 0', () async {
      fakeDb.stubbedUser = _profile(dailyScanCount: 3);
      await provider.load();

      await provider.resetDailyScanCount();
      expect(provider.user!.dailyScanCount, equals(0));
    });

    test('persists reset scan count to db', () async {
      fakeDb.stubbedUser = _profile(dailyScanCount: 3);
      await provider.load();

      await provider.resetDailyScanCount();
      expect(fakeDb.savedProfiles.last.dailyScanCount, equals(0));
    });

    test('does nothing when user is null', () async {
      await provider.resetDailyScanCount();
      expect(fakeDb.savedProfiles, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  group('UserProvider – setPro()', () {
    test('sets isPro to true', () async {
      fakeDb.stubbedUser = _profile(isPro: false);
      await provider.load();

      await provider.setPro(true);
      expect(provider.user!.isPro, isTrue);
    });

    test('sets isPro to false', () async {
      fakeDb.stubbedUser = _profile(isPro: true);
      await provider.load();

      await provider.setPro(false);
      expect(provider.user!.isPro, isFalse);
    });

    test('canScan reflects isPro change', () async {
      // User has exceeded free scan limit but is now granted Pro.
      fakeDb.stubbedUser = _profile(isPro: false, dailyScanCount: 10);
      await provider.load();
      expect(provider.user!.canScan, isFalse);

      await provider.setPro(true);
      expect(provider.user!.canScan, isTrue);
    });

    test('does nothing when user is null', () async {
      await provider.setPro(true);
      expect(fakeDb.savedProfiles, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  group('UserProvider – error state', () {
    test('error is set when Firestore getUser fails', () async {
      fakeDb.shouldThrowOnLoad = true;
      await provider.load();
      expect(provider.error, isNotNull);
    });

    test('error is null when user simply does not exist (null returned)', () async {
      fakeDb.stubbedUser = null;
      await provider.load();
      expect(provider.error, isNull);
    });

    test('error state is cleared on successful load', () async {
      fakeDb.shouldThrowOnLoad = true;
      await provider.load();
      expect(provider.error, isNotNull);

      fakeDb.shouldThrowOnLoad = false;
      fakeDb.stubbedUser = _profile();
      await provider.load();
      expect(provider.error, isNull);
    });

    test('error is set when Firestore saveUser fails in incrementScanCount',
        () async {
      fakeDb.stubbedUser = _profile(dailyScanCount: 0, lastScanDate: DateTime.now());
      await provider.load();
      fakeDb.shouldThrowOnSave = true;

      // incrementScanCount does not catch saveUser errors, so it propagates:
      await expectLater(
        provider.incrementScanCount(),
        throwsA(isA<Exception>()),
      );
    });
  });
}
