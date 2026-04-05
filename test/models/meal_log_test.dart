import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_nutriscan/models/food_item.dart';
import 'package:ai_nutriscan/models/meal_log.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Shared fixtures
  // ---------------------------------------------------------------------------

  const FoodItem rice = FoodItem(
    id: 'fi_rice',
    name: 'Rice',
    calories: 200.0,
    protein: 4.0,
    carbs: 44.0,
    fat: 1.0,
    servingGrams: 180.0,
  );

  const FoodItem chicken = FoodItem(
    id: 'fi_chicken',
    name: 'Chicken',
    calories: 165.0,
    protein: 31.0,
    carbs: 0.0,
    fat: 3.6,
    servingGrams: 100.0,
  );

  const FoodItem salad = FoodItem(
    id: 'fi_salad',
    name: 'Salad',
    calories: 50.0,
    protein: 2.0,
    carbs: 8.0,
    fat: 0.5,
    servingGrams: 100.0,
  );

  MealLog _makeMeal({
    List<FoodItem> items = const [],
    MealType type = MealType.lunch,
  }) =>
      MealLog(
        id: 'm1',
        userId: 'u1',
        mealType: type,
        items: items,
        dateTime: DateTime(2024, 6, 1, 12, 0),
      );

  // ---------------------------------------------------------------------------
  group('MealLog – nutrition aggregation', () {
    test('empty items list yields all zeros', () {
      final meal = _makeMeal();
      expect(meal.totalCalories, closeTo(0, 0.001));
      expect(meal.totalProtein, closeTo(0, 0.001));
      expect(meal.totalCarbs, closeTo(0, 0.001));
      expect(meal.totalFat, closeTo(0, 0.001));
    });

    test('single item totals equal that item values', () {
      final meal = _makeMeal(items: [chicken]);
      expect(meal.totalCalories, closeTo(165.0, 0.001));
      expect(meal.totalProtein, closeTo(31.0, 0.001));
      expect(meal.totalCarbs, closeTo(0.0, 0.001));
      expect(meal.totalFat, closeTo(3.6, 0.001));
    });

    test('multiple items are summed correctly', () {
      final meal = _makeMeal(items: [rice, chicken, salad]);
      // calories: 200 + 165 + 50 = 415
      expect(meal.totalCalories, closeTo(415.0, 0.001));
      // protein: 4 + 31 + 2 = 37
      expect(meal.totalProtein, closeTo(37.0, 0.001));
      // carbs: 44 + 0 + 8 = 52
      expect(meal.totalCarbs, closeTo(52.0, 0.001));
      // fat: 1 + 3.6 + 0.5 = 5.1
      expect(meal.totalFat, closeTo(5.1, 0.001));
    });

    test('two identical items double the totals', () {
      final meal = _makeMeal(items: [rice, rice]);
      expect(meal.totalCalories, closeTo(400.0, 0.001));
      expect(meal.totalProtein, closeTo(8.0, 0.001));
    });
  });

  // ---------------------------------------------------------------------------
  group('MealLog – mealLabel (English strings)', () {
    test('breakfast label', () {
      expect(
        _makeMeal(type: MealType.breakfast).mealLabel,
        equals('Breakfast'),
      );
    });

    test('lunch label', () {
      expect(
        _makeMeal(type: MealType.lunch).mealLabel,
        equals('Lunch'),
      );
    });

    test('dinner label', () {
      expect(
        _makeMeal(type: MealType.dinner).mealLabel,
        equals('Dinner'),
      );
    });

    test('snack label', () {
      expect(
        _makeMeal(type: MealType.snack).mealLabel,
        equals('Snack'),
      );
    });
  });

  // ---------------------------------------------------------------------------
  group('MealLog – toMap / fromMap roundtrip', () {
    test('toMap contains expected keys (items excluded from document map)', () {
      final map = _makeMeal(items: [chicken]).toMap();
      expect(map.containsKey('id'), isTrue);
      expect(map.containsKey('userId'), isTrue);
      expect(map.containsKey('mealType'), isTrue);
      expect(map.containsKey('dateTime'), isTrue);
      // items are NOT stored inside toMap — they are attached separately
      // by DatabaseService.saveMealLog
      expect(map.containsKey('items'), isFalse);
    });

    test('toMap encodes mealType as enum index', () {
      final map = _makeMeal(type: MealType.dinner).toMap();
      expect(map['mealType'], equals(MealType.dinner.index));
    });

    test('fromMap roundtrip preserves scalar fields', () {
      final original = _makeMeal(items: [chicken]);
      final restored = MealLog.fromMap(original.toMap(), [chicken]);

      expect(restored.id, equals(original.id));
      expect(restored.userId, equals(original.userId));
      expect(restored.mealType, equals(original.mealType));
      expect(restored.dateTime, equals(original.dateTime));
    });

    test('fromMap passes through the items list supplied by caller', () {
      final original = _makeMeal(items: [rice, chicken]);
      // fromMap receives the items list as a separate argument
      final restored = MealLog.fromMap(original.toMap(), [rice, chicken]);
      expect(restored.items.length, equals(2));
      expect(restored.items[0].id, equals('fi_rice'));
      expect(restored.items[1].id, equals('fi_chicken'));
    });

    test('fromMap with empty items list yields zero totals', () {
      final original = _makeMeal(items: [rice]);
      final restored = MealLog.fromMap(original.toMap(), []);
      expect(restored.totalCalories, closeTo(0, 0.001));
    });

    test('dateTime survives ISO-8601 roundtrip', () {
      final dt = DateTime(2024, 3, 15, 20, 45, 30);
      final meal = MealLog(
        id: 'm2',
        userId: 'u2',
        mealType: MealType.snack,
        items: const [],
        dateTime: dt,
      );
      final restored = MealLog.fromMap(meal.toMap(), const []);
      expect(restored.dateTime, equals(dt));
    });

    // -------------------------------------------------------------------------
    group('MealLog – Timestamp serialization', () {
      test('toMap encodes dateTime as Firestore Timestamp', () {
        final meal = MealLog(
          id: 'm_ts',
          userId: 'u_ts',
          mealType: MealType.lunch,
          items: const [],
          dateTime: DateTime(2024, 7, 4, 14, 30, 0),
        );
        final map = meal.toMap();
        // toMap uses Timestamp.fromDate for Firestore storage
        expect(map['dateTime'], isA<Timestamp>());
      });

      test('fromMap decodes Firestore Timestamp back to DateTime', () {
        final ts = Timestamp.fromDate(DateTime(2024, 7, 4, 14, 30, 0));
        final map = {
          'id': 'm_ts',
          'userId': 'u_ts',
          'mealType': MealType.breakfast.index,
          'dateTime': ts,
        };
        final restored = MealLog.fromMap(map, const []);

        expect(restored.dateTime.year, equals(2024));
        expect(restored.dateTime.month, equals(7));
        expect(restored.dateTime.day, equals(4));
        expect(restored.dateTime.hour, equals(14));
        expect(restored.dateTime.minute, equals(30));
      });

      test('Timestamp at midnight roundtrips correctly', () {
        final ts = Timestamp.fromDate(DateTime(2024, 1, 1, 0, 0, 0));
        final map = {
          'id': 'm_midnight',
          'userId': 'u1',
          'mealType': MealType.dinner.index,
          'dateTime': ts,
        };
        final restored = MealLog.fromMap(map, const []);
        expect(restored.dateTime, equals(DateTime(2024, 1, 1, 0, 0, 0)));
      });

      test('roundtrip preserves all fields including dateTime', () {
        final original = MealLog(
          id: 'm_round',
          userId: 'u_round',
          mealType: MealType.lunch,
          items: const [rice, chicken],
          dateTime: DateTime(2024, 9, 20, 13, 0),
        );
        final restored = MealLog.fromMap(original.toMap(), original.items);

        expect(restored.id, equals(original.id));
        expect(restored.userId, equals(original.userId));
        expect(restored.mealType, equals(original.mealType));
        expect(restored.items.length, equals(2));
        expect(restored.dateTime, equals(original.dateTime));
      });
    });
  });
}
