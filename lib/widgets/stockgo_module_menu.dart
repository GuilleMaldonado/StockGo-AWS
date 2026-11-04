import 'package:flutter/material.dart';

import '../data/stockgo_store.dart';
import '../screens/productos_screen.dart';
import '../screens/ventas_screen.dart';
import '../screens/reportes_screen.dart';
import '../screens/equipo_screen.dart';
import '../screens/servidor_screen.dart';
import '../theme/stockgo_theme.dart';
import 'stockgo_design.dart';

enum StockGoModule { inicio, inventario, ventas, reportes, equipo, conexion }

class StockGoModuleMenu extends StatelessWidget {
  const StockGoModuleMenu({
    super.key,
    required this.store,
    required this.current,
    this.enabled = true,
  });
  final StockGoStore store;
  final StockGoModule current;
  final bool enabled;

  void open(BuildContext context, StockGoModule module) {
    if (!enabled) return;
    final usuario = store.usuario;
    if (usuario == null || current == module) return;
    if (module == StockGoModule.inicio) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    final Widget screen;
    switch (module) {
      case StockGoModule.inventario:
        screen = ProductosScreen(store: store);
      case StockGoModule.ventas:
        if (!usuario.puedeVender) return;
        screen = VentasScreen(store: store);
      case StockGoModule.reportes:
        if (!usuario.puedeVender) return;
        screen = ReportesScreen(store: store);
      case StockGoModule.equipo:
        if (!usuario.puedeAdministrar) return;
        screen = EquipoScreen(store: store);
      case StockGoModule.conexion:
        if (!usuario.puedeAdministrar) return;
        screen = ServidorScreen(store: store);
      case StockGoModule.inicio:
        return;
    }
    final route = MaterialPageRoute<void>(builder: (_) => screen);
    if (current == StockGoModule.inicio) {
      Navigator.of(context).push(route);
    } else {
      Navigator.of(context).pushReplacement(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = store.usuario;
    final items = <(StockGoModule, String, IconData, Color)>[
      (
        StockGoModule.inicio,
        'Inicio',
        Icons.space_dashboard_rounded,
        StockGoTheme.blue,
      ),
      (
        StockGoModule.inventario,
        'Inventario · Stock',
        Icons.inventory_2_rounded,
        StockGoTheme.teal,
      ),
      if (usuario?.puedeVender == true)
        (
          StockGoModule.ventas,
          'Ventas',
          Icons.point_of_sale_rounded,
          StockGoTheme.green,
        ),
      if (usuario?.puedeVender == true)
        (
          StockGoModule.reportes,
          'Historial y estadísticas',
          Icons.insights_rounded,
          StockGoTheme.blue,
        ),
      if (usuario?.puedeAdministrar == true) ...[
        (
          StockGoModule.equipo,
          'Vendedores y equipo',
          Icons.groups_rounded,
          StockGoTheme.blue,
        ),
        (
          StockGoModule.conexion,
          'Compartir inventario',
          Icons.hub_rounded,
          StockGoTheme.teal,
        ),
      ],
    ];
    return PopupMenuButton<StockGoModule>(
      enabled: enabled,
      tooltip: 'Abrir módulos',
      position: PopupMenuPosition.under,
      offset: const Offset(8, 10),
      elevation: 8,
      shadowColor: StockGoTheme.navy.withValues(alpha: .18),
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      constraints: const BoxConstraints(minWidth: 260, maxWidth: 300),
      icon: const StockGoIconBadge(
        icon: Icons.menu_rounded,
        size: 38,
        color: StockGoTheme.blue,
      ),
      onSelected: (module) => open(context, module),
      itemBuilder: (context) => [
        const PopupMenuItem(
          enabled: false,
          height: 38,
          child: Text(
            'MÓDULOS',
            style: TextStyle(
              color: StockGoTheme.muted,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              fontSize: 12,
            ),
          ),
        ),
        for (final item in items)
          PopupMenuItem(
            value: item.$1,
            height: 66,
            child: Row(
              children: [
                StockGoIconBadge(icon: item.$3, color: item.$4, size: 38),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.$2,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (item.$1 == current)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: StockGoTheme.teal,
                    size: 18,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
