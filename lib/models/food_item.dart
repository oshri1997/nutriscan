class FoodItem {
  final String id;
  final String name;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double servingGrams;
  final String? barcode;

  const FoodItem({
    required this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.servingGrams,
    this.barcode,
  });

  FoodItem copyWith({
    String? name,
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
    double? servingGrams,
  }) => FoodItem(
    id: id,
    name: name ?? this.name,
    calories: calories ?? this.calories,
    protein: protein ?? this.protein,
    carbs: carbs ?? this.carbs,
    fat: fat ?? this.fat,
    servingGrams: servingGrams ?? this.servingGrams,
    barcode: barcode,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'servingGrams': servingGrams,
    'barcode': barcode,
  };

  factory FoodItem.fromMap(Map<String, dynamic> m) => FoodItem(
    id: m['id'],
    name: m['name'],
    calories: (m['calories'] as num).toDouble(),
    protein: (m['protein'] as num).toDouble(),
    carbs: (m['carbs'] as num).toDouble(),
    fat: (m['fat'] as num).toDouble(),
    servingGrams: (m['servingGrams'] as num).toDouble(),
    barcode: m['barcode'],
  );
}
