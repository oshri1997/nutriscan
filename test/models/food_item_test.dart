import 'package:flutter_test/flutter_test.dart';
import 'package:ai_nutriscan/models/food_item.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Shared fixture
  // ---------------------------------------------------------------------------

  FoodItem _chicken() => const FoodItem(
        id: 'fi1',
        name: 'Chicken Breast',
        calories: 165.0,
        protein: 31.0,
        carbs: 0.0,
        fat: 3.6,
        servingGrams: 100.0,
        barcode: '1234567890',
      );

  FoodItem _noBarcode() => const FoodItem(
        id: 'fi2',
        name: 'Brown Rice',
        calories: 216.0,
        protein: 4.5,
        carbs: 44.8,
        fat: 1.8,
        servingGrams: 185.0,
      );

  // ---------------------------------------------------------------------------
  group('FoodItem – toMap / fromMap roundtrip', () {
    test('roundtrip preserves all numeric fields', () {
      final original = _chicken();
      final restored = FoodItem.fromMap(original.toMap());

      expect(restored.id, equals(original.id));
      expect(restored.name, equals(original.name));
      expect(restored.calories, closeTo(original.calories, 0.001));
      expect(restored.protein, closeTo(original.protein, 0.001));
      expect(restored.carbs, closeTo(original.carbs, 0.001));
      expect(restored.fat, closeTo(original.fat, 0.001));
      expect(restored.servingGrams, closeTo(original.servingGrams, 0.001));
    });

    test('roundtrip preserves barcode when present', () {
      final restored = FoodItem.fromMap(_chicken().toMap());
      expect(restored.barcode, equals('1234567890'));
    });

    test('roundtrip preserves null barcode', () {
      final restored = FoodItem.fromMap(_noBarcode().toMap());
      expect(restored.barcode, isNull);
    });

    test('toMap contains all expected keys', () {
      final map = _chicken().toMap();
      for (final key in [
        'id',
        'name',
        'calories',
        'protein',
        'carbs',
        'fat',
        'servingGrams',
        'barcode',
      ]) {
        expect(map.containsKey(key), isTrue,
            reason: 'expected key "$key" in toMap output');
      }
    });

    test('fromMap coerces int values to double', () {
      // Firestore may return numeric fields as int when the fractional part
      // is zero (e.g. calories stored as 200 instead of 200.0).
      final map = {
        'id': 'fi3',
        'name': 'Apple',
        'calories': 95, // int
        'protein': 0,   // int
        'carbs': 25,    // int
        'fat': 0,       // int
        'servingGrams': 182, // int
        'barcode': null,
      };
      final item = FoodItem.fromMap(map);
      expect(item.calories, isA<double>());
      expect(item.protein, isA<double>());
      expect(item.carbs, isA<double>());
      expect(item.fat, isA<double>());
      expect(item.servingGrams, isA<double>());
    });
  });

  // ---------------------------------------------------------------------------
  group('FoodItem – copyWith', () {
    test('copyWith changes only specified fields', () {
      final original = _chicken();
      final updated = original.copyWith(calories: 200.0, protein: 35.0);

      expect(updated.calories, closeTo(200.0, 0.001));
      expect(updated.protein, closeTo(35.0, 0.001));
      // Unchanged fields
      expect(updated.id, equals(original.id));
      expect(updated.name, equals(original.name));
      expect(updated.carbs, closeTo(original.carbs, 0.001));
      expect(updated.fat, closeTo(original.fat, 0.001));
      expect(updated.servingGrams, closeTo(original.servingGrams, 0.001));
      expect(updated.barcode, equals(original.barcode));
    });

    test('copyWith preserves barcode (not part of copyWith signature)', () {
      final updated = _chicken().copyWith(name: 'Grilled Chicken');
      expect(updated.barcode, equals('1234567890'));
    });
  });
}
