import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_profile.dart';
import '../../providers/user_provider.dart';
import '../../utils/theme.dart';
import '../paywall/paywall_screen.dart';
import 'subscription_management_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          // Header
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
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Column(
                    children: [
                      // Back button row
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.card,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.arrow_back_ios_rounded,
                                  color: AppTheme.onBackground, size: 18),
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            'Profile & Settings',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.onBackground,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      // Avatar
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.3),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            user.name.isNotEmpty
                                ? user.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Color(0xFF003300),
                              fontWeight: FontWeight.w800,
                              fontSize: 34,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        user.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.onBackground,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Pro / Free badge
                      user.isPro
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 5),
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.star_rounded,
                                      color: Color(0xFF003300), size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'PRO Member',
                                    style: TextStyle(
                                      color: Color(0xFF003300),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppTheme.cardLight,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Free · ${user.dailyScanCount}/${user.maxFreeDailyScans} scans today',
                                style: const TextStyle(
                                  color: AppTheme.onCard,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverList(
            delegate: SliverChildListDelegate([
              // ---- Body Stats ----
              _SectionHeader(title: 'Body & Goals'),
              _StatsGrid(user: user),
              const SizedBox(height: 8),

              // ---- Edit options ----
              _SectionHeader(title: 'Edit Profile'),
              _SettingsTile(
                icon: Icons.monitor_weight_rounded,
                iconColor: AppTheme.carbColor,
                title: 'Current Weight',
                subtitle: '${user.weightKg.toInt()} kg',
                onTap: () => _editWeight(context, user),
              ),
              _SettingsTile(
                icon: Icons.flag_rounded,
                iconColor: AppTheme.fatColor,
                title: 'Goal',
                subtitle: _goalLabel(user.goal),
                onTap: () => _editGoal(context, user),
              ),
              _SettingsTile(
                icon: Icons.directions_run_rounded,
                iconColor: AppTheme.proteinColor,
                title: 'Activity Level',
                subtitle: _activityLabel(user.activityLevel),
                onTap: () => _editActivity(context, user),
              ),
              const SizedBox(height: 8),

              // ---- Daily Targets ----
              _SectionHeader(title: 'Daily Targets'),
              _TargetsCard(user: user),
              const SizedBox(height: 8),

              // ---- Subscription ----
              _SectionHeader(title: 'Subscription'),
              if (!user.isPro)
                _UpgradeCard(onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PaywallScreen()),
                  );
                })
              else
                _SettingsTile(
                  icon: Icons.star_rounded,
                  iconColor: AppTheme.primary,
                  title: 'Manage Subscription',
                  subtitle: 'View plan details & billing',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SubscriptionManagementScreen()),
                    );
                  },
                ),
              const SizedBox(height: 8),

              // ---- App Info ----
              _SectionHeader(title: 'App'),
              _SettingsTile(
                icon: Icons.info_outline_rounded,
                iconColor: AppTheme.onCard,
                title: 'NutriSnap',
                subtitle: 'Version 1.0.0',
                onTap: null,
              ),
              const SizedBox(height: 100),
            ]),
          ),
        ],
      ),
    );
  }

  // ---- Edit Dialogs ----

  void _editWeight(BuildContext context, UserProfile user) {
    final ctrl = TextEditingController(text: user.weightKg.toInt().toString());
    showDialog(
      context: context,
      builder: (_) => _EditDialog(
        title: 'Update Weight',
        controller: ctrl,
        suffix: 'kg',
        keyboardType: TextInputType.number,
        onSave: () {
          final val = double.tryParse(ctrl.text);
          if (val != null && val > 0) {
            context
                .read<UserProvider>()
                .saveProfile(user.copyWith(weightKg: val));
          }
        },
      ),
    );
  }

  void _editGoal(BuildContext context, UserProfile user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _GoalSheet(
        current: user.goal,
        onSelect: (goal) {
          context
              .read<UserProvider>()
              .saveProfile(user.copyWith(goal: goal));
        },
      ),
    );
  }

  void _editActivity(BuildContext context, UserProfile user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ActivitySheet(
        current: user.activityLevel,
        onSelect: (level) {
          context
              .read<UserProvider>()
              .saveProfile(user.copyWith(activityLevel: level));
        },
      ),
    );
  }

  static String _goalLabel(Goal g) => switch (g) {
        Goal.lose => 'Lose Weight',
        Goal.maintain => 'Maintain Weight',
        Goal.gain => 'Gain Muscle',
      };

  static String _activityLabel(ActivityLevel l) => switch (l) {
        ActivityLevel.sedentary => 'Sedentary',
        ActivityLevel.light => 'Light (1-2x/week)',
        ActivityLevel.moderate => 'Moderate (3-5x/week)',
        ActivityLevel.active => 'Active (6-7x/week)',
        ActivityLevel.veryActive => 'Very Active',
      };
}

// ---- Stats Grid ----

