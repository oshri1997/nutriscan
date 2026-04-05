import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/food_item.dart';
import '../../models/meal_log.dart';
import '../../providers/diary_provider.dart';
import '../../providers/user_provider.dart';
import '../../utils/theme.dart';

class AddFoodScreen extends StatefulWidget {
  final MealType mealType;
  const AddFoodScreen({super.key, required this.mealType});

  @override
  State<AddFoodScreen> createState() => _AddFoodScreenState();
}

class _AddFoodScreenState extends State<AddFoodScreen> {
  final _nameCtrl = TextEditingController();
  final _calCtrl = TextEditingController();
  final _proteinCtrl = TextEditingController();
  final _carbCtrl = TextEditingController();
  final _fatCtrl = TextEditingController();
  final _servingCtrl = TextEditingController(text: '100');

  bool _saving = false;

  String? _calError;
  String? _proteinError;
  String? _carbsError;
  String? _fatError;
  String? _servingError;

  @override
  void initState() {
    super.initState();
    // Listen to all controllers for live preview
    for (final ctrl in [
      _nameCtrl,
      _calCtrl,
      _proteinCtrl,
      _carbCtrl,
      _fatCtrl,
      _servingCtrl,
    ]) {
      ctrl.addListener(_onChanged);
    }
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _nameCtrl.dispose();
    _calCtrl.dispose();
    _proteinCtrl.dispose();
    _carbCtrl.dispose();
    _fatCtrl.dispose();
    _servingCtrl.dispose();
    super.dispose();
  }

  bool get _isValid {
    if (_nameCtrl.text.trim().isEmpty) return false;
    if (double.tryParse(_calCtrl.text) == null) return false;
    _validateRanges();
    return _calError == null &&
        _proteinError == null &&
        _carbsError == null &&
        _fatError == null &&
        _servingError == null;
  }

  void _validateRanges() {
    final cal = double.tryParse(_calCtrl.text);
    _calError = (cal == null || cal < 0 || cal > 5000)
        ? 'Calories must be 0-5000'
        : null;

    final protein = double.tryParse(_proteinCtrl.text);
    _proteinError = (protein == null || protein < 0 || protein > 500)
        ? 'Protein must be 0-500g'
        : null;

    final carbs = double.tryParse(_carbCtrl.text);
    _carbsError = (carbs == null || carbs < 0 || carbs > 500)
        ? 'Carbs must be 0-500g'
        : null;

    final fat = double.tryParse(_fatCtrl.text);
    _fatError = (fat == null || fat < 0 || fat > 500)
        ? 'Fat must be 0-500g'
        : null;

    final serving = double.tryParse(_servingCtrl.text);
    _servingError = (serving == null || serving < 1 || serving > 5000)
        ? 'Serving must be 1-5000g'
        : null;
  }

  double get _previewCalories =>
      double.tryParse(_calCtrl.text) ?? 0;

  double get _previewProtein =>
      double.tryParse(_proteinCtrl.text) ?? 0;

  double get _previewCarbs =>
      double.tryParse(_carbCtrl.text) ?? 0;

  double get _previewFat =>
      double.tryParse(_fatCtrl.text) ?? 0;

  Future<void> _save() async {
    _validateRanges();
    if (!_isValid || _saving) return;
    setState(() => _saving = true);

    final user = context.read<UserProvider>().user;
    if (user == null) {
      setState(() => _saving = false);
      return;
    }

    final item = FoodItem(
      id: const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      calories: double.tryParse(_calCtrl.text) ?? 0,
      protein: double.tryParse(_proteinCtrl.text) ?? 0,
      carbs: double.tryParse(_carbCtrl.text) ?? 0,
      fat: double.tryParse(_fatCtrl.text) ?? 0,
      servingGrams: double.tryParse(_servingCtrl.text) ?? 100,
    );

    await context
        .read<DiaryProvider>()
        .addMeal(user.id, widget.mealType, [item]);
    if (mounted) Navigator.pop(context);
  }

  String get _mealLabel => switch (widget.mealType) {
        MealType.breakfast => 'Breakfast',
        MealType.lunch => 'Lunch',
        MealType.dinner => 'Dinner',
        MealType.snack => 'Snack',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Add to $_mealLabel'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Live preview card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppTheme.cardGradient,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isValid
                    ? AppTheme.primary.withValues(alpha: 0.3)
                    : AppTheme.cardLight,
              ),
            ),
            child: Column(
              children: [
                Text(
                  _nameCtrl.text.isEmpty ? 'Food Name' : _nameCtrl.text,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _nameCtrl.text.isEmpty
                        ? AppTheme.onCard
                        : AppTheme.onBackground,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_previewCalories.toInt()} kcal',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: _previewCalories > 0
                        ? AppTheme.primary
                        : AppTheme.onCard,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _PreviewMacro(
                      label: 'Protein',
                      value: '${_previewProtein.toInt()}g',
                      color: AppTheme.proteinColor,
                    ),
                    _PreviewMacro(
                      label: 'Carbs',
                      value: '${_previewCarbs.toInt()}g',
                      color: AppTheme.carbColor,
                    ),
                    _PreviewMacro(
                      label: 'Fat',
                      value: '${_previewFat.toInt()}g',
                      color: AppTheme.fatColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Form fields
          _FormField(controller: _nameCtrl, label: 'Food Name', icon: Icons.restaurant_rounded),
          const SizedBox(height: 12),
          _FormField(
            controller: _calCtrl,
            label: 'Calories (kcal)',
            icon: Icons.local_fire_department_rounded,
            isNumeric: true,
            errorText: _calError,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _FormField(
                  controller: _proteinCtrl,
                  label: 'Protein (g)',
                  isNumeric: true,
                  errorText: _proteinError,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _FormField(
                  controller: _carbCtrl,
                  label: 'Carbs (g)',
                  isNumeric: true,
                  errorText: _carbsError,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _FormField(
                  controller: _fatCtrl,
                  label: 'Fat (g)',
                  isNumeric: true,
                  errorText: _fatError,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _FormField(
            controller: _servingCtrl,
            label: 'Serving Size (g)',
            icon: Icons.scale_rounded,
            isNumeric: true,
            errorText: _servingError,
          ),
          const SizedBox(height: 28),

          // Add button
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _isValid ? 1.0 : 0.5,
            child: GestureDetector(
              onTap: _isValid ? _save : null,
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: _isValid
                      ? AppTheme.primaryGradient
                      : const LinearGradient(colors: [
                          AppTheme.cardLight,
                          AppTheme.cardLight,
                        ]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _isValid
                      ? [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: _saving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Color(0xFF003300),
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          'Add Food',
                          style: TextStyle(
                            color: _isValid
                                ? const Color(0xFF003300)
                                : AppTheme.onCard,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
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

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData? icon;
  final bool isNumeric;
  final String? errorText;

  const _FormField({
    required this.controller,
    required this.label,
    this.icon,
    this.isNumeric = false,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
          style: const TextStyle(color: AppTheme.onBackground),
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: icon != null
                ? Icon(icon, color: AppTheme.onCard, size: 20)
                : null,
            errorText: errorText,
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 12),
            child: Text(
              errorText!,
              style: const TextStyle(
                color: AppTheme.error,
                fontSize: 11,
              ),
            ),
          ),
      ],
    );
  }
}

class _PreviewMacro extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _PreviewMacro({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.onCard,
          ),
        ),
      ],
    );
  }
}
