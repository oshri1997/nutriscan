import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_nutriscan/models/meal_log.dart';
import 'package:ai_nutriscan/screens/diary/add_food_screen.dart';

void main() {
  Future<void> _fillValidFields(WidgetTester tester) async {
    await tester.enterText(
        find.widgetWithText(TextField, 'Food Name'), 'Test Food');
    await tester.pump();
  }

  Future<void> _enterValidCalories(WidgetTester tester) async {
    await tester.enterText(
        find.widgetWithText(TextField, 'Calories (kcal)'), '100');
    await tester.pump();
  }

  group('AddFoodScreen – basic widget tests', () {
    testWidgets('screen renders with all input fields', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: AddFoodScreen(mealType: MealType.lunch)),
      );
      expect(find.text('Calories (kcal)'), findsOneWidget);
      expect(find.text('Protein (g)'), findsOneWidget);
      expect(find.text('Carbs (g)'), findsOneWidget);
      expect(find.text('Fat (g)'), findsOneWidget);
      expect(find.text('Serving Size (g)'), findsOneWidget);
      expect(find.text('Add Food'), findsOneWidget);
    });

    testWidgets('name field accepts text input', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: AddFoodScreen(mealType: MealType.lunch)),
      );
      await tester.enterText(
          find.widgetWithText(TextField, 'Food Name'), 'Chicken Breast');
      await tester.pump();
      // Both the preview Text widget AND the EditableText show the value
      expect(find.text('Chicken Breast'), findsWidgets);
    });
  });

  group('AddFoodScreen – range validation', () {
    testWidgets('no error for valid calories (2500)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: AddFoodScreen(mealType: MealType.lunch)),
      );
      await _fillValidFields(tester);
      await tester.enterText(
          find.widgetWithText(TextField, 'Calories (kcal)'), '2500');
      await tester.pumpAndSettle();
      expect(find.text('Calories must be 0-5000'), findsNothing);
    });

    testWidgets('error shown for negative calories', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: AddFoodScreen(mealType: MealType.lunch)),
      );
      await _fillValidFields(tester);
      await tester.enterText(
          find.widgetWithText(TextField, 'Calories (kcal)'), '-100');
      await tester.pumpAndSettle();
      // errorText appears twice: InputDecoration error + custom Text below
      expect(find.text('Calories must be 0-5000'), findsWidgets);
    });

    testWidgets('error shown for calories > 5000', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: AddFoodScreen(mealType: MealType.lunch)),
      );
      await _fillValidFields(tester);
      await tester.enterText(
          find.widgetWithText(TextField, 'Calories (kcal)'), '5001');
      await tester.pumpAndSettle();
      expect(find.text('Calories must be 0-5000'), findsWidgets);
    });

    testWidgets('error shown for very large calories (>10000)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: AddFoodScreen(mealType: MealType.lunch)),
      );
      await _fillValidFields(tester);
      await tester.enterText(
          find.widgetWithText(TextField, 'Calories (kcal)'), '99999');
      await tester.pumpAndSettle();
      expect(find.text('Calories must be 0-5000'), findsWidgets);
    });

    testWidgets('error shown for protein > 500g', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: AddFoodScreen(mealType: MealType.lunch)),
      );
      await _fillValidFields(tester);
      await _enterValidCalories(tester);
      await tester.enterText(
          find.widgetWithText(TextField, 'Protein (g)'), '501');
      await tester.pumpAndSettle();
      expect(find.text('Protein must be 0-500g'), findsWidgets);
    });

    testWidgets('error shown for carbs > 500g', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: AddFoodScreen(mealType: MealType.lunch)),
      );
      await _fillValidFields(tester);
      await _enterValidCalories(tester);
      await tester.enterText(
          find.widgetWithText(TextField, 'Carbs (g)'), '600');
      await tester.pumpAndSettle();
      expect(find.text('Carbs must be 0-500g'), findsWidgets);
    });

    testWidgets('error shown for fat > 500g', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: AddFoodScreen(mealType: MealType.lunch)),
      );
      await _fillValidFields(tester);
      await _enterValidCalories(tester);
      await tester.enterText(
          find.widgetWithText(TextField, 'Fat (g)'), '600');
      await tester.pumpAndSettle();
      expect(find.text('Fat must be 0-500g'), findsWidgets);
    });

    testWidgets('no error for valid macro values', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: AddFoodScreen(mealType: MealType.lunch)),
      );
      await _fillValidFields(tester);
      await _enterValidCalories(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Protein (g)'), '100');
      await tester.enterText(find.widgetWithText(TextField, 'Carbs (g)'), '200');
      await tester.enterText(find.widgetWithText(TextField, 'Fat (g)'), '50');
      await tester.pumpAndSettle();
      expect(find.text('Protein must be 0-500g'), findsNothing);
      expect(find.text('Carbs must be 0-500g'), findsNothing);
      expect(find.text('Fat must be 0-500g'), findsNothing);
    });

    testWidgets('all error messages shown for all invalid fields',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: AddFoodScreen(mealType: MealType.lunch)),
      );
      await _fillValidFields(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Calories (kcal)'), '-1');
      await tester.enterText(find.widgetWithText(TextField, 'Protein (g)'), '600');
      await tester.enterText(find.widgetWithText(TextField, 'Carbs (g)'), '600');
      await tester.enterText(find.widgetWithText(TextField, 'Fat (g)'), '600');
      await tester.pumpAndSettle();
      expect(find.text('Calories must be 0-5000'), findsWidgets);
      expect(find.text('Protein must be 0-500g'), findsWidgets);
      expect(find.text('Carbs must be 0-500g'), findsWidgets);
      expect(find.text('Fat must be 0-500g'), findsWidgets);
    });
  });
}
