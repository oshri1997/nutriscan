import 'package:cloud_firestore/cloud_firestore.dart';
import 'food_item.dart';

enum MealType { breakfast, lunch, dinner, snack }

class MealLog {
  final String id;
  final String userId;
  final MealType mealType;
  final List<FoodItem> items;
  final DateTime dateTime;

  const MealLog({
    required this.id,
    required this.userId,
    required this.mealType,
    required this.items,
    required this.dateTime,
  });

  double get totalCalories => items.fold(0, (s, i) => s + i.calories);
  double get totalProtein => items.fold(0, (s, i) => s + i.protein);
  double get totalCarbs => items.fold(0, (s, i) => s + i.carbs);
  double get totalFat => items.fold(0, (s, i) => s + i.fat);

  String get mealLabel => switch (mealType) {
    MealType.breakfast => 'Breakfast',
    MealType.lunch => 'Lunch',
    MealType.dinner => 'Dinner',
    MealType.snack => 'Snack',
  };

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'mealType': mealType.index,
    'dateTime': Timestamp.fromDate(dateTime),
  };

  factory MealLog.fromMap(Map<String, dynamic> m, List<FoodItem> items) =>
      MealLog(
        id: m['id'],
        userId: m['userId'],
        mealType: MealType.values[m['mealType']],
        items: items,
        dateTime: (m['dateTime'] as Timestamp).toDate(),
      );
}
