import 'package:flutter/material.dart';

import '../theme/stockgo_theme.dart';
import 'stockgo_inventory_scene.dart';

class StockGoShowcase extends StatelessWidget {
  const StockGoShowcase({
    super.key,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.action = 'Ver catálogo',
  });
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final String action;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth > 500;
      return Container(
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(
            colors: [StockGoTheme.navy, StockGoTheme.teal],
          ),
          boxShadow: [
            BoxShadow(
              color: StockGoTheme.blue.withValues(alpha: .16),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'STOCKGO · TU NEGOCIO',
                    style: TextStyle(
                      color: Color(0xFFBAE6FD),
                      fontSize: 11,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: wide ? 30 : 23,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFFDDF3FF),
                      height: 1.5,
                    ),
                  ),
                  if (onTap != null) ...[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: StockGoTheme.teal,
                      ),
                      onPressed: onTap,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: Text(action),
                    ),
                  ],
                ],
              ),
            ),
            if (wide) const Expanded(child: StockGoInventoryScene(height: 180)),
          ],
        ),
      );
    },
  );
}
