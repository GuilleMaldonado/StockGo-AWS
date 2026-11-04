import 'package:flutter/material.dart';

import '../theme/stockgo_theme.dart';

/// Original curved bands inspired by the supplied login reference.
class StockGoLoginDecoration extends CustomPainter {
  const StockGoLoginDecoration();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final soft = Paint()..color = const Color(0xFFBAE6FD);
    final blue = Paint()..color = StockGoTheme.blue;
    canvas.drawPath(
      Path()
        ..moveTo(w * .48, 0)
        ..lineTo(w, 0)
        ..lineTo(w, 88)
        ..lineTo(w * .69, 88)
        ..quadraticBezierTo(w * .39, 88, w * .48, 0)
        ..close(),
      soft,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * .53, 0)
        ..lineTo(w, 0)
        ..lineTo(w, 77)
        ..lineTo(w * .72, 77)
        ..quadraticBezierTo(w * .44, 77, w * .53, 0)
        ..close(),
      blue,
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, h - 60)
        ..lineTo(w, h - 14)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close(),
      soft,
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, h - 45)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close(),
      blue,
    );
  }

  @override
  bool shouldRepaint(StockGoLoginDecoration oldDelegate) => false;
}
