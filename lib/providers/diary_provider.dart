import 'package:flutter/material.dart';
import '../models/meal_log.dart';
import '../models/food_item.dart';
import '../services/database_service.dart';
import 'package:uuid/uuid.dart';

class DiaryProvider extends ChangeNotifier {
  final DatabaseService _db;
  static const _uuid = Uuid();

  List<MealLog> _todayMeals = [];
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  DiaryProvider(this._db);

  List<MealLog> get todayMeals => _todayMeals;
  DateTime get selectedDate => _selectedDate;
  bool get isLoading => _isLoading;

  double get totalCalories =>
      _todayMeals.fold(0, (s, m) => s + m.totalCalories);
  double get totalProtein =>
      _todayMeals.fold(0, (s, m) => s + m.totalProtein);
  double get totalCarbs => _todayMeals.fold(0, (s, m) => s + m.totalCarbs);
  double get totalFat => _todayMeals.fold(0, (s, m) => s + m.totalFat);

  List<MealLog> mealsOfType(MealType type) =>
      _todayMeals.where((m) => m.mealType == type).toList();

  Future<void> loadMeals(String userId, {DateTime? date}) async {
    _isLoading = true;
    notifyListeners();
    _selectedDate = date ?? DateTime.now();
    _todayMeals = await _db.getMealsForDate(userId, _selectedDate);
    _isLoading = false;
    notifyListeners();
  }

  /// Get meals for a specific date without modifying provider state.
  /// Used by DashboardScreen for historical weekly data.
  Future<List<MealLog>> getMealsForDateRaw(
      String userId, DateTime date) async {
    return _db.getMealsForDate(userId, date);
  }

  Future<void> addMeal(
      String userId, MealType type, List<FoodItem> items) async {
    final meal = MealLog(
      id: _uuid.v4(),
      userId: userId,
      mealType: type,
      items: items,
      dateTime: DateTime.now(),
    );
    try {
      await _db.saveMealLog(meal);
    } catch (e) {
      rethrow;
    }
    await loadMeals(userId, date: _selectedDate);
  }

  Future<void> deleteMeal(String userId, String mealId) async {
    await _db.deleteMealLog(mealId);
    await loadMeals(userId, date: _selectedDate);
  }

  Future<void> deleteItem(String userId, String mealId, String itemId) async {
    await _db.deleteItemFromMeal(mealId, itemId);
    await loadMeals(userId, date: _selectedDate);
  }
}
