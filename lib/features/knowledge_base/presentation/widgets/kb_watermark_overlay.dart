import 'dart:math' as math;
import 'package:flutter/material.dart';

class KbWatermarkOverlay extends StatelessWidget {
  final String text;
  final Widget child;
  final double opacity;

  const KbWatermarkOverlay({
    super.key,
    required this.text,
    required this.child,
    this.opacity = 0.08,
  });

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return child;

    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _WatermarkPainter(
                text: text,
                opacity: opacity,
                isDark: Theme.of(context).brightness == Brightness.dark,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WatermarkPainter extends CustomPainter {
  final String text;
  final double opacity;
  final bool isDark;

  _WatermarkPainter({
    required this.text,
    required this.opacity,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final textStyle = TextStyle(
      color: (isDark ? Colors.white : Colors.black).withValues(alpha: opacity),
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
    );

    final textSpan = TextSpan(text: text, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final textWidth = textPainter.width;
    final textHeight = textPainter.height;

    final stepX = textWidth + 50.0;
    final stepY = textHeight + 60.0;

    canvas.save();
    for (double y = -50; y < size.height + 150; y += stepY) {
      for (double x = -50; x < size.width + 150; x += stepX) {
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(-math.pi / 7); // -25.7 deg
        textPainter.paint(canvas, Offset.zero);
        canvas.restore();
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WatermarkPainter oldDelegate) {
    return oldDelegate.text != text ||
        oldDelegate.opacity != opacity ||
        oldDelegate.isDark != isDark;
  }
}