import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/diary_provider.dart';
import '../../providers/user_provider.dart';
import '../../utils/theme.dart';
import '../settings/settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _barAnimController;
  late Animation<double> _barAnimation;
  Map<int, double> _weeklyData = {};

  @override
  void initState() {
    super.initState();
    _barAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _barAnimation = CurvedAnimation(
      parent: _barAnimController,
      curve: Curves.easeOutCubic,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadWeeklyData());
  }

  @override
  void dispose() {
    _barAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadWeeklyData() async {
    final user = context.read<UserProvider>().user;
    if (user == null) return;

    final diary = context.read<DiaryProvider>();
    final today = DateTime.now();

    final futures = List.generate(7, (i) async {
      final date = today.subtract(Duration(days: 6 - i));
      final meals = await diary.getMealsForDateRaw(user.id, date);
      return meals.fold<double>(0, (s, m) => s + m.totalCalories);
    });

    final results = await Future.wait(futures);
    if (!mounted) return;

    final data = <int, double>{};
    for (int i = 0; i < 7; i++) {
      data[i] = results[i];
    }

    setState(() => _weeklyData = data);
    _barAnimController.forward(from: 0);
  }

  int _calculateStreak() {
    int streak = 0;
    // Start from index 5 (yesterday), not index 6 (today)
    for (int i = 5; i >= 0; i--) {
      if ((_weeklyData[i] ?? 0) > 0) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  String _dayLabel(int index) {
    final today = DateTime.now();
    final date = today.subtract(Duration(days: 6 - index));
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    final diary = context.watch<DiaryProvider>();

    if (user == null) return const SizedBox.shrink();

    final streak = _calculateStreak();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
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
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
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
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.name,
                                  style:
                                      Theme.of(context).textTheme.titleLarge,
                                ),
                                Text(
                                  user.isPro ? 'Pro Member' : 'Free Plan',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: user.isPro
                                        ? AppTheme.primary
                                        : AppTheme.onCard,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                            },
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.card,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.settings_rounded,
                                  color: AppTheme.onSurface, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Streak + Today stats row
                  Row(
                    children: [
                      Expanded(
                        child: _InfoCard(
                          icon: Icons.local_fire_department_rounded,
                          iconColor: AppTheme.fatColor,
                          title: '$streak days',
                          subtitle: 'Log Streak',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _InfoCard(
                          icon: Icons.restaurant_rounded,
                          iconColor: AppTheme.primary,
                          title:
                              '${diary.totalCalories.toInt()} kcal',
                          subtitle: 'Today',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // BMR / TDEE grid
                  Row(
                    children: [
                      Expanded(
                        child: _InfoCard(
                          icon: Icons.monitor_heart_rounded,
                          iconColor: AppTheme.proteinColor,
                          title: '${user.bmr.toInt()} kcal',
                          subtitle: 'BMR',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _InfoCard(
                          icon: Icons.directions_run_rounded,
                          iconColor: AppTheme.carbColor,
                          title: '${user.tdee.toInt()} kcal',
                          subtitle: 'TDEE',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _InfoCard(
                          icon: Icons.flag_rounded,
                          iconColor: AppTheme.secondary,
                          title:
                              '${user.dailyCalorieTarget.toInt()} kcal',
                          subtitle: 'Daily Target',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _InfoCard(
                          icon: Icons.camera_alt_rounded,
                          iconColor: AppTheme.snackColor,
                          title:
                              '${user.dailyScanCount}/${user.maxFreeDailyScans}',
                          subtitle: 'Scans Today',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Weekly chart
                  Text('This Week',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: SizedBox(
                      height: 200,
                      child: AnimatedBuilder(
                        animation: _barAnimation,
                        builder: (_, __) => BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: user.dailyCalorieTarget * 1.3,
                            barTouchData: BarTouchData(
                              enabled: true,
                              touchTooltipData: BarTouchTooltipData(
                                getTooltipColor: (_) => AppTheme.surface,
                                tooltipRoundedRadius: 10,
                                getTooltipItem: (group, _, rod, __) {
                                  return BarTooltipItem(
                                    '${rod.toY.toInt()} kcal',
                                    const TextStyle(
                                      color: AppTheme.onBackground,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  );
                                },
                              ),
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (v, _) => Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      _dayLabel(v.toInt()),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: v.toInt() == 6
                                            ? AppTheme.primary
                                            : AppTheme.onCard,
                                        fontWeight: v.toInt() == 6
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              leftTitles: const AxisTitles(
                                  sideTitles:
                                      SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(
                                  sideTitles:
                                      SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(
                                  sideTitles:
                                      SideTitles(showTitles: false)),
                            ),
                            borderData: FlBorderData(show: false),
                            gridData: const FlGridData(show: false),
                            barGroups: List.generate(7, (i) {
                              final val = (_weeklyData[i] ?? 0) *
                                  _barAnimation.value;
                              final isOverTarget =
                                  (_weeklyData[i] ?? 0) >
                                      user.dailyCalorieTarget;
                              return BarChartGroupData(x: i, barRods: [
                                BarChartRodData(
                                  toY: val,
                                  gradient: isOverTarget
                                      ? const LinearGradient(
                                          colors: [
                                            AppTheme.fatColor,
                                            Color(0xFFFF6E40),
                                          ],
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                        )
                                      : const LinearGradient(
                                          colors: [
                                            AppTheme.primary,
                                            AppTheme.secondary,
                                          ],
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                        ),
                                  width: 22,
                                  borderRadius:
                                      const BorderRadius.vertical(
                                          top: Radius.circular(6)),
                                ),
                              ]);
                            }),
                            extraLinesData: ExtraLinesData(
                              horizontalLines: [
                                HorizontalLine(
                                  y: user.dailyCalorieTarget,
                                  color: AppTheme.error
                                      .withValues(alpha: 0.4),
                                  strokeWidth: 1,
                                  dashArray: [6, 4],
                                  label: HorizontalLineLabel(
                                    show: true,
                                    labelResolver: (_) => 'Target',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppTheme.error,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Body Stats
                  Text('Body Stats',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        _StatRow(
                            label: 'Height',
                            value: '${user.heightCm.toInt()} cm'),
                        _StatRow(
                            label: 'Weight',
                            value:
                                '${user.weightKg.toStringAsFixed(1)} kg'),
                        _StatRow(
                            label: 'Target Weight',
                            value:
                                '${user.targetWeightKg.toStringAsFixed(1)} kg'),
                        _StatRow(
                            label: 'Activity',
                            value: _activityLabel(user.activityLevel)),
                        _StatRow(
                            label: 'Goal',
                            value: _goalLabel(user.goal)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _activityLabel(dynamic level) => switch (level.toString()) {
        'ActivityLevel.sedentary' => 'Sedentary',
        'ActivityLevel.light' => 'Light',
        'ActivityLevel.moderate' => 'Moderate',
        'ActivityLevel.active' => 'Active',
        'ActivityLevel.veryActive' => 'Very Active',
        _ => 'Unknown',
      };

  String _goalLabel(dynamic goal) => switch (goal.toString()) {
        'Goal.lose' => 'Lose Weight',
        'Goal.maintain' => 'Maintain',
        'Goal.gain' => 'Gain Muscle',
        _ => 'Unknown',
      };
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _InfoCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppTheme.onBackground,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.onCard,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                color: AppTheme.onCard,
                fontSize: 14,
              )),
          Text(value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.onBackground,
                fontSize: 14,
              )),
        ],
      ),
    );
  }
}
