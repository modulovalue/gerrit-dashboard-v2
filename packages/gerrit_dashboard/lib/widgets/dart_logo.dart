import 'package:flutter/material.dart';

/// Stylised approximation of the Dart language logo: two leaning
/// parallelograms in the official Dart brand blues. Custom-painted so
/// the dashboard doesn't take on a `flutter_svg` dependency for one
/// tiny mark.
class DartLogo extends StatelessWidget {
  final double size;
  const DartLogo({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const CustomPaint(painter: _DartLogoPainter()),
    );
  }
}

class _DartLogoPainter extends CustomPainter {
  // Dart brand colours.
  static const _accent = Color(0xFF13B9FD); // light cyan-blue
  static const _primary = Color(0xFF0175C2); // deep Dart blue

  const _DartLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Background blade: leaning light-blue quadrilateral.
    final blade = Path()
      ..moveTo(0.08 * w, 0.18 * h)
      ..lineTo(0.58 * w, 0.04 * h)
      ..lineTo(0.74 * w, 0.58 * h)
      ..lineTo(0.24 * w, 0.72 * h)
      ..close();
    canvas.drawPath(blade, Paint()..color = _accent);

    // Foreground body: deep-blue overlapping quadrilateral.
    final body = Path()
      ..moveTo(0.36 * w, 0.42 * h)
      ..lineTo(0.86 * w, 0.30 * h)
      ..lineTo(0.96 * w, 0.86 * h)
      ..lineTo(0.46 * w, 0.96 * h)
      ..close();
    canvas.drawPath(body, Paint()..color = _primary);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
