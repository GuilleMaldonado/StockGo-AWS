import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/stockgo_theme.dart';

/// Ilustración vectorial original: cajas, lubricante y control de existencias.
class StockGoInventoryScene extends StatelessWidget {
  const StockGoInventoryScene({super.key, this.height = 190});
  final double height;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      height: height,
      width: double.infinity,
      child: RepaintBoundary(child: CustomPaint(painter: _InventoryPainter())),
    ),
  );
}

class _InventoryPainter extends CustomPainter {
  void _face(Canvas canvas, List<Offset> points, Color color) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _box(
    Canvas c,
    double x,
    double y,
    double width,
    double height,
    Color color,
  ) {
    final depth = width * .33;
    _face(c, [
      Offset(x, y),
      Offset(x + width, y - 20),
      Offset(x + width + depth, y),
      Offset(x + depth, y + 20),
    ], Color.lerp(color, Colors.white, .4)!);
    _face(c, [
      Offset(x, y),
      Offset(x + depth, y + 20),
      Offset(x + depth, y + height + 20),
      Offset(x, y + height),
    ], Color.lerp(color, StockGoTheme.navy, .2)!);
    _face(c, [
      Offset(x + depth, y + 20),
      Offset(x + width + depth, y),
      Offset(x + width + depth, y + height),
      Offset(x + depth, y + height + 20),
    ], color);
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x + depth + 12, y + 35, width * .5, 18),
        const Radius.circular(4),
      ),
      Paint()..color = Colors.white.withValues(alpha: .9),
    );
    for (var i = 0; i < 7; i++) {
      c.drawRect(
        Rect.fromLTWH(x + depth + 17 + i * 4, y + 39, i.isEven ? 2 : 1, 10),
        Paint()..color = StockGoTheme.navy,
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / 360, size.height / 220);
    canvas.save();
    canvas.translate(
      (size.width - 360 * scale) / 2,
      (size.height - 220 * scale) / 2,
    );
    canvas.scale(scale);
    final shadow = Paint()
      ..color = StockGoTheme.navy.withValues(alpha: .18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawOval(const Rect.fromLTWH(32, 170, 290, 32), shadow);
    _face(canvas, [
      const Offset(22, 167),
      const Offset(192, 125),
      const Offset(337, 170),
      const Offset(173, 213),
    ], const Color(0xFFCEDBFF));
    _face(canvas, [
      const Offset(22, 167),
      const Offset(173, 213),
      const Offset(173, 220),
      const Offset(22, 174),
    ], const Color(0xFF99B0E7));
    _face(canvas, [
      const Offset(173, 213),
      const Offset(337, 170),
      const Offset(337, 177),
      const Offset(173, 220),
    ], const Color(0xFF688ED4));
    _box(canvas, 68, 93, 77, 76, StockGoTheme.blue);
    _box(canvas, 127, 48, 80, 80, StockGoTheme.teal);
    _box(canvas, 180, 117, 54, 53, StockGoTheme.yellow);
    // Bidón de aceite con asa y etiqueta.
    final bottle = Path()
      ..moveTo(260, 93)
      ..lineTo(277, 93)
      ..lineTo(277, 108)
      ..lineTo(297, 120)
      ..lineTo(297, 174)
      ..quadraticBezierTo(297, 183, 287, 183)
      ..lineTo(251, 183)
      ..quadraticBezierTo(242, 183, 242, 174)
      ..lineTo(242, 121)
      ..lineTo(252, 111)
      ..lineTo(260, 111)
      ..close();
    canvas.drawPath(
      bottle,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF20B69B), Color(0xFF08776E)],
        ).createShader(const Rect.fromLTWH(242, 93, 55, 90)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(258, 87, 21, 9),
        const Radius.circular(3),
      ),
      Paint()..color = StockGoTheme.navy,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(269, 116, 18, 18),
        const Radius.circular(5),
      ),
      Paint()..color = const Color(0xFFCEE5EE),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(252, 142, 35, 22),
        const Radius.circular(5),
      ),
      Paint()..color = Colors.white,
    );
    final drop = Path()
      ..moveTo(270, 146)
      ..quadraticBezierTo(257, 159, 270, 160)
      ..quadraticBezierTo(282, 159, 270, 146);
    canvas.drawPath(drop, Paint()..color = StockGoTheme.yellow);
    // Tarjeta flotante de stock.
    final card = RRect.fromRectAndRadius(
      const Rect.fromLTWH(235, 16, 102, 63),
      const Radius.circular(14),
    );
    canvas.drawRRect(
      card.shift(const Offset(0, 7)),
      Paint()
        ..color = StockGoTheme.navy.withValues(alpha: .12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawRRect(card, Paint()..color = Colors.white);
    canvas.drawCircle(
      const Offset(255, 36),
      9,
      Paint()..color = StockGoTheme.green,
    );
    canvas.drawPath(
      Path()
        ..moveTo(251, 36)
        ..lineTo(254, 39)
        ..lineTo(259, 33),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    for (var i = 0; i < 3; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(274 + i * 15, 52 - i * 8, 9, 15 + i * 8),
          const Radius.circular(3),
        ),
        Paint()
          ..color = [
            StockGoTheme.teal,
            StockGoTheme.blue,
            StockGoTheme.yellow,
          ][i],
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(273, 28, 46, 5),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFFDAE5F6),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _InventoryPainter oldDelegate) => false;
}
