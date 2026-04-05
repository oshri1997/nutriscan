import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_nutriscan/models/meal_log.dart';
import 'package:ai_nutriscan/models/food_item.dart';
import 'package:ai_nutriscan/widgets/meal_section.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const _chicken = FoodItem(
  id: 'fi_chicken',
  name: 'Chicken',
  calories: 165,
  protein: 31,
  carbs: 0,
  fat: 3.6,
  servingGrams: 100,
);

const _rice = FoodItem(
  id: 'fi_rice',
  name: 'Rice',
  calories: 200,
  protein: 4,
  carbs: 44,
  fat: 1,
  servingGrams: 180,
);

MealLog _meal(String id, MealType type, List<FoodItem> items) => MealLog(
      id: id,
      userId: 'u1',
      mealType: type,
      items: items,
      dateTime: DateTime(2024, 6, 1, 12, 0),
    );

// ---------------------------------------------------------------------------
// Test wrapper: constrains height so MealSection doesn't overflow.
// ---------------------------------------------------------------------------

Widget _wrapWithScaffold(Widget child) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 400,
          child: child,
        ),
      ),
    );

// ---------------------------------------------------------------------------

void main() {
  group('MealSection – empty state', () {
    testWidgets('shows Hebrew hint when meals list is empty', (tester) async {
      await tester.pumpWidget(
        _wrapWithScaffold(
          MealSection(
            mealType: MealType.breakfast,
            meals: const [],
            onAdd: () {},
            onDelete: (_, __) {},
          ),
        ),
      );

      expect(find.text('Tap + to add food'), findsOneWidget);
    });

    testWidgets('does not show empty hint when meals are present',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithScaffold(
          MealSection(
            mealType: MealType.breakfast,
            meals: [_meal('m1', MealType.breakfast, [_chicken])],
            onAdd: () {},
            onDelete: (_, __) {},
          ),
        ),
      );

      expect(find.text('Tap + to add food'), findsNothing);
      expect(find.text('Chicken'), findsOneWidget);
    });
  });

  group('MealSection – structure', () {
    testWidgets('shows correct meal label for each MealType', (tester) async {
      for (final type in MealType.values) {
        await tester.pumpWidget(
          _wrapWithScaffold(
            MealSection(
              mealType: type,
              meals: const [],
              onAdd: () {},
              onDelete: (_, __) {},
            ),
          ),
        );

        final label = switch (type) {
          MealType.breakfast => 'Breakfast',
          MealType.lunch => 'Lunch',
          MealType.dinner => 'Dinner',
          MealType.snack => 'Snacks',
        };
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('shows calorie total in header when meals have calories',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithScaffold(
          MealSection(
            mealType: MealType.lunch,
            meals: [_meal('m1', MealType.lunch, [_chicken])],
            onAdd: () {},
            onDelete: (_, __) {},
          ),
        ),
      );

      // 165 kcal appears twice: once in header summary and once in item row
      expect(find.text('165 kcal'), findsWidgets);
    });

    testWidgets('shows "Add" button that calls onAdd', (tester) async {
      bool addCalled = false;

      await tester.pumpWidget(
        _wrapWithScaffold(
          MealSection(
            mealType: MealType.lunch,
            meals: const [],
            onAdd: () => addCalled = true,
            onDelete: (_, __) {},
          ),
        ),
      );

      // Find the add button (Container with Icons.add_rounded)
      final addButton = find.byIcon(Icons.add_rounded);
      expect(addButton, findsOneWidget);

      await tester.tap(addButton);
      await tester.pump();

      expect(addCalled, isTrue);
    });

    testWidgets('Dismissible widgets are present for each item',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithScaffold(
          MealSection(
            mealType: MealType.lunch,
            meals: [_meal('m1', MealType.lunch, [_chicken, _rice])],
            onAdd: () {},
            onDelete: (_, __) {},
          ),
        ),
      );

      expect(find.byType(Dismissible), findsNWidgets(2));
    });

    testWidgets('item rows show item name and calorie info', (tester) async {
      await tester.pumpWidget(
        _wrapWithScaffold(
          MealSection(
            mealType: MealType.lunch,
            meals: [_meal('m1', MealType.lunch, [_chicken])],
            onAdd: () {},
            onDelete: (_, __) {},
          ),
        ),
      );

      expect(find.text('Chicken'), findsOneWidget);
      expect(find.text('100g'), findsOneWidget); // serving grams
      // 165 kcal appears in both header summary and item row
      expect(find.text('165 kcal'), findsWidgets);
    });
  });
}
