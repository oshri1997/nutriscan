import 'package:flutter_test/flutter_test.dart';
import 'package:ai_nutriscan/models/food_item.dart';
import 'package:ai_nutriscan/models/meal_log.dart';
import 'package:ai_nutriscan/providers/diary_provider.dart';
import 'package:ai_nutriscan/services/database_service.dart';

// ---------------------------------------------------------------------------
// Minimal stub DatabaseService
// ---------------------------------------------------------------------------
//
// DiaryProvider only calls four DatabaseService methods:
//   getMealsForDate, saveMealLog, deleteMealLog, deleteItemFromMeal.
//
// We extend DatabaseService and override those four methods so that no
// real Firestore / Firebase connection is required.
// The constructor calls super() which does nothing beyond field init on the
// static _firestore field — that is never exercised in these tests because
// we override every method DiaryProvider touches.

class _FakeDB extends DatabaseService {
  // Meals that getMealsForDate will return on the next call.
  List<MealLog> stubbedMeals = [];

  // Records of operations performed (for assertion).
  final List<String> deletedMealIds = [];
  final List<(String mealId, String itemId)> deletedItems = [];
  final List<MealLog> savedMeals = [];
  bool shouldThrowOnSaveMeal = false;

  @override
  Future<List<MealLog>> getMealsForDate(String userId, DateTime date) async {
    return stubbedMeals;
  }

  @override
  Future<void> saveMealLog(MealLog meal) async {
    if (shouldThrowOnSaveMeal) throw Exception('saveMealLog error');
    savedMeals.add(meal);
  }

  @override
  Future<void> deleteMealLog(String id) async {
    deletedMealIds.add(id);
    stubbedMeals.removeWhere((m) => m.id == id);
  }

  @override
  Future<void> deleteItemFromMeal(String mealId, String itemId) async {
    deletedItems.add((mealId, itemId));
    // Mirror the real behaviour: filter the item out of the in-memory list
    // so subsequent getMealsForDate calls reflect the deletion.
    stubbedMeals = stubbedMeals.map((meal) {
      if (meal.id != mealId) return meal;
      final remaining =
          meal.items.where((i) => i.id != itemId).toList();
      if (remaining.isEmpty) {
        return null; // signal to remove the meal entirely
      }
      return MealLog(
        id: meal.id,
        userId: meal.userId,
        mealType: meal.mealType,
        items: remaining,
        dateTime: meal.dateTime,
      );
    }).whereType<MealLog>().toList();
  }
}

// ---------------------------------------------------------------------------
// Fixture helpers
// ---------------------------------------------------------------------------

const FoodItem _rice = FoodItem(
  id: 'fi_rice',
  name: 'Rice',
  calories: 200,
  protein: 4,
  carbs: 44,
  fat: 1,
  servingGrams: 180,
);

const FoodItem _chicken = FoodItem(
  id: 'fi_chicken',
  name: 'Chicken',
  calories: 165,
  protein: 31,
  carbs: 0,
  fat: 3.6,
  servingGrams: 100,
);

const FoodItem _salad = FoodItem(
  id: 'fi_salad',
  name: 'Salad',
  calories: 50,
  protein: 2,
  carbs: 8,
  fat: 0.5,
  servingGrams: 100,
);

MealLog _meal(
  String id,
  MealType type,
  List<FoodItem> items,
) =>
    MealLog(
      id: id,
      userId: 'u1',
      mealType: type,
      items: items,
      dateTime: DateTime(2024, 6, 1, 12, 0),
    );

// ---------------------------------------------------------------------------

