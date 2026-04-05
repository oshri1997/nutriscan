import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/user_profile.dart';
import '../../providers/user_provider.dart';
import '../../utils/theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final _pageController = PageController();
  int _page = 0;

  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _targetWeightCtrl = TextEditingController();

  Gender _gender = Gender.male;
  ActivityLevel _activity = ActivityLevel.moderate;
  Goal _goal = Goal.lose;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  late AnimationController _successController;
  late Animation<double> _successScale;
  String? _validationError;
  bool _showSuccess = false;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _successScale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _successController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _targetWeightCtrl.dispose();
    _shakeController.dispose();
    _successController.dispose();
    super.dispose();
  }

  bool _validate() {
    switch (_page) {
      case 0:
        if (_nameCtrl.text.trim().isEmpty) {
          _showValidationError('Please enter your name');
          return false;
        }
        break;
      case 1:
        final age = int.tryParse(_ageCtrl.text);
        final height = double.tryParse(_heightCtrl.text);
        final weight = double.tryParse(_weightCtrl.text);
        final target = double.tryParse(_targetWeightCtrl.text);
        if (age == null || age < 10 || age > 120) {
          _showValidationError('Enter a valid age (10-120)');
          return false;
        }
        if (height == null || height < 100 || height > 250) {
          _showValidationError('Enter a valid height (100-250 cm)');
          return false;
        }
        if (weight == null || weight < 30 || weight > 300) {
          _showValidationError('Enter a valid weight (30-300 kg)');
          return false;
        }
        if (target == null || target < 30 || target > 300) {
          _showValidationError('Enter a valid target weight (30-300 kg)');
          return false;
        }
        break;
    }
    _validationError = null;
    return true;
  }

  void _showValidationError(String msg) {
    setState(() => _validationError = msg);
    _shakeController.forward(from: 0);
  }

  void _next() {
    if (!_validate()) return;
    setState(() => _validationError = null);

    if (_page < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _save();
    }
  }

  Future<void> _save() async {
    setState(() => _showSuccess = true);
    _successController.forward();

    final profile = UserProfile(
      id: const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      age: int.tryParse(_ageCtrl.text) ?? 25,
      gender: _gender,
      heightCm: double.tryParse(_heightCtrl.text) ?? 170,
      weightKg: double.tryParse(_weightCtrl.text) ?? 70,
      targetWeightKg: double.tryParse(_targetWeightCtrl.text) ?? 65,
      activityLevel: _activity,
      goal: _goal,
    );

    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    await context.read<UserProvider>().saveProfile(profile);
  }

  @override
  Widget build(BuildContext context) {
    if (_showSuccess) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
          child: Center(
            child: AnimatedBuilder(
              animation: _successScale,
              builder: (_, __) => Transform.scale(
                scale: _successScale.value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppTheme.primaryGradient,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.4),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 50,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Your goals are set!',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Let\'s start tracking',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Animated dot indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final isActive = i == _page;
                  final isPast = i < _page;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    width: isActive ? 28 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: isActive
                          ? AppTheme.primary
                          : isPast
                              ? AppTheme.primary.withValues(alpha: 0.5)
                              : AppTheme.cardLight,
                    ),
                  );
                }),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (p) => setState(() {
                    _page = p;
                    _validationError = null;
                  }),
                  children: [
                    _buildWelcomePage(),
                    _buildBodyPage(),
                    _buildActivityPage(),
                    _buildGoalPage(),
                  ],
                ),
              ),
              // Validation error
              AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (_, child) {
                  final dx = math.sin(_shakeAnimation.value * math.pi * 4) * 10;
                  return Transform.translate(
                    offset: Offset(dx, 0),
                    child: child,
                  );
                },
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _validationError != null
                      ? Padding(
                          key: ValueKey(_validationError),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.error.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.error.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    color: AppTheme.error, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _validationError!,
                                    style: const TextStyle(
                                      color: AppTheme.error,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
              // Next button
              Padding(
                padding: const EdgeInsets.all(24),
                child: _GradientButton(
                  onPressed: _next,
                  label: _page < 3 ? 'Continue' : 'Let\'s Go!',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return _PageLayout(
      icon: Icons.bolt_rounded,
      iconColor: AppTheme.primary,
      title: 'Welcome to NutriSnap',
      subtitle: 'AI-powered nutrition tracking.\nWhat should we call you?',
      child: _GlassTextField(
        controller: _nameCtrl,
        hint: 'Your name',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppTheme.onBackground,
        ),
      ),
    );
  }

  Widget _buildBodyPage() {
    return _PageLayout(
      icon: Icons.accessibility_new_rounded,
      iconColor: AppTheme.secondary,
      title: 'Your Body Stats',
      subtitle: 'We need a few details to calculate your targets.',
      child: Column(
        children: [
          // Gender cards
          Row(
            children: [
              Expanded(
                child: _GenderCard(
                  icon: Icons.male_rounded,
                  label: 'Male',
                  selected: _gender == Gender.male,
                  onTap: () => setState(() => _gender = Gender.male),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _GenderCard(
                  icon: Icons.female_rounded,
                  label: 'Female',
                  selected: _gender == Gender.female,
                  onTap: () => setState(() => _gender = Gender.female),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _GlassTextField(
                  controller: _ageCtrl,
                  hint: 'Age',
                  suffix: 'yrs',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _GlassTextField(
                  controller: _heightCtrl,
                  hint: 'Height',
                  suffix: 'cm',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _GlassTextField(
                  controller: _weightCtrl,
                  hint: 'Weight',
                  suffix: 'kg',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _GlassTextField(
                  controller: _targetWeightCtrl,
                  hint: 'Target',
                  suffix: 'kg',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityPage() {
    const levels = [
      (ActivityLevel.sedentary, 'Sedentary', 'Little to no exercise', Icons.weekend_rounded),
      (ActivityLevel.light, 'Light', '1-2 workouts/week', Icons.directions_walk_rounded),
      (ActivityLevel.moderate, 'Moderate', '3-5 workouts/week', Icons.directions_run_rounded),
      (ActivityLevel.active, 'Active', '6-7 workouts/week', Icons.fitness_center_rounded),
      (ActivityLevel.veryActive, 'Very Active', 'Athlete / heavy labor', Icons.local_fire_department_rounded),
    ];

    return _PageLayout(
      icon: Icons.directions_run_rounded,
      iconColor: AppTheme.carbColor,
      title: 'Activity Level',
      subtitle: 'How active are you on a typical week?',
      child: Column(
        children: levels.map((data) {
          final (level, label, desc, icon) = data;
          final selected = _activity == level;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () => setState(() => _activity = level),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: selected
                      ? AppTheme.primary.withValues(alpha: 0.1)
                      : AppTheme.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? AppTheme.primary : AppTheme.cardLight,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(icon,
                        color: selected ? AppTheme.primary : AppTheme.onCard,
                        size: 24),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: selected
                                  ? AppTheme.primary
                                  : AppTheme.onBackground,
                            ),
                          ),
                          Text(
                            desc,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.onCard,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (selected)
                      const Icon(Icons.check_circle_rounded,
                          color: AppTheme.primary, size: 22),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGoalPage() {
    const goals = [
      (Goal.lose, 'Lose Weight', 'Calorie deficit for fat loss', Icons.local_fire_department_rounded, AppTheme.fatColor),
      (Goal.maintain, 'Maintain', 'Keep your current weight', Icons.bolt_rounded, AppTheme.carbColor),
      (Goal.gain, 'Gain Muscle', 'Calorie surplus for growth', Icons.fitness_center_rounded, AppTheme.proteinColor),
    ];

    return _PageLayout(
      icon: Icons.flag_rounded,
      iconColor: AppTheme.fatColor,
      title: 'Your Goal',
      subtitle: 'What are you working towards?',
      child: Column(
        children: goals.map((data) {
          final (goal, label, desc, icon, color) = data;
          final selected = _goal == goal;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: () => setState(() => _goal = goal),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: selected
                      ? LinearGradient(
                          colors: [
                            color.withValues(alpha: 0.15),
                            color.withValues(alpha: 0.05),
                          ],
                        )
                      : null,
                  color: selected ? null : AppTheme.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected ? color : AppTheme.cardLight,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: color, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                              color: selected ? color : AppTheme.onBackground,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            desc,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.onCard,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (selected)
                      Icon(Icons.check_circle_rounded, color: color, size: 24),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ---- Reusable widgets ----

class _PageLayout extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget child;

  const _PageLayout({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(icon, color: iconColor, size: 36),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          child,
        ],
      ),
    );
  }
}

class _GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String? suffix;
  final TextInputType keyboardType;
  final TextAlign textAlign;
  final TextStyle? style;

  const _GlassTextField({
    required this.controller,
    required this.hint,
    this.suffix,
    this.keyboardType = TextInputType.text,
    this.textAlign = TextAlign.start,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textAlign: textAlign,
      style: style ??
          const TextStyle(
            fontSize: 16,
            color: AppTheme.onBackground,
          ),
      decoration: InputDecoration(
        hintText: hint,
        suffixText: suffix,
      ),
    );
  }
}

class _GenderCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _GenderCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 90,
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary.withValues(alpha: 0.1)
              : AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.cardLight,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 32,
                color: selected ? AppTheme.primary : AppTheme.onCard),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: selected ? AppTheme.primary : AppTheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;

  const _GradientButton({required this.onPressed, required this.label});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF003300),
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