class _StatsGrid extends StatelessWidget {
  final UserProfile user;
  const _StatsGrid({required this.user});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
              child: _StatCell(
                  label: 'Weight',
                  value: '${user.weightKg.toInt()}',
                  unit: 'kg',
                  color: AppTheme.carbColor)),
          const SizedBox(width: 8),
          Expanded(
              child: _StatCell(
                  label: 'Height',
                  value: '${user.heightCm.toInt()}',
                  unit: 'cm',
                  color: AppTheme.proteinColor)),
          const SizedBox(width: 8),
          Expanded(
              child: _StatCell(
                  label: 'Age',
                  value: '${user.age}',
                  unit: 'yrs',
                  color: AppTheme.fatColor)),
          const SizedBox(width: 8),
          Expanded(
              child: _StatCell(
                  label: 'Target',
                  value: '${user.targetWeightKg.toInt()}',
                  unit: 'kg',
                  color: AppTheme.secondary)),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _StatCell(
      {required this.label,
      required this.value,
      required this.unit,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: color)),
          Text(unit,
              style: const TextStyle(
                  fontSize: 10, color: AppTheme.onCard)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.onCard,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ---- Targets Card ----

class _TargetsCard extends StatelessWidget {
  final UserProfile user;
  const _TargetsCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            _TargetRow(
              label: 'Calories',
              value: '${user.dailyCalorieTarget.toInt()} kcal',
              color: AppTheme.primary,
              icon: Icons.local_fire_department_rounded,
            ),
            const SizedBox(height: 10),
            _TargetRow(
              label: 'Protein',
              value: '${user.proteinTarget.toInt()} g',
              color: AppTheme.proteinColor,
              icon: Icons.egg_alt_rounded,
            ),
            const SizedBox(height: 10),
            _TargetRow(
              label: 'Carbs',
              value: '${user.carbTarget.toInt()} g',
              color: AppTheme.carbColor,
              icon: Icons.grain_rounded,
            ),
            const SizedBox(height: 10),
            _TargetRow(
              label: 'Fat',
              value: '${user.fatTarget.toInt()} g',
              color: AppTheme.fatColor,
              icon: Icons.opacity_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

class _TargetRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _TargetRow(
      {required this.label,
      required this.value,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Text(label,
            style: const TextStyle(
                color: AppTheme.onSurface, fontSize: 14)),
        const Spacer(),
        Text(value,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 14)),
      ],
    );
  }
}

// ---- Upgrade Card ----

class _UpgradeCard extends StatelessWidget {
  final VoidCallback onTap;
  const _UpgradeCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A2235), Color(0xFF0F1D2E)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.star_rounded,
                    color: Color(0xFF003300), size: 26),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upgrade to Pro',
                      style: TextStyle(
                        color: AppTheme.onBackground,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'Unlimited scans · Advanced analytics',
                      style:
                          TextStyle(color: AppTheme.onCard, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.primary, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

// ---- Section Header ----

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppTheme.onCard,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ---- Settings Tile ----

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.onBackground)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.onCard)),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.onCard, size: 18),
          ],
        ),
      ),
    );
  }
}

// ---- Edit Weight Dialog ----

class _EditDialog extends StatelessWidget {
  final String title;
  final TextEditingController controller;
  final String suffix;
  final TextInputType keyboardType;
  final VoidCallback onSave;

  const _EditDialog({
    required this.title,
    required this.controller,
    required this.suffix,
    required this.keyboardType,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        keyboardType: keyboardType,
        autofocus: true,
        style: const TextStyle(color: AppTheme.onBackground),
        decoration: InputDecoration(suffixText: suffix),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            onSave();
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(80, 40),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// ---- Goal Sheet ----

class _GoalSheet extends StatelessWidget {
  final Goal current;
  final void Function(Goal) onSelect;

  const _GoalSheet({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const options = [
      (Goal.lose, 'Lose Weight', Icons.local_fire_department_rounded,
          AppTheme.fatColor),
      (Goal.maintain, 'Maintain Weight', Icons.bolt_rounded,
          AppTheme.carbColor),
      (Goal.gain, 'Gain Muscle', Icons.fitness_center_rounded,
          AppTheme.proteinColor),
    ];

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: AppTheme.cardLight,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          const Text('Select Goal',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onBackground)),
          const SizedBox(height: 16),
          ...options.map((o) {
            final (goal, label, icon, color) = o;
            final selected = current == goal;
            return GestureDetector(
              onTap: () {
                onSelect(goal);
                Navigator.pop(context);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: selected
                      ? color.withValues(alpha: 0.1)
                      : AppTheme.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? color : AppTheme.cardLight,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(icon,
                        color: selected ? color : AppTheme.onCard,
                        size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(label,
                          style: TextStyle(
                              color: selected
                                  ? color
                                  : AppTheme.onBackground,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                    ),
                    if (selected)
                      Icon(Icons.check_circle_rounded,
                          color: color, size: 20),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ---- Activity Sheet ----

class _ActivitySheet extends StatelessWidget {
  final ActivityLevel current;
  final void Function(ActivityLevel) onSelect;

  const _ActivitySheet({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const options = [
      (ActivityLevel.sedentary, 'Sedentary', 'Little to no exercise'),
      (ActivityLevel.light, 'Light', '1-2 workouts/week'),
      (ActivityLevel.moderate, 'Moderate', '3-5 workouts/week'),
      (ActivityLevel.active, 'Active', '6-7 workouts/week'),
      (ActivityLevel.veryActive, 'Very Active', 'Athlete / heavy labor'),
    ];

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: AppTheme.cardLight,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          const Text('Activity Level',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onBackground)),
          const SizedBox(height: 16),
          ...options.map((o) {
            final (level, label, desc) = o;
            final selected = current == level;
            return GestureDetector(
              onTap: () {
                onSelect(level);
                Navigator.pop(context);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: selected
                      ? AppTheme.primary.withValues(alpha: 0.1)
                      : AppTheme.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? AppTheme.primary
                        : AppTheme.cardLight,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label,
                              style: TextStyle(
                                  color: selected
                                      ? AppTheme.primary
                                      : AppTheme.onBackground,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14)),
                          Text(desc,
                              style: const TextStyle(
                                  color: AppTheme.onCard,
                                  fontSize: 11)),
                        ],
                      ),
                    ),
                    if (selected)
                      const Icon(Icons.check_circle_rounded,
                          color: AppTheme.primary, size: 20),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
