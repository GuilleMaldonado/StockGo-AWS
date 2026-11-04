import 'package:flutter/material.dart';

import '../theme/stockgo_theme.dart';

class StockGoIconBadge extends StatelessWidget {
  const StockGoIconBadge({
    super.key,
    required this.icon,
    this.color = StockGoTheme.teal,
    this.size = 48,
    this.onDark = false,
  });
  final IconData icon;
  final Color color;
  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: onDark
            ? [const Color(0xFF1397B0), StockGoTheme.teal]
            : [color, Color.lerp(color, StockGoTheme.navy, .3)!],
      ),
      borderRadius: BorderRadius.circular(size * .3),
      border: Border.all(color: Colors.white.withValues(alpha: .32)),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: .24),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Icon(
      icon,
      size: size * .48,
      color: !onDark && color.computeLuminance() > .4
          ? StockGoTheme.navy
          : Colors.white,
    ),
  );
}

class StockGoModuleCard extends StatefulWidget {
  const StockGoModuleCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
    this.color = StockGoTheme.teal,
  });
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  @override
  State<StockGoModuleCard> createState() => _StockGoModuleCardState();
}

class _StockGoModuleCardState extends State<StockGoModuleCard> {
  bool _hovered = false;
  bool _focused = false;
  bool get _highlight => _hovered || _focused;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(24),
    child: InkWell(
      onTap: widget.onTap,
      onHover: (value) => setState(() => _hovered = value),
      onFocusChange: (value) => setState(() => _focused = value),
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
        constraints: const BoxConstraints(minHeight: 204),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _highlight ? widget.color.withValues(alpha: .04) : null,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _highlight ? widget.color : StockGoTheme.line,
            width: _highlight ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: StockGoTheme.navy.withValues(
                alpha: _highlight ? .08 : .035,
              ),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              children: [
                const SizedBox(width: 24),
                Expanded(
                  child: Center(
                    child: StockGoIconBadge(
                      icon: widget.icon,
                      color: widget.color,
                      size: 52,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 24,
                  color: widget.color,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              widget.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              widget.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: StockGoTheme.muted,
                height: 1.45,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class StockGoSectionHeading extends StatelessWidget {
  const StockGoSectionHeading({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      StockGoIconBadge(icon: icon),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(
                color: StockGoTheme.muted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
