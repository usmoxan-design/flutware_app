import 'package:flutter/material.dart';

class BlockShapePainter extends CustomPainter {
  final Color color;
  final bool isHat;
  final bool isMouth;

  const BlockShapePainter({
    required this.color,
    this.isHat = false,
    this.isMouth = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(8),
    );

    final fill = Paint()..color = color;
    final border = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawRRect(rect, fill);
    canvas.drawRRect(rect, border);

    if (isHat) {
      final hat = Paint()..color = Colors.white.withValues(alpha: 0.14);
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 8), hat);
    }

    if (isMouth) {
      final slot = Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(8, size.height * 0.35),
        Offset(size.width - 8, size.height * 0.35),
        slot,
      );
      canvas.drawLine(
        Offset(8, size.height * 0.72),
        Offset(size.width - 8, size.height * 0.72),
        slot,
      );
    }
  }

  @override
  bool shouldRepaint(covariant BlockShapePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.isHat != isHat ||
        oldDelegate.isMouth != isMouth;
  }
}
