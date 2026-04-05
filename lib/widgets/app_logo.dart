import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/theme.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool showGlow;

  const AppLogo({super.key, this.size = 80, this.showGlow = true});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _NeuralLeafPainter(showGlow: showGlow)),
    );
  }
}

class _NeuralLeafPainter extends CustomPainter {
  final bool showGlow;
  const _NeuralLeafPainter({required this.showGlow});

  List<Offset> _hexVertices(Offset center, double radius) {
    return List.generate(6, (i) {
      final angle = (math.pi / 3) * i - math.pi / 2;
      return Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
    });
  }

  Path _hexPath(Offset center, double radius) {
    final v = _hexVertices(center, radius);
    return Path()
      ..moveTo(v[0].dx, v[0].dy)
      ..lineTo(v[1].dx, v[1].dy)
      ..lineTo(v[2].dx, v[2].dy)
      ..lineTo(v[3].dx, v[3].dy)
      ..lineTo(v[4].dx, v[4].dy)
      ..lineTo(v[5].dx, v[5].dy)
      ..close();
  }

  Path _leafPath(Offset center, double leafHeight, double leafWidth) {
    final tip = Offset(center.dx, center.dy - leafHeight * 0.52);
    final belly = Offset(center.dx, center.dy + leafHeight * 0.28);
    final leftCtrl1 = Offset(center.dx - leafWidth * 0.08, tip.dy + leafHeight * 0.12);
    final leftCtrl2 = Offset(center.dx - leafWidth * 0.50, belly.dy - leafHeight * 0.15);
    final rightCtrl1 = Offset(center.dx + leafWidth * 0.50, belly.dy - leafHeight * 0.15);
    final rightCtrl2 = Offset(center.dx + leafWidth * 0.08, tip.dy + leafHeight * 0.12);
    return Path()
      ..moveTo(tip.dx, tip.dy)
      ..cubicTo(leftCtrl1.dx, leftCtrl1.dy, leftCtrl2.dx, leftCtrl2.dy, belly.dx, belly.dy)
      ..cubicTo(rightCtrl1.dx, rightCtrl1.dy, rightCtrl2.dx, rightCtrl2.dy, tip.dx, tip.dy)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final hexRadius = size.width * 0.44;

    canvas.drawPath(_hexPath(center, hexRadius),
        Paint()..color = AppTheme.card..style = PaintingStyle.fill);

    canvas.drawPath(_hexPath(center, hexRadius * 0.82),
        Paint()..color = AppTheme.primary.withValues(alpha: 0.07)..style = PaintingStyle.fill);

    canvas.drawPath(_hexPath(center, hexRadius),
        Paint()
          ..color = AppTheme.primary.withValues(alpha: 0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.018);

    final leafH = size.height * 0.54;
    final leafW = size.width * 0.32;
    final leafCenter = Offset(center.dx, center.dy + size.height * 0.03);

    if (showGlow) {
      canvas.drawPath(
        _leafPath(leafCenter, leafH * 1.05, leafW * 1.15),
        Paint()
          ..color = AppTheme.primary.withValues(alpha: 0.28)
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    canvas.drawPath(_leafPath(leafCenter, leafH, leafW),
        Paint()..color = AppTheme.primary..style = PaintingStyle.fill);

    canvas.drawLine(
      Offset(leafCenter.dx, leafCenter.dy - leafH * 0.52),
      Offset(leafCenter.dx, leafCenter.dy + leafH * 0.28),
      Paint()
        ..color = AppTheme.background.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.012
        ..strokeCap = StrokeCap.round,
    );

    final innerHexRadius = hexRadius * 0.82;
    final traceAngle = (math.pi / 3) * 1 - math.pi / 2;
    final traceOrigin = Offset(
      center.dx + innerHexRadius * math.cos(traceAngle),
      center.dy + innerHexRadius * math.sin(traceAngle),
    );
    final traceEndH = Offset(traceOrigin.dx + size.width * 0.10, traceOrigin.dy);
    final traceEndV = Offset(traceEndH.dx, traceEndH.dy - size.height * 0.06);

    canvas.drawPath(
      Path()
        ..moveTo(traceOrigin.dx, traceOrigin.dy)
        ..lineTo(traceEndH.dx, traceEndH.dy)
        ..lineTo(traceEndV.dx, traceEndV.dy),
      Paint()
        ..color = AppTheme.secondary.withValues(alpha: 0.70)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.014
        ..strokeCap = StrokeCap.square,
    );

    final nodePaint = Paint()..color = AppTheme.secondary..style = PaintingStyle.fill;
    canvas.drawCircle(traceOrigin, size.width * 0.026, nodePaint);
    final ts = size.width * 0.030;
    canvas.drawRect(Rect.fromCenter(center: traceEndV, width: ts, height: ts), nodePaint);
  }

  @override
  bool shouldRepaint(_NeuralLeafPainter old) => old.showGlow != showGlow;
}
