import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/theme.dart';

class MacroRing extends StatefulWidget {
  final String label;
  final double current;
  final double target;
  final Color color;
  final String unit;
  final double radius;

  const MacroRing({
    super.key,
    required this.label,
    required this.current,
    required this.target,
    required this.color,
    this.unit = 'g',
    this.radius = 36,
  });

  @override
  State<MacroRing> createState() => _MacroRingState();
}

class _MacroRingState extends State<MacroRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(MacroRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.current != widget.current) {
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
    final pct = widget.target > 0
        ? (widget.current / widget.target).clamp(0.0, 1.0)
        : 0.0;

    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: widget.radius * 2,
              height: widget.radius * 2,
              child: CustomPaint(
                painter: _MacroRingPainter(
                  progress: pct * _animation.value,
                  color: widget.color,
                  strokeWidth: 5,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(widget.current * _animation.value).toInt()}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: widget.color,
                        ),
                      ),
                      Text(
                        widget.unit,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.onCard,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MacroRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _MacroRingPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - strokeWidth;

    // Background
    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress
    if (progress > 0) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      final sweepAngle = 2 * math.pi * progress;

      // Glow
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 4
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, glowPaint);

      final progressPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, progressPaint);
    }
  }

  @override
  bool shouldRepaint(_MacroRingPainter oldDelegate) =>
      progress != oldDelegate.progress || color != oldDelegate.color;
}
