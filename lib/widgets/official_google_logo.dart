import 'package:flutter/material.dart';

/// Official 4-color Google "G" Logo rendered using vector Canvas paths.
class OfficialGoogleLogo extends StatelessWidget {
  final double size;
  const OfficialGoogleLogo({super.key, this.size = 18.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / 24.0;
    canvas.scale(scale, scale);

    final Paint paint = Paint()..style = PaintingStyle.fill;

    // Red: Top arc (#EA4335)
    paint.color = const Color(0xFFEA4335);
    final Path redPath = Path()
      ..moveTo(12, 4.75)
      ..cubicTo(13.77, 4.75, 15.35, 5.36, 16.6, 6.55)
      ..lineTo(20.02, 3.13)
      ..cubicTo(17.95, 1.19, 15.24, 0, 12, 0)
      ..cubicTo(7.31, 0, 3.26, 2.7, 1.29, 6.63)
      ..lineTo(5.28, 9.76)
      ..cubicTo(6.23, 6.91, 8.88, 4.75, 12, 4.75)
      ..close();
    canvas.drawPath(redPath, paint);

    // Blue: Right bar and upper right arc (#4285F4)
    paint.color = const Color(0xFF4285F4);
    final Path bluePath = Path()
      ..moveTo(23.745, 12.27)
      ..cubicTo(23.745, 11.57, 23.685, 10.87, 23.555, 10.2)
      ..lineTo(12, 10.2)
      ..lineTo(12, 14.71)
      ..lineTo(18.6, 14.71)
      ..cubicTo(18.31, 16.23, 17.46, 17.53, 16.2, 18.39)
      ..lineTo(20.08, 21.44)
      ..cubicTo(22.35, 19.35, 23.745, 16.27, 23.745, 12.27)
      ..close();
    canvas.drawPath(bluePath, paint);

    // Yellow: Left arc (#FBBC05)
    paint.color = const Color(0xFFFBBC05);
    final Path yellowPath = Path()
      ..moveTo(5.28, 14.24)
      ..cubicTo(5.03, 13.52, 4.9, 12.75, 4.9, 12)
      ..cubicTo(4.9, 11.25, 5.03, 10.48, 5.28, 9.76)
      ..lineTo(1.29, 6.63)
      ..cubicTo(0.47, 8.24, 0, 10.06, 0, 12)
      ..cubicTo(0, 13.94, 0.47, 15.76, 1.29, 17.37)
      ..lineTo(5.28, 14.24)
      ..close();
    canvas.drawPath(yellowPath, paint);

    // Green: Bottom arc (#34A853)
    paint.color = const Color(0xFF34A853);
    final Path greenPath = Path()
      ..moveTo(12, 24)
      ..cubicTo(15.24, 24, 17.95, 22.92, 19.93, 21.09)
      ..lineTo(16.05, 18.04)
      ..cubicTo(14.97, 18.76, 13.6, 19.2, 12, 19.2)
      ..cubicTo(8.88, 19.2, 6.23, 17.09, 5.28, 14.24)
      ..lineTo(1.29, 17.37)
      ..cubicTo(3.26, 21.3, 7.31, 24, 12, 24)
      ..close();
    canvas.drawPath(greenPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
