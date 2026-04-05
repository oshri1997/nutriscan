import 'package:flutter/material.dart';
import '../models/meal_log.dart';
import '../utils/theme.dart';

class MealSection extends StatefulWidget {
  final MealType mealType;
  final List<MealLog> meals;
  final VoidCallback onAdd;
  final void Function(String mealId, String itemId) onDelete;

  const MealSection({
    super.key,
    required this.mealType,
    required this.meals,
    required this.onAdd,
    required this.onDelete,
  });

  @override
  State<MealSection> createState() => _MealSectionState();
}

class _MealSectionState extends State<MealSection>
    with SingleTickerProviderStateMixin {
  bool _expanded = true;
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;

  // Pending delete state for undo snackbar
  String? _pendingMealId;
  String? _pendingItemId;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0,
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    });
  }

  IconData get _icon => switch (widget.mealType) {
        MealType.breakfast => Icons.wb_sunny_rounded,
        MealType.lunch => Icons.restaurant_rounded,
        MealType.dinner => Icons.nightlight_round,
        MealType.snack => Icons.cookie_rounded,
      };

  String get _label => switch (widget.mealType) {
        MealType.breakfast => 'Breakfast',
        MealType.lunch => 'Lunch',
        MealType.dinner => 'Dinner',
        MealType.snack => 'Snacks',
      };

  Color get _accentColor => switch (widget.mealType) {
        MealType.breakfast => AppTheme.breakfastColor,
        MealType.lunch => AppTheme.lunchColor,
        MealType.dinner => AppTheme.dinnerColor,
        MealType.snack => AppTheme.snackColor,
      };

  @override
  Widget build(BuildContext context) {
    final totalCal =
        widget.meals.fold<double>(0, (s, m) => s + m.totalCalories);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: _toggleExpand,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Colored accent bar
                  Container(
                    width: 4,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _accentColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_icon, size: 18, color: _accentColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: AppTheme.onBackground,
                          ),
                        ),
                        if (widget.meals.isNotEmpty)
                          Text(
                            '${widget.meals.expand((m) => m.items).length} items',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.onCard,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (totalCal > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${totalCal.toInt()} kcal',
                        style: TextStyle(
                          color: _accentColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: widget.onAdd,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.add_rounded,
                          size: 18, color: AppTheme.primary),
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: AppTheme.onCard, size: 20),
                  ),
                ],
              ),
            ),
          ),
          // Expandable items
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: widget.meals.isNotEmpty
                ? Padding(
                    padding:
                        const EdgeInsets.only(left: 14, right: 14, bottom: 10),
                    child: Column(
                      children: widget.meals
                          .expand((meal) => meal.items.map((item) {
                                return Dismissible(
                                  key: Key('${meal.id}_${item.id}'),
                                  direction: DismissDirection.endToStart,
                                  confirmDismiss: (_) async {
                                    _pendingMealId = meal.id;
                                    _pendingItemId = item.id;
                                    return true;
                                  },
                                  onDismissed: (_) {
                                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text('Item deleted'),
                                        duration: const Duration(seconds: 3),
                                        action: SnackBarAction(
                                          label: 'Undo',
                                          onPressed: () {
                                            setState(() {
                                              _pendingMealId = null;
                                              _pendingItemId = null;
                                            });
                                          },
                                        ),
                                      ),
                                    );
                                    Future.delayed(const Duration(seconds: 3), () {
                                      if (!mounted) return;
                                      if (_pendingMealId == meal.id &&
                                          _pendingItemId == item.id) {
                                        widget.onDelete(meal.id, item.id);
                                        setState(() {
                                          _pendingMealId = null;
                                          _pendingItemId = null;
                                        });
                                      }
                                    });
                                  },
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20),
                                    decoration: BoxDecoration(
                                      color: AppTheme.error
                                          .withValues(alpha: 0.1),
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.delete_rounded,
                                        color: AppTheme.error, size: 20),
                                  ),
                                  child: Container(
                                    margin:
                                        const EdgeInsets.symmetric(vertical: 3),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: AppTheme.cardLight
                                          .withValues(alpha: 0.3),
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: _accentColor
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                              Icons.restaurant_rounded,
                                              size: 14,
                                              color: _accentColor),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.name,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                  color:
                                                      AppTheme.onBackground,
                                                ),
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                '${item.servingGrams.toInt()}g',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppTheme.onCard,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppTheme.background,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '${item.calories.toInt()} kcal',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.onSurface,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }))
                          .toList(),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.only(left: 14, right: 14, bottom: 10),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.restaurant_outlined,
                              color: _accentColor.withValues(alpha: 0.4),
                              size: 28,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Tap + to add food',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.onCard.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