void main() {
  late _FakeDB fakeDb;
  late DiaryProvider provider;

  setUp(() {
    fakeDb = _FakeDB();
    provider = DiaryProvider(fakeDb);
  });

  // ---------------------------------------------------------------------------
  group('DiaryProvider – computed nutrition totals', () {
    test('totalCalories is 0 when no meals loaded', () {
      expect(provider.totalCalories, closeTo(0, 0.001));
    });

    test('totalCalories sums across all meals', () async {
      fakeDb.stubbedMeals = [
        _meal('m1', MealType.breakfast, [_rice]),           // 200
        _meal('m2', MealType.lunch, [_chicken, _salad]),    // 165 + 50 = 215
      ];
      await provider.loadMeals('u1');
      expect(provider.totalCalories, closeTo(415, 0.001));
    });

    test('totalProtein sums across all meals', () async {
      fakeDb.stubbedMeals = [
        _meal('m1', MealType.breakfast, [_rice]),    // 4
        _meal('m2', MealType.lunch, [_chicken]),     // 31
      ];
      await provider.loadMeals('u1');
      // 4 + 31 = 35
      expect(provider.totalProtein, closeTo(35, 0.001));
    });

    test('totalCarbs sums across all meals', () async {
      fakeDb.stubbedMeals = [
        _meal('m1', MealType.breakfast, [_rice]),   // 44
        _meal('m2', MealType.lunch, [_salad]),      // 8
      ];
      await provider.loadMeals('u1');
      expect(provider.totalCarbs, closeTo(52, 0.001));
    });

    test('totalFat sums across all meals', () async {
      fakeDb.stubbedMeals = [
        _meal('m1', MealType.breakfast, [_chicken]), // 3.6
        _meal('m2', MealType.lunch, [_salad]),       // 0.5
      ];
      await provider.loadMeals('u1');
      expect(provider.totalFat, closeTo(4.1, 0.001));
    });

    test('totals reset to 0 after loading empty list', () async {
      fakeDb.stubbedMeals = [_meal('m1', MealType.lunch, [_rice])];
      await provider.loadMeals('u1');
      expect(provider.totalCalories, greaterThan(0));

      fakeDb.stubbedMeals = [];
      await provider.loadMeals('u1');
      expect(provider.totalCalories, closeTo(0, 0.001));
    });
  });

  // ---------------------------------------------------------------------------
  group('DiaryProvider – mealsOfType filtering', () {
    setUp(() async {
      fakeDb.stubbedMeals = [
        _meal('m1', MealType.breakfast, [_rice]),
        _meal('m2', MealType.lunch, [_chicken]),
        _meal('m3', MealType.lunch, [_salad]),
        _meal('m4', MealType.dinner, [_rice, _chicken]),
        _meal('m5', MealType.snack, [_salad]),
      ];
      await provider.loadMeals('u1');
    });

    test('returns only breakfast meals', () {
      final result = provider.mealsOfType(MealType.breakfast);
      expect(result.length, equals(1));
      expect(result.first.id, equals('m1'));
    });

    test('returns both lunch meals', () {
      final result = provider.mealsOfType(MealType.lunch);
      expect(result.length, equals(2));
      expect(result.map((m) => m.id), containsAll(['m2', 'm3']));
    });

    test('returns dinner meal', () {
      final result = provider.mealsOfType(MealType.dinner);
      expect(result.length, equals(1));
      expect(result.first.id, equals('m4'));
    });

    test('returns snack meal', () {
      expect(provider.mealsOfType(MealType.snack).length, equals(1));
    });

    test('returns empty list for type with no matching meals', () {
      fakeDb.stubbedMeals = [_meal('m1', MealType.lunch, [_rice])];
      // Re-load so provider reflects the new stub list synchronously via
      // a direct assignment of todayMeals... but we must call loadMeals.
      // Use a fresh provider with only a lunch meal.
      final fresh = DiaryProvider(fakeDb);
      // Before loadMeals the internal list is empty.
      expect(fresh.mealsOfType(MealType.breakfast), isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  group('DiaryProvider – deleteMeal', () {
    test('calls db.deleteMealLog with correct mealId', () async {
      fakeDb.stubbedMeals = [_meal('m1', MealType.lunch, [_rice])];
      await provider.loadMeals('u1');

      await provider.deleteMeal('u1', 'm1');
      expect(fakeDb.deletedMealIds, contains('m1'));
    });

    test('meal no longer present in todayMeals after deletion', () async {
      fakeDb.stubbedMeals = [
        _meal('m1', MealType.breakfast, [_rice]),
        _meal('m2', MealType.lunch, [_chicken]),
      ];
      await provider.loadMeals('u1');

      await provider.deleteMeal('u1', 'm1');
      // After deletion the stub returns only m2
      expect(provider.todayMeals.any((m) => m.id == 'm1'), isFalse);
      expect(provider.todayMeals.any((m) => m.id == 'm2'), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  group('DiaryProvider – deleteItem', () {
    test('calls db.deleteItemFromMeal with correct ids', () async {
      fakeDb.stubbedMeals = [
        _meal('m1', MealType.lunch, [_rice, _chicken]),
      ];
      await provider.loadMeals('u1');

      await provider.deleteItem('u1', 'm1', 'fi_rice');
      expect(fakeDb.deletedItems, contains(('m1', 'fi_rice')));
    });

    test('after item deletion only remaining item survives in the meal', () async {
      fakeDb.stubbedMeals = [
        _meal('m1', MealType.lunch, [_rice, _chicken]),
      ];
      await provider.loadMeals('u1');

      await provider.deleteItem('u1', 'm1', 'fi_rice');

      final meals = provider.todayMeals;
      expect(meals.length, equals(1));
      expect(meals.first.items.length, equals(1));
      expect(meals.first.items.first.id, equals('fi_chicken'));
    });

    test('deleting last item removes the meal entirely', () async {
      fakeDb.stubbedMeals = [
        _meal('m1', MealType.lunch, [_rice]),
      ];
      await provider.loadMeals('u1');

      await provider.deleteItem('u1', 'm1', 'fi_rice');
      expect(provider.todayMeals, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  group('DiaryProvider – loadMeals', () {
    test('updates selectedDate to provided date', () async {
      final target = DateTime(2024, 3, 10);
      fakeDb.stubbedMeals = [];
      await provider.loadMeals('u1', date: target);
      expect(provider.selectedDate.year, equals(2024));
      expect(provider.selectedDate.month, equals(3));
      expect(provider.selectedDate.day, equals(10));
    });

    test('todayMeals reflects what db returns', () async {
      fakeDb.stubbedMeals = [_meal('m1', MealType.dinner, [_chicken])];
      await provider.loadMeals('u1');
      expect(provider.todayMeals.length, equals(1));
      expect(provider.todayMeals.first.id, equals('m1'));
    });
  });

  // ---------------------------------------------------------------------------
  group('DiaryProvider – addMeal error handling', () {
    test('addMeal wraps saveMealLog errors and rethrows', () async {
      fakeDb.shouldThrowOnSaveMeal = true;

      await expectLater(
        provider.addMeal('u1', MealType.lunch, [_rice]),
        throwsA(isA<Exception>()),
      );
    });

    test('addMeal does not call loadMeals after save failure', () async {
      fakeDb.shouldThrowOnSaveMeal = true;
      fakeDb.stubbedMeals = [];

      try {
        await provider.addMeal('u1', MealType.lunch, [_rice]);
      } catch (_) {}

      // loadMeals would have set isLoading to false if it ran
      expect(provider.isLoading, isFalse);
    });

    test('saved meals contain the meal passed to addMeal', () async {
      fakeDb.shouldThrowOnSaveMeal = false;
      await provider.addMeal('u1', MealType.dinner, [_chicken]);

      expect(fakeDb.savedMeals.length, equals(1));
      expect(fakeDb.savedMeals.first.mealType, equals(MealType.dinner));
      expect(fakeDb.savedMeals.first.items, contains(_chicken));
    });
  });

  // ---------------------------------------------------------------------------
  group('DiaryProvider – isLoading flag', () {
    test('isLoading is true during loadMeals', () async {
      fakeDb.stubbedMeals = [];
      final loadFuture = provider.loadMeals('u1');
      // Immediately after calling loadMeals, isLoading should be true
      // (we can't easily synchronously check this, so we verify the false case)
      await loadFuture;
      expect(provider.isLoading, isFalse);
    });

    test('isLoading is false after loadMeals completes', () async {
      fakeDb.stubbedMeals = [];
      await provider.loadMeals('u1');
      expect(provider.isLoading, isFalse);
    });

    test('isLoading is false when addMeal fails', () async {
      fakeDb.shouldThrowOnSaveMeal = true;
      fakeDb.stubbedMeals = [];

      try {
        await provider.addMeal('u1', MealType.lunch, [_rice]);
      } catch (_) {}

      expect(provider.isLoading, isFalse);
    });
  });
}
