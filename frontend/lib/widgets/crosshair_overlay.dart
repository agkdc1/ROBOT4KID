import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/fcs_state.dart';

/// FCS crosshair overlay on the turret camera view.
/// Centered by default, movable in the middle 1/3 vertically.
class CrosshairOverlay extends StatelessWidget {
  const CrosshairOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final fcs = context.watch<FcsState>();

    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final centerX = constraints.maxWidth / 2;
          final centerY = constraints.maxHeight / 2;
          // Middle 1/3 of view vertically
          final maxOffsetPx = constraints.maxHeight / 6;
          final offsetPx = fcs.crosshairOffsetY * constraints.maxHeight;

          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onVerticalDragUpdate: fcs.fcsActive
                ? (details) {
                    final newOffset = fcs.crosshairOffsetY +
                        details.delta.dy / constraints.maxHeight;
                    fcs.updateCrosshair(newOffset);
                  }
                : null,
            child: IgnorePointer(
              child: CustomPaint(
                painter: _CrosshairPainter(
                  centerX: centerX,
                  centerY: centerY + offsetPx,
                  fcsActive: fcs.fcsActive,
                  barrelAngle: fcs.computedBarrelAngle,
                  maxOffsetPx: maxOffsetPx,
                  screenCenterY: centerY,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CrosshairPainter extends CustomPainter {
  final double centerX;
  final double centerY;
  final bool fcsActive;
  final double barrelAngle;
  final double maxOffsetPx;
  final double screenCenterY;

  _CrosshairPainter({
    required this.centerX,
    required this.centerY,
    required this.fcsActive,
    required this.barrelAngle,
    required this.maxOffsetPx,
    required this.screenCenterY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final color = fcsActive ? Colors.greenAccent : Colors.red;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final center = Offset(centerX, centerY);

    // Main crosshair
    const gap = 12.0;
    const lineLen = 20.0;

    // Horizontal lines
    canvas.drawLine(
      Offset(center.dx - gap - lineLen, center.dy),
      Offset(center.dx - gap, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx + gap, center.dy),
      Offset(center.dx + gap + lineLen, center.dy),
      paint,
    );

    // Vertical lines
    canvas.drawLine(
      Offset(center.dx, center.dy - gap - lineLen),
      Offset(center.dx, center.dy - gap),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy + gap),
      Offset(center.dx, center.dy + gap + lineLen),
      paint,
    );

    // Center dot
    final dotPaint = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 2.5, dotPaint);

    // Range marks (mil dots)
    final milPaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..strokeWidth = 1;
    for (int i = 1; i <= 3; i++) {
      final y = center.dy + i * 15.0;
      canvas.drawLine(
        Offset(center.dx - 6, y),
        Offset(center.dx + 6, y),
        milPaint,
      );
    }

    // Movement range indicator (middle 1/3 zone) when FCS active
    if (fcsActive) {
      final zonePaint = Paint()
        ..color = Colors.cyan.withValues(alpha: 0.15)
        ..style = PaintingStyle.fill;
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(centerX, screenCenterY),
          width: 40,
          height: maxOffsetPx * 2,
        ),
        zonePaint,
      );

      // Barrel angle text
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'FCS ${barrelAngle.toStringAsFixed(1)}°',
          style: TextStyle(
            color: Colors.greenAccent.withValues(alpha: 0.7),
            fontSize: 10,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(center.dx + gap + lineLen + 8, center.dy - 6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CrosshairPainter old) =>
      centerY != old.centerY ||
      fcsActive != old.fcsActive ||
      barrelAngle != old.barrelAngle;
}
