import 'package:flutter/material.dart';
import 'dart:math';

/// Virtual joystick widget with visual feedback.
class JoystickWidget extends StatefulWidget {
  final String label;
  final double size;
  final ValueChanged<double>? onXChanged;
  final ValueChanged<double>? onYChanged;
  final void Function(double x, double y)? onChanged;

  const JoystickWidget({
    super.key,
    this.label = '',
    this.size = 150,
    this.onXChanged,
    this.onYChanged,
    this.onChanged,
  });

  @override
  State<JoystickWidget> createState() => _JoystickWidgetState();
}

class _JoystickWidgetState extends State<JoystickWidget> {
  double _dx = 0;
  double _dy = 0;

  void _updatePosition(Offset localPosition) {
    final center = widget.size / 2;
    final maxRadius = center - 20;

    double dx = (localPosition.dx - center) / maxRadius;
    double dy = -(localPosition.dy - center) / maxRadius; // Invert Y

    // Clamp to unit circle
    final magnitude = sqrt(dx * dx + dy * dy);
    if (magnitude > 1.0) {
      dx /= magnitude;
      dy /= magnitude;
    }

    // Dead zone
    if (magnitude < 0.1) {
      dx = 0;
      dy = 0;
    }

    setState(() {
      _dx = dx;
      _dy = dy;
    });

    widget.onChanged?.call(dx, dy);
    widget.onXChanged?.call(dx);
    widget.onYChanged?.call(dy);
  }

  void _resetPosition() {
    setState(() {
      _dx = 0;
      _dy = 0;
    });
    widget.onChanged?.call(0, 0);
    widget.onXChanged?.call(0);
    widget.onYChanged?.call(0);
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.size / 2;
    final knobRadius = 25.0;
    final maxRadius = center - 20;

    return GestureDetector(
      onPanUpdate: (details) => _updatePosition(details.localPosition),
      onPanEnd: (_) => _resetPosition(),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _JoystickPainter(
            dx: _dx,
            dy: _dy,
            knobRadius: knobRadius,
            maxRadius: maxRadius,
            label: widget.label,
          ),
        ),
      ),
    );
  }
}

class _JoystickPainter extends CustomPainter {
  final double dx, dy;
  final double knobRadius;
  final double maxRadius;
  final String label;

  _JoystickPainter({
    required this.dx,
    required this.dy,
    required this.knobRadius,
    required this.maxRadius,
    required this.label,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Background circle
    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, maxRadius + knobRadius, bgPaint);

    // Border
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, maxRadius + knobRadius, borderPaint);

    // Crosshair
    final crossPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(center.dx - maxRadius, center.dy),
      Offset(center.dx + maxRadius, center.dy),
      crossPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - maxRadius),
      Offset(center.dx, center.dy + maxRadius),
      crossPaint,
    );

    // Knob
    final knobCenter = Offset(
      center.dx + dx * maxRadius,
      center.dy - dy * maxRadius, // Invert Y for screen coords
    );
    final knobPaint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(knobCenter, knobRadius, knobPaint);

    final knobBorder = Paint()
      ..color = Colors.lightBlueAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(knobCenter, knobRadius, knobBorder);

    // Label
    if (label.isNotEmpty) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(center.dx - textPainter.width / 2, size.height - 18),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _JoystickPainter oldDelegate) =>
      dx != oldDelegate.dx || dy != oldDelegate.dy;
}
