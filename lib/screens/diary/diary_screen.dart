import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../models/meal_log.dart';
import '../../providers/diary_provider.dart';
import '../../providers/user_provider.dart';
import '../../utils/theme.dart';
import '../../widgets/calorie_summary_card.dart';
import '../../widgets/meal_section.dart';
import '../scan/scan_screen.dart';
import '../scan/barcode_scan_screen.dart';
import '../settings/settings_screen.dart';
import 'add_food_screen.dart';

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  late DateTime _selectedDate;
  late int _selectedDayIndex;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _selectedDayIndex = 6; // today is last in the strip
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<UserProvider>().user;
      if (user != null) {
        context.read<DiaryProvider>().loadMeals(user.id, date: _selectedDate);
      }
    });
  }

  List<DateTime> get _weekDates {
    final today = DateTime.now();
    return List.generate(
      7,
      (i) => today.subtract(Duration(days: 6 - i)),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _dayLabel(DateTime date) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }

  void _selectDate(int index) {
    final user = context.read<UserProvider>().user;
    if (user == null) return;
    setState(() {
      _selectedDayIndex = index;
      _selectedDate = _weekDates[index];
    });
    context.read<DiaryProvider>().loadMeals(user.id, date: _selectedDate);
  }

  Color _mealTypeColor(MealType type) => switch (type) {
        MealType.breakfast => AppTheme.breakfastColor,
        MealType.lunch => AppTheme.lunchColor,
        MealType.dinner => AppTheme.dinnerColor,
        MealType.snack => AppTheme.snackColor,
      };

  void _addFood(MealType type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddFoodOptionsSheet(mealType: type, parentContext: context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    final diary = context.watch<DiaryProvider>();

    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      body: RefreshIndicator(
        color: AppTheme.primary,
        backgroundColor: AppTheme.surface,
        onRefresh: () => diary.loadMeals(user.id, date: _selectedDate),
        child: CustomScrollView(
          slivers: [
            // Hero header
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0F1525), AppTheme.background],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                    child: Column(
                      children: [
                        // Greeting
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_greeting()},',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(color: AppTheme.onCard),
                                  ),
                                  Text(
                                    user.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall,
                                  ),
                                ],
                              ),
                            ),
                            // Avatar — taps to Settings
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SettingsScreen(),
                                ),
                              ),
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: AppTheme.primaryGradient,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Center(
                                  child: Text(
                                    user.name.isNotEmpty
                                        ? user.name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: Color(0xFF003300),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Calorie ring
                        CalorieSummaryCard(
                          calories: diary.totalCalories,
                          calorieTarget: user.dailyCalorieTarget,
                          protein: diary.totalProtein,
                          proteinTarget: user.proteinTarget,
                          carbs: diary.totalCarbs,
                          carbTarget: user.carbTarget,
                          fat: diary.totalFat,
                          fatTarget: user.fatTarget,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Date strip
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  height: 72,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: 7,
                    itemBuilder: (_, i) {
                      final date = _weekDates[i];
                      final isSelected = i == _selectedDayIndex;
                      final isToday = i == 6;
                      return GestureDetector(
                        onTap: () => _selectDate(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: 48,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.primary : AppTheme.card,
                            borderRadius: BorderRadius.circular(14),
                            border: isToday && !isSelected
                                ? Border.all(
                                    color: AppTheme.primary.withValues(alpha: 0.3),
                                    width: 1,
                                  )
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _dayLabel(date),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: isSelected
                                      ? const Color(0xFF003300)
                                      : AppTheme.onCard,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${date.day}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? const Color(0xFF003300)
                                      : AppTheme.onBackground,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            // Meal sections
            SliverList(
              delegate: SliverChildListDelegate([
                if (diary.isLoading)
                  ...MealType.values.map((type) => _ShimmerMealSection(accentColor: _mealTypeColor(type)))
                else
                  ...MealType.values.map((type) => MealSection(
                        mealType: type,
                        meals: diary.mealsOfType(type),
                        onAdd: () => _addFood(type),
                        onDelete: (mealId, itemId) => diary.deleteItem(user.id, mealId, itemId),
                      )),
                const SizedBox(height: 120),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddFoodOptionsSheet extends StatelessWidget {
  final MealType mealType;
  final BuildContext parentContext;

  const _AddFoodOptionsSheet({
    required this.mealType,
    required this.parentContext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.cardLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text('Add Food', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _OptionTile(
              icon: Icons.camera_alt_rounded,
              title: 'AI Scan',
              subtitle: 'Photo analysis with AI',
              color: AppTheme.primary,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  parentContext,
                  MaterialPageRoute(
                    builder: (_) => ScanScreen(mealType: mealType),
                  ),
                );
              },
            ),
            _OptionTile(
              icon: Icons.qr_code_scanner_rounded,
              title: 'Barcode',
              subtitle: 'Scan packaged product',
              color: AppTheme.proteinColor,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  parentContext,
                  MaterialPageRoute(
                    builder: (_) => BarcodeScanScreen(mealType: mealType),
                  ),
                );
              },
            ),
            _OptionTile(
              icon: Icons.edit_note_rounded,
              title: 'Manual Entry',
              subtitle: 'Enter food details',
              color: AppTheme.carbColor,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  parentContext,
                  MaterialPageRoute(
                    builder: (_) => AddFoodScreen(mealType: mealType),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: AppTheme.onBackground,
                      )),
                  Text(subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.onCard,
                      )),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppTheme.onCard, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ShimmerMealSection extends StatelessWidget {
  final Color accentColor;

  const _ShimmerMealSection({required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Shimmer.fromColors(
        baseColor: AppTheme.cardLight,
        highlightColor: AppTheme.card.withValues(alpha: 0.5),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 70,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 40,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 60,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
