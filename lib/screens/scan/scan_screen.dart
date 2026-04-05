import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/food_item.dart';
import '../../models/meal_log.dart';
import '../../models/scan_event.dart';
import '../../providers/diary_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/ai_scan_service.dart';
import '../../services/database_service.dart';
import '../../utils/theme.dart';
import '../../widgets/ai_scan_loader.dart';
import '../paywall/paywall_screen.dart';

class ScanScreen extends StatefulWidget {
  final MealType mealType;
  const ScanScreen({super.key, this.mealType = MealType.lunch});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with TickerProviderStateMixin {
  final _aiService = AIScanService();
  final _picker = ImagePicker();

  File? _image;
  List<FoodItem>? _results;
  bool _loading = false;
  String? _error;
  MealType _selectedMealType = MealType.lunch;

  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _selectedMealType = widget.mealType;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _pickAndScan(ImageSource source) async {
    final user = context.read<UserProvider>().user;
    if (user != null && !user.canScan) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PaywallScreen()),
      );
      return;
    }

    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 1024,
    );
    if (picked == null) return;

    setState(() {
      _image = File(picked.path);
      _loading = true;
      _error = null;
      _results = null;
    });

    try {
      final items = await _aiService.analyzeImage(_image!);
      if (!mounted) return;
      setState(() {
        _results = items;
        _loading = false;
      });
      _slideController.forward(from: 0);
    } catch (e) {
      String message;
      if (e.toString().contains('SocketException') ||
          e.toString().contains('TimeoutException') ||
          e.toString().contains('ClientException')) {
        message = 'No internet connection. Please try again.';
      } else if (e.toString().contains('429')) {
        message = 'Daily scan limit reached.';
      } else if (e.toString().contains('50') ||
          e.toString().contains('502') ||
          e.toString().contains('503') ||
          e.toString().contains('504')) {
        message = 'Server error. Please try again later.';
      } else {
        message = 'Analysis failed. Please take a clearer photo.';
      }
      setState(() {
        _error = message;
        _loading = false;
      });
    }
  }

  Future<void> _retryScan() async {
    try {
      final items = await _aiService.analyzeImage(_image!);
      if (!mounted) return;
      setState(() {
        _results = items;
        _loading = false;
      });
      _slideController.forward(from: 0);
    } catch (e) {
      String message;
      if (e.toString().contains('SocketException') ||
          e.toString().contains('TimeoutException') ||
          e.toString().contains('ClientException')) {
        message = 'No internet connection. Please try again.';
      } else if (e.toString().contains('429')) {
        message = 'Daily scan limit reached.';
      } else if (e.toString().contains('50') ||
          e.toString().contains('502') ||
          e.toString().contains('503') ||
          e.toString().contains('504')) {
        message = 'Server error. Please try again later.';
      } else {
        message = 'Analysis failed. Please take a clearer photo.';
      }
      setState(() {
        _error = message;
        _loading = false;
      });
    }
  }

  Future<void> _confirm() async {
    if (_results == null || _results!.isEmpty) return;
    final user = context.read<UserProvider>().user;
    if (user == null) return;

    setState(() => _loading = true);
    try {
      final db = DatabaseService();
      await db.saveScanEvent(ScanEvent(
        id: const Uuid().v4(),
        userId: user.id,
        imageUrl: _image?.path,
        aiResponse: _results!.map((i) => i.name).join(', '),
        createdAt: DateTime.now(),
      ));

      if (!mounted) return;
      await context.read<DiaryProvider>().addMeal(user.id, _selectedMealType, _results!);
      await context.read<UserProvider>().incrementScanCount();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to save. Please try again.'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _editItem(int index) {
    final item = _results![index];
    showDialog(
      context: context,
      builder: (_) => _EditItemDialog(
        item: item,
        onSave: (updated) {
          setState(() {
            _results![index] = updated;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // Image / camera area
          Positioned.fill(
            child: _image != null
                ? Image.file(_image!, fit: BoxFit.cover)
                : Container(
                    decoration: const BoxDecoration(
                      gradient: AppTheme.backgroundGradient,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (_, child) => Opacity(
                            opacity: 0.4 + _pulseController.value * 0.6,
                            child: child,
                          ),
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: AppTheme.primary.withValues(alpha: 0.3),
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.restaurant_rounded,
                              size: 64,
                              color: AppTheme.onCard,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Take a photo of your food',
                          style: TextStyle(
                            color: AppTheme.onSurface,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'AI will analyze the nutrition',
                          style: TextStyle(
                            color: AppTheme.onCard,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),

          // Loading overlay
          if (_loading)
            Positioned.fill(
              child: Container(
                color: AppTheme.background.withValues(alpha: 0.88),
                child: const Center(
                  child: AIScanLoader(size: 110, showLabels: true),
                ),
              ),
            ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.background.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.close_rounded,
                            color: AppTheme.onBackground),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'AI Scan',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppTheme.onBackground,
                          ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),

          // Error
          if (_error != null)
            Positioned(
              bottom: 120,
              left: 24,
              right: 24,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppTheme.error, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: AppTheme.error,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          if (_image != null) {
                            setState(() {
                              _loading = true;
                              _error = null;
                            });
                            _retryScan();
                          }
                        },
                        child: const Text('Retry'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Results bottom sheet
          if (_results != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _slideController,
                builder: (_, child) => IgnorePointer(
                  ignoring: _slideController.isAnimating,
                  child: child!,
                ),
                child: SlideTransition(
                position: _slideAnimation,
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.55,
                  ),
                  decoration: const BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.cardLight,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // Meal type selector
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Row(
                          children: [
                            Text('Results',
                                style:
                                    Theme.of(context).textTheme.titleLarge),
                            const Spacer(),
                            _MealTypeChip(
                              selectedType: _selectedMealType,
                              onChanged: (type) =>
                                  setState(() => _selectedMealType = type),
                            ),
                          ],
                        ),
                      ),
                      // Total
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Text(
                              'Total: ${_results!.fold<double>(0, (s, i) => s + i.calories).toInt()} kcal',
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Items
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _results!.length,
                          itemBuilder: (_, i) =>
                              _ResultItemCard(
                                item: _results![i],
                                onEdit: () => _editItem(i),
                              ),
                        ),
                      ),
                      // Action buttons
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => setState(() {
                                  _results = null;
                                  _image = null;
                                }),
                                child: const Text('Rescan'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: AppTheme.primaryGradient,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primary
                                          .withValues(alpha: 0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _confirm,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                  ),
                                  child: const Text('Add to Diary'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Disclaimer
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Values are estimates and not a substitute for professional advice',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.onCard,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ),
            ),

          // Camera buttons (when no results)
          if (_results == null && !_loading)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      // Gallery
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.card,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: IconButton(
                          onPressed: () =>
                              _pickAndScan(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_rounded,
                              color: AppTheme.onSurface),
                          iconSize: 28,
                          padding: const EdgeInsets.all(14),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Capture button
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary
                                    .withValues(alpha: 0.3),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                _pickAndScan(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt_rounded),
                            label: const Text('Capture'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ResultItemCard extends StatelessWidget {
  final FoodItem item;
  final VoidCallback onEdit;

  const _ResultItemCard({required this.item, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
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
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.restaurant_rounded,
                color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppTheme.onBackground,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _MiniChip(
                        label: 'P ${item.protein.toInt()}g',
                        color: AppTheme.proteinColor),
                    const SizedBox(width: 4),
                    _MiniChip(
                        label: 'C ${item.carbs.toInt()}g',
                        color: AppTheme.carbColor),
                    const SizedBox(width: 4),
                    _MiniChip(
                        label: 'F ${item.fat.toInt()}g',
                        color: AppTheme.fatColor),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${item.calories.toInt()} kcal',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${item.servingGrams.toInt()}g',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.onCard,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onEdit,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.cardLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.edit_rounded,
                  color: AppTheme.onSurface, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _MealTypeChip extends StatelessWidget {
  final MealType selectedType;
  final ValueChanged<MealType> onChanged;

  const _MealTypeChip({
    required this.selectedType,
    required this.onChanged,
  });

  String _label(MealType type) => switch (type) {
        MealType.breakfast => 'Breakfast',
        MealType.lunch => 'Lunch',
        MealType.dinner => 'Dinner',
        MealType.snack => 'Snack',
      };

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<MealType>(
      onSelected: onChanged,
      color: AppTheme.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      itemBuilder: (_) => MealType.values
          .map((t) => PopupMenuItem(
                value: t,
                child: Text(_label(t),
                    style: const TextStyle(color: AppTheme.onBackground)),
              ))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _label(selectedType),
              style: const TextStyle(
                color: AppTheme.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded,
                color: AppTheme.onCard, size: 18),
          ],
        ),
      ),
    );
  }
}

class _EditItemDialog extends StatefulWidget {
  final FoodItem item;
  final ValueChanged<FoodItem> onSave;

  const _EditItemDialog({required this.item, required this.onSave});

  @override
  State<_EditItemDialog> createState() => _EditItemDialogState();
}

class _EditItemDialogState extends State<_EditItemDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _calCtrl;
  late final TextEditingController _proteinCtrl;
  late final TextEditingController _carbsCtrl;
  late final TextEditingController _fatCtrl;
  late final TextEditingController _servingCtrl;

  String? _calError;
  String? _proteinError;
  String? _carbsError;
  String? _fatError;
  String? _servingError;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item.name);
    _calCtrl =
        TextEditingController(text: widget.item.calories.toStringAsFixed(0));
    _proteinCtrl =
        TextEditingController(text: widget.item.protein.toStringAsFixed(0));
    _carbsCtrl =
        TextEditingController(text: widget.item.carbs.toStringAsFixed(0));
    _fatCtrl =
        TextEditingController(text: widget.item.fat.toStringAsFixed(0));
    _servingCtrl =
        TextEditingController(text: widget.item.servingGrams.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _calCtrl.dispose();
    _proteinCtrl.dispose();
    _carbsCtrl.dispose();
    _fatCtrl.dispose();
    _servingCtrl.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _calError == null &&
      _proteinError == null &&
      _carbsError == null &&
      _fatError == null &&
      _servingError == null;

  void _validateRanges() {
    final cal = double.tryParse(_calCtrl.text);
    _calError = (cal == null || cal < 0 || cal > 5000)
        ? 'Must be 0-5000'
        : null;

    final protein = double.tryParse(_proteinCtrl.text);
    _proteinError = (protein == null || protein < 0 || protein > 500)
        ? 'Must be 0-500g'
        : null;

    final carbs = double.tryParse(_carbsCtrl.text);
    _carbsError = (carbs == null || carbs < 0 || carbs > 500)
        ? 'Must be 0-500g'
        : null;

    final fat = double.tryParse(_fatCtrl.text);
    _fatError = (fat == null || fat < 0 || fat > 500)
        ? 'Must be 0-500g'
        : null;

    final serving = double.tryParse(_servingCtrl.text);
    _servingError = (serving == null || serving < 1 || serving > 5000)
        ? 'Must be 1-5000g'
        : null;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Edit Item',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              _EditField(controller: _nameCtrl, label: 'Name'),
              const SizedBox(height: 10),
              _EditField(
                  controller: _calCtrl,
                  label: 'Calories',
                  isNumeric: true,
                  errorText: _calError),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                      child: _EditField(
                          controller: _proteinCtrl,
                          label: 'Protein (g)',
                          isNumeric: true,
                          errorText: _proteinError)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _EditField(
                          controller: _carbsCtrl,
                          label: 'Carbs (g)',
                          isNumeric: true,
                          errorText: _carbsError)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                      child: _EditField(
                          controller: _fatCtrl,
                          label: 'Fat (g)',
                          isNumeric: true,
                          errorText: _fatError)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _EditField(
                          controller: _servingCtrl,
                          label: 'Serving (g)',
                          isNumeric: true,
                          errorText: _servingError)),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      _validateRanges();
                      if (!_isValid) {
                        setState(() {});
                        return;
                      }
                      widget.onSave(widget.item.copyWith(
                        name: _nameCtrl.text,
                        calories:
                            double.tryParse(_calCtrl.text) ?? widget.item.calories,
                        protein: double.tryParse(_proteinCtrl.text) ??
                            widget.item.protein,
                        carbs:
                            double.tryParse(_carbsCtrl.text) ?? widget.item.carbs,
                        fat: double.tryParse(_fatCtrl.text) ?? widget.item.fat,
                        servingGrams:
                            double.tryParse(_servingCtrl.text) ??
                                widget.item.servingGrams,
                      ));
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(100, 44),
                    ),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool isNumeric;
  final String? errorText;

  const _EditField({
    required this.controller,
    required this.label,
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
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            errorText: errorText,
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 4),
            child: Text(
              errorText!,
              style: const TextStyle(
                color: AppTheme.error,
                fontSize: 10,
              ),
            ),
          ),
      ],
    );
  }
}
