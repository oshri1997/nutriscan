import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/food_item.dart';
import 'package:uuid/uuid.dart';

// ---- Result types ----

sealed class BarcodeResult {}

/// Product found with full nutrition data.
class BarcodeFound extends BarcodeResult {
  final FoodItem item;
  BarcodeFound(this.item);
}

/// Product found by name/brand but nutrition data is missing in the database.
class BarcodeFoundNoNutrition extends BarcodeResult {
  final String name;
  final String? brand;
  BarcodeFoundNoNutrition(this.name, this.brand);
}

/// Product barcode not in Open Food Facts at all.
class BarcodeNotFound extends BarcodeResult {}

// ---- Service ----

class FoodDatabaseService {
  static const _uuid = Uuid();

  /// Looks up a barcode using Open Food Facts.
  static Future<BarcodeResult> lookupBarcode(String barcode) async {
    final uri = Uri.parse(
      'https://world.openfoodfacts.org/api/v2/product/$barcode.json'
      '?fields=product_name,product_name_he,brands,nutriments,serving_size,serving_quantity',
    );

    final response = await http
        .get(uri, headers: {'User-Agent': 'NutriSnap-App/1.0'})
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) return BarcodeNotFound();

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if ((json['status'] as int? ?? 0) != 1) return BarcodeNotFound();

    final product = json['product'] as Map<String, dynamic>?;
    if (product == null) return BarcodeNotFound();

    // Prefer Hebrew name, fall back to English
    final name =
        (product['product_name_he'] as String?)?.trim().isNotEmpty == true
            ? product['product_name_he'] as String
            : (product['product_name'] as String?)?.trim() ?? '';

    if (name.isEmpty) return BarcodeNotFound();

    final brand = (product['brands'] as String?)?.split(',').first.trim();
    final nutriments = product['nutriments'] as Map<String, dynamic>? ?? {};

    // Check if any meaningful calorie data exists
    final caloriesRaw = _toDouble(nutriments['energy-kcal_100g']) ??
        (_toDouble(nutriments['energy_100g']) != null
            ? _toDouble(nutriments['energy_100g'])! / 4.184
            : null);

    if (caloriesRaw == null || caloriesRaw == 0) {
      // Product known but nutrition missing — caller will offer AI estimation
      return BarcodeFoundNoNutrition(name, brand);
    }

    final protein = _toDouble(nutriments['proteins_100g']) ?? 0;
    final carbs = _toDouble(nutriments['carbohydrates_100g']) ?? 0;
    final fat = _toDouble(nutriments['fat_100g']) ?? 0;

    // Always show per 100g
    return BarcodeFound(FoodItem(
      id: _uuid.v4(),
      name: name,
      calories: caloriesRaw,
      protein: protein,
      carbs: carbs,
      fat: fat,
      servingGrams: 100,
      barcode: barcode,
    ));
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

}
