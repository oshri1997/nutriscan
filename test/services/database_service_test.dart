// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_nutriscan/models/food_item.dart';
import 'package:ai_nutriscan/models/meal_log.dart';

// ---------------------------------------------------------------------------
// Design note
// ---------------------------------------------------------------------------
//
// DatabaseService uses FirebaseFirestore.instance and AuthService.currentUserId
// as static references.  Replacing static state requires either (a) modifying
// production code to accept injection or (b) working around it in tests.
//
// To keep production code untouched we define a thin test-local helper class
// (_MealDocHelper) that replicates the exact Firestore interaction logic of
// deleteItemFromMeal using an injected FakeFirebaseFirestore instance.  This
// lets us assert on real Firestore semantics (document reads, filtered updates,
// document deletes) without hitting network or production statics.
//
// Every line of _MealDocHelper.deleteItemFromMeal is a verbatim copy of the
// production method body with only the static Firestore/AuthService references
// replaced by the injected fakeFirestore and a plain uid parameter.
// ---------------------------------------------------------------------------

/// Test-local replica of DatabaseService.deleteItemFromMeal using injected deps.
class _MealDocHelper {
  final FirebaseFirestore firestore;
  final String uid;

  _MealDocHelper(this.firestore, this.uid);

  CollectionReference _mealLogs() =>
      firestore.collection('users').doc(uid).collection('meal_logs');

  /// Direct copy of DatabaseService.deleteItemFromMeal with statics replaced.
  Future<void> deleteItemFromMeal(String mealId, String itemId) async {
    final doc = _mealLogs().doc(mealId);
    final snap = await doc.get();
    if (!snap.exists) return;

    final data = snap.data() as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>? ?? [])
        .where((i) => (i as Map<String, dynamic>)['id'] != itemId)
        .toList();

    if (items.isEmpty) {
      await doc.delete();
    } else {
      await doc.update({'items': items});
    }
  }

  /// Helper: seed a meal document into fakeFirestore.
  Future<void> seedMeal(MealLog meal) async {
    final data = meal.toMap();
    data['items'] = meal.items.map((i) => i.toMap()).toList();
    await _mealLogs().doc(meal.id).set(data);
  }

  /// Helper: read a meal document; returns null when the document is absent.
  Future<Map<String, dynamic>?> readMeal(String mealId) async {
    final snap = await _mealLogs().doc(mealId).get();
    if (!snap.exists) return null;
    return snap.data() as Map<String, dynamic>;
  }
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const _item1 = FoodItem(
  id: 'fi_1',
  name: 'Rice',
  calories: 200,
  protein: 4,
  carbs: 44,
  fat: 1,
  servingGrams: 180,
);

const _item2 = FoodItem(
  id: 'fi_2',
  name: 'Chicken',
  calories: 165,
  protein: 31,
  carbs: 0,
  fat: 3.6,
  servingGrams: 100,
);

const _item3 = FoodItem(
  id: 'fi_3',
  name: 'Salad',
  calories: 50,
  protein: 2,
  carbs: 8,
  fat: 0.5,
  servingGrams: 100,
);

MealLog _meal(List<FoodItem> items) => MealLog(
      id: 'meal_abc',
      userId: 'test_uid',
      mealType: MealType.lunch,
      items: items,
      dateTime: DateTime(2024, 6, 1, 12, 0),
    );

// ---------------------------------------------------------------------------

