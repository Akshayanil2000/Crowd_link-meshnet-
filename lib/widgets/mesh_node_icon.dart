import 'package:flutter/material.dart';

class MeshNodeIcon extends StatelessWidget {
  const MeshNodeIcon({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 80,
      child: Opacity(
        opacity: 0.5,
        child: CustomPaint(
          painter: MeshNodeIconPainter(),
          size: const Size(64, 64),
        ),
      ),
    );
  }
}

class MeshNodeIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    double scale = size.width / 64;
    canvas.scale(scale, scale);

    final paint = Paint()
      ..color = const Color(0xFF4A4A4A)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Center node
    canvas.drawCircle(const Offset(32, 32), 6, paint);

    // Top left node
    canvas.drawCircle(const Offset(15, 18), 4, paint);
    canvas.drawLine(const Offset(18.5, 20.5), const Offset(27, 28), paint);

    // Top right node
    canvas.drawCircle(const Offset(49, 18), 4, paint);
    canvas.drawLine(const Offset(45.5, 20.5), const Offset(37, 28), paint);

    // Bottom node
    canvas.drawCircle(const Offset(32, 52), 4, paint);
    canvas.drawLine(const Offset(32, 38), const Offset(32, 48), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
