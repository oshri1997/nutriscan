import 'package:flutter_test/flutter_test.dart';
import 'package:ai_nutriscan/models/user_profile.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Shared fixtures
  // ---------------------------------------------------------------------------

  /// A known male profile used across BMR / TDEE / macro tests.
  /// Age 30, 80 kg, 180 cm, sedentary, goal = maintain.
  /// BMR = 10*80 + 6.25*180 - 5*30 + 5 = 800 + 1125 - 150 + 5 = 1780
  UserProfile _maleProfile({
    Goal goal = Goal.maintain,
    ActivityLevel activityLevel = ActivityLevel.sedentary,
    bool isPro = false,
    int dailyScanCount = 0,
  }) =>
      UserProfile(
        id: 'u1',
        name: 'Avi',
        age: 30,
        gender: Gender.male,
        heightCm: 180,
        weightKg: 80,
        targetWeightKg: 75,
        activityLevel: activityLevel,
        goal: goal,
        isPro: isPro,
        dailyScanCount: dailyScanCount,
        createdAt: DateTime(2024, 1, 1),
      );

  /// A known female profile.
  /// Age 25, 60 kg, 165 cm, sedentary, goal = maintain.
  /// BMR = 10*60 + 6.25*165 - 5*25 - 161 = 600 + 1031.25 - 125 - 161 = 1345.25
  UserProfile _femaleProfile({
    Goal goal = Goal.maintain,
    ActivityLevel activityLevel = ActivityLevel.sedentary,
  }) =>
      UserProfile(
        id: 'u2',
        name: 'Dana',
        age: 25,
        gender: Gender.female,
        heightCm: 165,
        weightKg: 60,
        targetWeightKg: 58,
        activityLevel: activityLevel,
        goal: goal,
        createdAt: DateTime(2024, 1, 1),
      );

  // ---------------------------------------------------------------------------
  group('UserProfile – BMR (Mifflin-St Jeor)', () {
    test('male BMR formula: 10w + 6.25h - 5a + 5', () {
      final p = _maleProfile();
      // 10*80 + 6.25*180 - 5*30 + 5 = 1780
      expect(p.bmr, closeTo(1780, 0.01));
    });

    test('female BMR formula: 10w + 6.25h - 5a - 161', () {
      final p = _femaleProfile();
      // 10*60 + 6.25*165 - 5*25 - 161 = 1345.25
      expect(p.bmr, closeTo(1345.25, 0.01));
    });

    test('male BMR is always 166 kcal higher than equivalent female', () {
      // The only difference in the formula is +5 vs -161, a delta of 166.
      final male = UserProfile(
        id: 'm',
        name: 'M',
        age: 40,
        gender: Gender.male,
        heightCm: 170,
        weightKg: 70,
        targetWeightKg: 70,
        activityLevel: ActivityLevel.sedentary,
        goal: Goal.maintain,
        createdAt: DateTime(2024, 1, 1),
      );
      final female = male.copyWith(gender: Gender.female);
      expect(male.bmr - female.bmr, closeTo(166, 0.01));
    });
  });

  // ---------------------------------------------------------------------------
  group('UserProfile – TDEE activity multipliers', () {
    const tolerance = 0.01;

    test('sedentary multiplier = 1.2', () {
      final p = _maleProfile(activityLevel: ActivityLevel.sedentary);
      expect(p.tdee, closeTo(p.bmr * 1.2, tolerance));
    });

    test('light multiplier = 1.375', () {
      final p = _maleProfile(activityLevel: ActivityLevel.light);
      expect(p.tdee, closeTo(p.bmr * 1.375, tolerance));
    });

    test('moderate multiplier = 1.55', () {
      final p = _maleProfile(activityLevel: ActivityLevel.moderate);
      expect(p.tdee, closeTo(p.bmr * 1.55, tolerance));
    });

    test('active multiplier = 1.725', () {
      final p = _maleProfile(activityLevel: ActivityLevel.active);
      expect(p.tdee, closeTo(p.bmr * 1.725, tolerance));
    });

    test('veryActive multiplier = 1.9', () {
      final p = _maleProfile(activityLevel: ActivityLevel.veryActive);
      expect(p.tdee, closeTo(p.bmr * 1.9, tolerance));
    });
  });

  // ---------------------------------------------------------------------------
  group('UserProfile – dailyCalorieTarget by goal', () {
    test('lose goal subtracts 500 kcal from TDEE', () {
      final p = _maleProfile(goal: Goal.lose);
      expect(p.dailyCalorieTarget, closeTo(p.tdee - 500, 0.01));
    });

    test('maintain goal equals TDEE exactly', () {
      final p = _maleProfile(goal: Goal.maintain);
      expect(p.dailyCalorieTarget, closeTo(p.tdee, 0.01));
    });

    test('gain goal adds 300 kcal to TDEE', () {
      final p = _maleProfile(goal: Goal.gain);
      expect(p.dailyCalorieTarget, closeTo(p.tdee + 300, 0.01));
    });
  });

  // ---------------------------------------------------------------------------
  group('UserProfile – macro targets', () {
    test('proteinTarget = weightKg * 2.0', () {
      final p = _maleProfile(); // weightKg = 80
      expect(p.proteinTarget, closeTo(160.0, 0.01));
    });

    test('fatTarget = (dailyCalorieTarget * 0.25) / 9', () {
      final p = _maleProfile();
      final expected = (p.dailyCalorieTarget * 0.25) / 9;
      expect(p.fatTarget, closeTo(expected, 0.01));
    });

    test('carbTarget energy fills remaining calories after protein and fat', () {
      final p = _maleProfile();
      // carbTarget * 4 + proteinTarget * 4 + fatTarget * 9 ≈ dailyCalorieTarget
      final total =
          p.carbTarget * 4 + p.proteinTarget * 4 + p.fatTarget * 9;
      expect(total, closeTo(p.dailyCalorieTarget, 0.5));
    });

    test('female macro targets recalculated from her dailyCalorieTarget', () {
      final p = _femaleProfile(goal: Goal.lose);
      final expectedFat = (p.dailyCalorieTarget * 0.25) / 9;
      expect(p.fatTarget, closeTo(expectedFat, 0.01));
    });
  });

  // ---------------------------------------------------------------------------
  group('UserProfile – canScan logic', () {
    test('free user with 0 scans can scan', () {
      expect(_maleProfile(dailyScanCount: 0).canScan, isTrue);
    });

    test('free user with 2 scans (below limit) can scan', () {
      expect(_maleProfile(dailyScanCount: 2).canScan, isTrue);
    });

    test('free user at exactly maxFreeDailyScans (3) cannot scan', () {
      expect(_maleProfile(dailyScanCount: 3).canScan, isFalse);
    });

    test('free user above maxFreeDailyScans cannot scan', () {
      expect(_maleProfile(dailyScanCount: 10).canScan, isFalse);
    });

    test('pro user can always scan regardless of dailyScanCount', () {
      expect(
        _maleProfile(isPro: true, dailyScanCount: 100).canScan,
        isTrue,
      );
    });

    test('maxFreeDailyScans is 3', () {
      expect(_maleProfile().maxFreeDailyScans, equals(3));
    });
  });

  // ---------------------------------------------------------------------------
  group('UserProfile – toMap / fromMap roundtrip', () {
    test('roundtrip preserves all scalar fields', () {
      final original = _maleProfile(
        goal: Goal.lose,
        activityLevel: ActivityLevel.moderate,
        isPro: true,
        dailyScanCount: 2,
      );
      final restored = UserProfile.fromMap(original.toMap());

      expect(restored.id, equals(original.id));
      expect(restored.name, equals(original.name));
      expect(restored.age, equals(original.age));
      expect(restored.gender, equals(original.gender));
      expect(restored.heightCm, closeTo(original.heightCm, 0.001));
      expect(restored.weightKg, closeTo(original.weightKg, 0.001));
      expect(restored.targetWeightKg, closeTo(original.targetWeightKg, 0.001));
      expect(restored.activityLevel, equals(original.activityLevel));
      expect(restored.goal, equals(original.goal));
      expect(restored.isPro, equals(original.isPro));
      expect(restored.dailyScanCount, equals(original.dailyScanCount));
    });

    test('roundtrip preserves createdAt timestamp', () {
      final ts = DateTime(2024, 6, 15, 8, 30);
      final original = UserProfile(
        id: 'u3',
        name: 'Test',
        age: 28,
        gender: Gender.female,
        heightCm: 160,
        weightKg: 55,
        targetWeightKg: 53,
        activityLevel: ActivityLevel.light,
        goal: Goal.maintain,
        createdAt: ts,
      );
      final restored = UserProfile.fromMap(original.toMap());
      expect(restored.createdAt, equals(ts));
    });

    test('toMap encodes gender as enum index', () {
      final map = _maleProfile().toMap();
      expect(map['gender'], equals(Gender.male.index)); // 0
    });

    test('toMap encodes activityLevel as enum index', () {
      final map = _maleProfile(activityLevel: ActivityLevel.active).toMap();
      expect(map['activityLevel'], equals(ActivityLevel.active.index));
    });

    test('toMap encodes goal as enum index', () {
      final map = _maleProfile(goal: Goal.gain).toMap();
      expect(map['goal'], equals(Goal.gain.index));
    });

    test('fromMap handles isPro stored as int 1 (legacy)', () {
      final map = _maleProfile(isPro: true).toMap();
      map['isPro'] = 1; // simulate legacy int storage
      final restored = UserProfile.fromMap(map);
      expect(restored.isPro, isTrue);
    });

    test('fromMap defaults dailyScanCount to 0 when key missing', () {
      final map = _maleProfile().toMap()..remove('dailyScanCount');
      final restored = UserProfile.fromMap(map);
      expect(restored.dailyScanCount, equals(0));
    });
  });

  // ---------------------------------------------------------------------------
  group('UserProfile – copyWith', () {
    test('copyWith returns new instance with overridden fields', () {
      final original = _maleProfile();
      final updated = original.copyWith(name: 'Benny', age: 35);
      expect(updated.name, equals('Benny'));
      expect(updated.age, equals(35));
      expect(updated.id, equals(original.id)); // id is not copyWith-able
    });

    test('copyWith preserves unchanged fields', () {
      final original = _maleProfile(isPro: true, dailyScanCount: 1);
      final updated = original.copyWith(name: 'New Name');
      expect(updated.isPro, isTrue);
      expect(updated.dailyScanCount, equals(1));
      expect(updated.createdAt, equals(original.createdAt));
    });
  });
}
