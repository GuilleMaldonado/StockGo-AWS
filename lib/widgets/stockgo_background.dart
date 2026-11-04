import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Fondo vectorial ligero. Animación de entrada finita y movimiento reducido.
class StockGoBackground extends StatelessWidget {
  const StockGoBackground({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 1400),
    curve: Curves.easeOutCubic,
    child: child,
    builder: (context, progress, content) => Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(painter: _FondoPainter(progress)),
          ),
        ),
        Positioned.fill(child: content!),
      ],
    ),
  );
}

class _FondoPainter extends CustomPainter {
  const _FondoPainter(this.progress);
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final area = Offset.zero & size;
    canvas.drawRect(
      area,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE9F7FF), Color(0xFFF8FCFF), Color(0xFFF0F8FC)],
        ).createShader(area),
    );
    final paint = Paint();
    for (final orb in [
      (Offset(size.width * .92, size.height * .12), const Color(0xFF7DD3FC)),
      (Offset(size.width * .05, size.height * .88), const Color(0xFFBAE6FD)),
    ]) {
      final radius = math.min(size.width, size.height) * (.35 + progress * .08);
      paint.shader = RadialGradient(
        colors: [orb.$2.withValues(alpha: .32), orb.$2.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: orb.$1, radius: radius));
      canvas.drawCircle(orb.$1, radius, paint);
    }
    paint.shader = null;
    paint.color = const Color(0xFF137C66).withValues(alpha: .06 * progress);
    for (double x = 18; x < size.width; x += 36) {
      for (double y = 18; y < size.height; y += 36) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
    paint.color = const Color(0xFF2563B7).withValues(alpha: .035 * progress);
    paint.strokeWidth = 1;
    for (double x = -size.height; x < size.width; x += 110) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_FondoPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class StockGoPageTransition extends PageTransitionsBuilder {
  const StockGoPageTransition();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, .035),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
