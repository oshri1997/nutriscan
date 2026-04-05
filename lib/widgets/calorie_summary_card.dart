import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/theme.dart';

class CalorieSummaryCard extends StatefulWidget {
  final double calories, calorieTarget;
  final double protein, proteinTarget;
  final double carbs, carbTarget;
  final double fat, fatTarget;

  const CalorieSummaryCard({
    super.key,
    required this.calories,
    required this.calorieTarget,
    required this.protein,
    required this.proteinTarget,
    required this.carbs,
    required this.carbTarget,
    required this.fat,
    required this.fatTarget,
  });

  @override
  State<CalorieSummaryCard> createState() => _CalorieSummaryCardState();
}

class _CalorieSummaryCardState extends State<CalorieSummaryCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(CalorieSummaryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.calories != widget.calories) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining =
        (widget.calorieTarget - widget.calories).clamp(0.0, widget.calorieTarget);
    final pct = widget.calorieTarget > 0
        ? (widget.calories / widget.calorieTarget).clamp(0.0, 1.0)
        : 0.0;

    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) {
        final animPct = pct * _animation.value;
        final animRemaining = remaining + (widget.calorieTarget - remaining) * (1 - _animation.value);

        return Column(
          children: [
            // Calorie Ring
            SizedBox(
              width: 160,
              height: 160,
              child: CustomPaint(
                painter: _CalorieRingPainter(
                  progress: animPct,
                  glowIntensity: _animation.value,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${animRemaining.toInt()}',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.onBackground,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'remaining',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.onCard,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.calories.toInt()} / ${widget.calorieTarget.toInt()} kcal',
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.onCard,
              ),
            ),
            const SizedBox(height: 16),
            // Macro pills
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _MacroPill(
                  label: 'Protein',
                  current: widget.protein * _animation.value,
                  target: widget.proteinTarget,
                  color: AppTheme.proteinColor,
                ),
                _MacroPill(
                  label: 'Carbs',
                  current: widget.carbs * _animation.value,
                  target: widget.carbTarget,
                  color: AppTheme.carbColor,
                ),
                _MacroPill(
                  label: 'Fat',
                  current: widget.fat * _animation.value,
                  target: widget.fatTarget,
                  color: AppTheme.fatColor,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _CalorieRingPainter extends CustomPainter {
  final double progress;
  final double glowIntensity;

  _CalorieRingPainter({
    required this.progress,
    required this.glowIntensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 14;
    const strokeWidth = 10.0;

    // Background ring
    final bgPaint = Paint()
      ..color = AppTheme.cardLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    if (progress > 0) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      final sweepAngle = 2 * math.pi * progress;

      // Glow
      if (glowIntensity > 0) {
        final glowPaint = Paint()
          ..color = AppTheme.primary.withValues(alpha: 0.2 * glowIntensity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth + 8
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, glowPaint);
      }

      // Gradient arc
      final gradient = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + sweepAngle,
        colors: const [AppTheme.primary, AppTheme.secondary],
        transform: const GradientRotation(-math.pi / 2),
      );
      final progressPaint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, progressPaint);
    }
  }

  @override
  bool shouldRepaint(_CalorieRingPainter oldDelegate) =>
      progress != oldDelegate.progress ||
      glowIntensity != oldDelegate.glowIntensity;
}

class _MacroPill extends StatelessWidget {
  final String label;
  final double current;
  final double target;
  final Color color;

  const _MacroPill({
    required this.label,
    required this.current,
    required this.target,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.onCard,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${current.toInt()}g',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 50,
            height: 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: color.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
