import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/theme.dart';

class AIScanLoader extends StatefulWidget {
  final double size;
  final bool showLabels;
  final List<String>? labels;

  const AIScanLoader({
    super.key,
    this.size = 100,
    this.showLabels = true,
    this.labels,
  });

  @override
  State<AIScanLoader> createState() => _AIScanLoaderState();
}

class _AIScanLoaderState extends State<AIScanLoader> with TickerProviderStateMixin {
  late AnimationController _outerCtrl;
  late AnimationController _middleCtrl;
  late AnimationController _innerCtrl;
  late AnimationController _scanCtrl;
  late AnimationController _labelCtrl;

  int _labelIndex = 0;

  static const _defaultLabels = [
    'Reading image...',
    'Identifying foods...',
    'Estimating nutrients...',
    'Calculating macros...',
  ];

  List<String> get _labels => widget.labels ?? _defaultLabels;

  @override
  void initState() {
    super.initState();
    _outerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();
    _middleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3600))..repeat();
    _innerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
    _scanCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();
    _labelCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() => _labelIndex = (_labelIndex + 1) % _labels.length);
          _labelCtrl.forward(from: 0);
        }
      });
    _labelCtrl.forward();
  }

  @override
  void dispose() {
    _outerCtrl.dispose();
    _middleCtrl.dispose();
    _innerCtrl.dispose();
    _scanCtrl.dispose();
    _labelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rings = SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_outerCtrl, _middleCtrl, _innerCtrl, _scanCtrl]),
        builder: (_, __) => CustomPaint(
          painter: _ScanRingsPainter(
            outerAngle: _outerCtrl.value * 2 * math.pi,
            middleAngle: -_middleCtrl.value * 2 * math.pi,
            innerAngle: _innerCtrl.value * 2 * math.pi,
            scanProgress: _scanCtrl.value,
          ),
        ),
      ),
    );

    if (!widget.showLabels) return rings;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        rings,
        const SizedBox(height: 28),
        AnimatedBuilder(
          animation: _labelCtrl,
          builder: (_, __) {
            final t = _labelCtrl.value;
            final opacity = (t < 0.2 ? t / 0.2 : t > 0.8 ? (1.0 - t) / 0.2 : 1.0).clamp(0.0, 1.0);
            return Opacity(
              opacity: opacity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _labels[_labelIndex],
                    style: const TextStyle(
                      color: AppTheme.onBackground,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_labelIndex + 1} of ${_labels.length}',
                    style: const TextStyle(color: AppTheme.onCard, fontSize: 12),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ScanRingsPainter extends CustomPainter {
  final double outerAngle, middleAngle, innerAngle, scanProgress;

  const _ScanRingsPainter({
    required this.outerAngle,
    required this.middleAngle,
    required this.innerAngle,
    required this.scanProgress,
  });

  static double _deg(double d) => d * math.pi / 180;

  void _drawSegmentedRing({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required double strokeWidth,
    required Color color,
    required double baseAngle,
    required List<double> arcSweeps,
    required List<double> gapSweeps,
    required double glowAlpha,
  }) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    double angle = baseAngle;
    for (int i = 0; i < arcSweeps.length; i++) {
      canvas.drawArc(rect, angle, arcSweeps[i], false,
          Paint()
            ..color = color.withValues(alpha: glowAlpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth + 4
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      canvas.drawArc(rect, angle, arcSweeps[i], false,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth
            ..strokeCap = StrokeCap.round);
      angle += arcSweeps[i] + gapSweeps[i];
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;

    _drawSegmentedRing(canvas: canvas, center: center, radius: maxR * 0.90,
        strokeWidth: size.width * 0.025, color: AppTheme.primary, baseAngle: outerAngle,
        arcSweeps: [_deg(110), _deg(70), _deg(60)],
        gapSweeps: [_deg(20), _deg(20), _deg(80)], glowAlpha: 0.30);

    _drawSegmentedRing(canvas: canvas, center: center, radius: maxR * 0.64,
        strokeWidth: size.width * 0.020, color: AppTheme.secondary, baseAngle: middleAngle,
        arcSweeps: [_deg(140), _deg(80)],
        gapSweeps: [_deg(60), _deg(80)], glowAlpha: 0.22);

    _drawSegmentedRing(canvas: canvas, center: center, radius: maxR * 0.40,
        strokeWidth: size.width * 0.030, color: AppTheme.primary, baseAngle: innerAngle,
        arcSweeps: [_deg(200)], gapSweeps: [_deg(160)], glowAlpha: 0.18);

    // Scan line
    final innerR = maxR * 0.40;
    final scanY = (center.dy - innerR) + innerR * 2 * scanProgress;
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: innerR * 0.85)));
    canvas.drawRect(
      Rect.fromLTWH(center.dx - innerR, scanY - size.height * 0.07, innerR * 2, size.height * 0.14),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [AppTheme.primary.withValues(alpha: 0.0), AppTheme.primary.withValues(alpha: 0.35), AppTheme.primary.withValues(alpha: 0.0)],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromLTWH(center.dx - innerR, scanY - size.height * 0.07, innerR * 2, size.height * 0.14)),
    );
    canvas.drawLine(Offset(center.dx - innerR * 0.70, scanY), Offset(center.dx + innerR * 0.70, scanY),
        Paint()..color = AppTheme.primary.withValues(alpha: 0.90)..style = PaintingStyle.stroke..strokeWidth = size.width * 0.012..strokeCap = StrokeCap.round);
    canvas.restore();

    // Center dot
    canvas.drawCircle(center, size.width * 0.022, Paint()..color = AppTheme.primary);
    final halo = (0.5 + 0.5 * math.sin(innerAngle)).clamp(0.0, 1.0);
    canvas.drawCircle(center, size.width * 0.055,
        Paint()..color = AppTheme.primary.withValues(alpha: halo * 0.25)..style = PaintingStyle.stroke..strokeWidth = size.width * 0.010);
  }

  @override
  bool shouldRepaint(_ScanRingsPainter old) =>
      old.outerAngle != outerAngle || old.middleAngle != middleAngle ||
      old.innerAngle != innerAngle || old.scanProgress != scanProgress;
}