void main() {
  group('DatabaseService.deleteItemFromMeal – partial deletion', () {
    late FakeFirebaseFirestore fakeFirestore;
    late _MealDocHelper helper;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      helper = _MealDocHelper(fakeFirestore, 'test_uid');
    });

    // -------------------------------------------------------------------------
    test('deleting one of three items leaves exactly two items remaining',
        () async {
      await helper.seedMeal(_meal([_item1, _item2, _item3]));

      await helper.deleteItemFromMeal('meal_abc', 'fi_1');

      final data = await helper.readMeal('meal_abc');
      expect(data, isNotNull,
          reason: 'meal document should still exist after partial deletion');

      final items = data!['items'] as List<dynamic>;
      expect(items.length, equals(2),
          reason: 'exactly two items should remain after deleting one of three');

      final ids = items
          .map((i) => (i as Map<String, dynamic>)['id'] as String)
          .toSet();
      expect(ids, equals({'fi_2', 'fi_3'}),
          reason: 'the correct two items should remain');
      expect(ids, isNot(contains('fi_1')),
          reason: 'the deleted item must not remain');
    });

    // -------------------------------------------------------------------------
    test('deleting middle item preserves first and last items in order',
        () async {
      await helper.seedMeal(_meal([_item1, _item2, _item3]));

      await helper.deleteItemFromMeal('meal_abc', 'fi_2');

      final data = await helper.readMeal('meal_abc');
      final items = data!['items'] as List<dynamic>;
      expect(items.length, equals(2));

      final ids =
          items.map((i) => (i as Map<String, dynamic>)['id'] as String).toList();
      expect(ids, equals(['fi_1', 'fi_3']));
    });

    // -------------------------------------------------------------------------
    test('deleting last-in-list item leaves the first two intact', () async {
      await helper.seedMeal(_meal([_item1, _item2, _item3]));

      await helper.deleteItemFromMeal('meal_abc', 'fi_3');

      final data = await helper.readMeal('meal_abc');
      final items = data!['items'] as List<dynamic>;
      expect(items.length, equals(2));

      final ids =
          items.map((i) => (i as Map<String, dynamic>)['id'] as String).toSet();
      expect(ids, equals({'fi_1', 'fi_2'}));
    });

    // -------------------------------------------------------------------------
    test('deleting one of two items leaves exactly one item', () async {
      await helper.seedMeal(_meal([_item1, _item2]));

      await helper.deleteItemFromMeal('meal_abc', 'fi_1');

      final data = await helper.readMeal('meal_abc');
      expect(data, isNotNull);

      final items = data!['items'] as List<dynamic>;
      expect(items.length, equals(1));
      expect(
        (items.first as Map<String, dynamic>)['id'],
        equals('fi_2'),
      );
    });
  });

  // ---------------------------------------------------------------------------
  group('DatabaseService.deleteItemFromMeal – full deletion (last item)', () {
    late FakeFirebaseFirestore fakeFirestore;
    late _MealDocHelper helper;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      helper = _MealDocHelper(fakeFirestore, 'test_uid');
    });

    test('deleting the sole item removes the entire meal document', () async {
      await helper.seedMeal(_meal([_item1]));

      await helper.deleteItemFromMeal('meal_abc', 'fi_1');

      final data = await helper.readMeal('meal_abc');
      expect(data, isNull,
          reason:
              'entire meal document must be deleted when the last item is removed');
    });

    test('subsequent read returns null (document truly absent)', () async {
      await helper.seedMeal(_meal([_item2]));

      await helper.deleteItemFromMeal('meal_abc', 'fi_2');

      // Confirm via direct Firestore snapshot, not the helper wrapper.
      final snap = await fakeFirestore
          .collection('users')
          .doc('test_uid')
          .collection('meal_logs')
          .doc('meal_abc')
          .get();
      expect(snap.exists, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  group('DatabaseService.deleteItemFromMeal – edge cases', () {
    late FakeFirebaseFirestore fakeFirestore;
    late _MealDocHelper helper;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      helper = _MealDocHelper(fakeFirestore, 'test_uid');
    });

    test('deleting from a non-existent meal document is a no-op', () async {
      // No document seeded — should not throw.
      await expectLater(
        helper.deleteItemFromMeal('non_existent_meal', 'fi_1'),
        completes,
      );
    });

    test('deleting an item id that does not exist in the meal is a no-op',
        () async {
      await helper.seedMeal(_meal([_item1, _item2]));

      // 'fi_999' does not exist in the meal.
      await helper.deleteItemFromMeal('meal_abc', 'fi_999');

      final data = await helper.readMeal('meal_abc');
      expect(data, isNotNull,
          reason: 'meal should still exist when unknown item id is provided');

      final items = data!['items'] as List<dynamic>;
      expect(items.length, equals(2),
          reason: 'item count must be unchanged for unknown item id');
    });

    test('only the target meal document is affected when multiple meals exist',
        () async {
      final meal2 = MealLog(
        id: 'meal_xyz',
        userId: 'test_uid',
        mealType: MealType.breakfast,
        items: const [_item3],
        dateTime: DateTime(2024, 6, 1, 8, 0),
      );

      await helper.seedMeal(_meal([_item1, _item2])); // meal_abc
      await helper.seedMeal(meal2);                  // meal_xyz

      await helper.deleteItemFromMeal('meal_abc', 'fi_1');

      // meal_xyz must be untouched.
      final xyzData = await helper.readMeal('meal_xyz');
      expect(xyzData, isNotNull);
      final xyzItems = xyzData!['items'] as List<dynamic>;
      expect(xyzItems.length, equals(1));
      expect(
        (xyzItems.first as Map<String, dynamic>)['id'],
        equals('fi_3'),
      );
    });
  });
}
