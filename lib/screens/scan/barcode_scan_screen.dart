import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../models/food_item.dart';
import '../../models/meal_log.dart';
import '../../providers/diary_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/food_database_service.dart';
import '../../utils/theme.dart';
import '../diary/add_food_screen.dart';
import '../paywall/paywall_screen.dart';

class BarcodeScanScreen extends StatefulWidget {
  final MealType mealType;
  const BarcodeScanScreen({super.key, this.mealType = MealType.lunch});

  @override
  State<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends State<BarcodeScanScreen>
    with SingleTickerProviderStateMixin {
  MobileScannerController? _cameraController;
  late AnimationController _scanLineController;
  FoodItem? _result;
  BarcodeFoundNoNutrition? _noNutritionResult;
  bool _isProcessing = false;
  String? _scannedBarcode;
  String? _errorMessage;
  DateTime? _lookupStartTime;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _scanLineController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing || _result != null || _errorMessage != null ||
        _noNutritionResult != null) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final barcode = barcodes.first.rawValue;
    if (barcode == null || barcode.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _scannedBarcode = barcode;
      _errorMessage = null;
    });

    _lookupBarcode(barcode);
  }

  Future<void> _lookupBarcode(String barcode) async {
    _lookupStartTime = DateTime.now();
    _elapsedSeconds = 0;

    // Timer to show elapsed time after 3 seconds
    Timer(const Duration(seconds: 3), () {
      if (!mounted || !_isProcessing) return;
      setState(() {
        _elapsedSeconds = DateTime.now().difference(_lookupStartTime!).inSeconds;
      });
    });

    try {
      final barcodeResult = await FoodDatabaseService.lookupBarcode(barcode);
      if (!mounted) return;
      _lookupStartTime = null;
      switch (barcodeResult) {
        case BarcodeFound(:final item):
          setState(() {
            _result = item;
            _isProcessing = false;
          });
        case BarcodeFoundNoNutrition():
          setState(() {
            _noNutritionResult = barcodeResult;
            _isProcessing = false;
          });
        case BarcodeNotFound():
          setState(() {
            _isProcessing = false;
            _errorMessage = 'Product not found in database';
          });
      }
    } catch (e) {
      if (!mounted) return;
      _lookupStartTime = null;
      final errorMsg = e.toString().toLowerCase();

      String message;
      if (errorMsg.contains('socketexception') ||
          errorMsg.contains('handshake') ||
          errorMsg.contains('connection') ||
          errorMsg.contains('network')) {
        message = 'No internet connection';
      } else if (errorMsg.contains('timeout') ||
          errorMsg.contains('timed out')) {
        message = 'Request timed out. Please try again.';
      } else if (errorMsg.contains('api') ||
          errorMsg.contains('invalid') ||
          errorMsg.contains('error')) {
        message = 'Error looking up product. Please try again.';
      } else {
        message = 'Unexpected error. Please try again.';
      }

      setState(() {
        _isProcessing = false;
        _errorMessage = message;
      });
    }
  }

  void _retryLookup() {
    if (_scannedBarcode == null) return;
    setState(() {
      _errorMessage = null;
      _isProcessing = true;
    });
    _lookupBarcode(_scannedBarcode!);
  }


  Future<void> _addToDiary() async {
    if (_result == null) return;
    final user = context.read<UserProvider>().user;
    if (user == null) return;

    if (!user.canScan) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PaywallScreen()),
      );
      return;
    }

    await context
        .read<DiaryProvider>()
        .addMeal(user.id, widget.mealType, [_result!]);
    await context.read<UserProvider>().incrementScanCount();
    if (mounted) Navigator.pop(context);
  }

  void _resetScan() {
    setState(() {
      _result = null;
      _noNutritionResult = null;
      _scannedBarcode = null;
      _isProcessing = false;
      _errorMessage = null;
      _lookupStartTime = null;
      _elapsedSeconds = 0;
    });
  }

  void _enterManually() {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddFoodScreen(mealType: widget.mealType),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // Camera
          if (_cameraController != null)
            MobileScanner(
              controller: _cameraController!,
              onDetect: _onDetect,
            ),

          // Dark overlay with cutout
          Positioned.fill(
            child: CustomPaint(
              painter: _ScanOverlayPainter(),
            ),
          ),

          // Animated scan line
          if (_result == null)
            Positioned(
              left: MediaQuery.of(context).size.width * 0.15,
              right: MediaQuery.of(context).size.width * 0.15,
              top: MediaQuery.of(context).size.height * 0.3,
              bottom: MediaQuery.of(context).size.height * 0.3,
              child: AnimatedBuilder(
                animation: _scanLineController,
                builder: (_, __) {
                  final height = MediaQuery.of(context).size.height * 0.4;
                  return Stack(
                    children: [
                      Positioned(
                        top: _scanLineController.value * (height - 2),
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 2,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                AppTheme.primary.withValues(alpha: 0.8),
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    AppTheme.primary.withValues(alpha: 0.3),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
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
                      'Barcode Scanner',
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

          // Instruction text
          if (_result == null && !_isProcessing)
            Positioned(
              bottom: MediaQuery.of(context).size.height * 0.22,
              left: 0,
              right: 0,
              child: const Text(
                'Point at a barcode',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.onBackground,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

          // Processing indicator
          if (_isProcessing)
            Positioned(
              bottom: MediaQuery.of(context).size.height * 0.2,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      color: AppTheme.primary,
                      strokeWidth: 2,
                      backgroundColor:
                          AppTheme.primary.withValues(alpha: 0.15),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _elapsedSeconds > 0
                        ? 'Looking up product... (${_elapsedSeconds}s)'
                        : 'Looking up product...',
                    style: const TextStyle(
                      color: AppTheme.onBackground,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

          // Found product but no nutrition data
          if (_noNutritionResult != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: const BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40, height: 4,
                          decoration: BoxDecoration(
                            color: AppTheme.cardLight,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          width: 64, height: 64,
                          decoration: BoxDecoration(
                            color: AppTheme.carbColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(Icons.no_food_rounded,
                              color: AppTheme.carbColor, size: 32),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _noNutritionResult!.name,
                          style: const TextStyle(
                            color: AppTheme.onBackground,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Nutrition data not found for this product',
                          style: TextStyle(
                              fontSize: 13, color: AppTheme.onCard),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _resetScan,
                                child: const Text('Scan Again'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: AppTheme.primaryGradient,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: ElevatedButton(
                                  onPressed: _enterManually,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                  ),
                                  child: const Text('Enter Manually'),
                                ),
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

          // Not found / error card
          if (_errorMessage != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: const BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SafeArea(
                  top: false,
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
                        const SizedBox(height: 20),
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppTheme.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(Icons.search_off_rounded,
                              color: AppTheme.error, size: 32),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: AppTheme.onBackground,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        if (_scannedBarcode != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Barcode: $_scannedBarcode',
                              style: const TextStyle(
                                  fontSize: 11, color: AppTheme.onCard),
                            ),
                          ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _retryLookup,
                                child: const Text('Try Again'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: AppTheme.primaryGradient,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: ElevatedButton(
                                  onPressed: _enterManually,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                  ),
                                  child: const Text('Enter Manually'),
                                ),
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

          // Result card
          if (_result != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: const BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SafeArea(
                  top: false,
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
                        // Product info
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.card,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: AppTheme.proteinColor
                                          .withValues(alpha: 0.15),
                                      borderRadius:
                                          BorderRadius.circular(14),
                                    ),
                                    child: const Icon(
                                      Icons.qr_code_rounded,
                                      color: AppTheme.proteinColor,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _result!.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                            color: AppTheme.onBackground,
                                          ),
                                        ),
                                        if (_scannedBarcode != null)
                                          Text(
                                            'Barcode: $_scannedBarcode',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.onCard,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${_result!.calories.toInt()} kcal',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primary,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              // Macros row
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _MacroInfo(
                                    label: 'Protein',
                                    value: '${_result!.protein.toInt()}g',
                                    color: AppTheme.proteinColor,
                                  ),
                                  _MacroInfo(
                                    label: 'Carbs',
                                    value: '${_result!.carbs.toInt()}g',
                                    color: AppTheme.carbColor,
                                  ),
                                  _MacroInfo(
                                    label: 'Fat',
                                    value: '${_result!.fat.toInt()}g',
                                    color: AppTheme.fatColor,
                                  ),
                                  _MacroInfo(
                                    label: 'Serving',
                                    value:
                                        '${_result!.servingGrams.toInt()}g',
                                    color: AppTheme.onSurface,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _resetScan,
                                child: const Text('Scan Again'),
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
                                  onPressed: _addToDiary,
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

class _ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cutoutRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.42),
        width: size.width * 0.7,
        height: size.height * 0.25,
      ),
      const Radius.circular(16),
    );

    // Dark overlay
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(cutoutRect);
    path.fillType = PathFillType.evenOdd;

    canvas.drawPath(
      path,
      Paint()..color = AppTheme.background.withValues(alpha: 0.7),
    );

    // Corner brackets
    final rect = cutoutRect.outerRect;
    const cornerLen = 30.0;
    const cornerStroke = 3.0;
    final cornerPaint = Paint()
      ..color = AppTheme.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = cornerStroke
      ..strokeCap = StrokeCap.round;

    // Top-left
    canvas.drawLine(
        Offset(rect.left, rect.top + cornerLen),
        Offset(rect.left, rect.top),
        cornerPaint);
    canvas.drawLine(
        Offset(rect.left, rect.top),
        Offset(rect.left + cornerLen, rect.top),
        cornerPaint);

    // Top-right
    canvas.drawLine(
        Offset(rect.right - cornerLen, rect.top),
        Offset(rect.right, rect.top),
        cornerPaint);
    canvas.drawLine(
        Offset(rect.right, rect.top),
        Offset(rect.right, rect.top + cornerLen),
        cornerPaint);

    // Bottom-left
    canvas.drawLine(
        Offset(rect.left, rect.bottom - cornerLen),
        Offset(rect.left, rect.bottom),
        cornerPaint);
    canvas.drawLine(
        Offset(rect.left, rect.bottom),
        Offset(rect.left + cornerLen, rect.bottom),
        cornerPaint);

    // Bottom-right
    canvas.drawLine(
        Offset(rect.right - cornerLen, rect.bottom),
        Offset(rect.right, rect.bottom),
        cornerPaint);
    canvas.drawLine(
        Offset(rect.right, rect.bottom),
        Offset(rect.right, rect.bottom - cornerLen),
        cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MacroInfo extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MacroInfo({
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
            fontSize: 15,
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
