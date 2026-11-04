import 'package:flutter/material.dart';

import '../data/stockgo_store.dart';
import '../theme/stockgo_theme.dart';
import 'stockgo_module_menu.dart';

class StockGoBottomNavigation extends StatelessWidget {
  const StockGoBottomNavigation({
    super.key,
    required this.store,
    required this.current,
    this.enabled = true,
  });
  final StockGoStore store;
  final StockGoModule current;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width >= 700) return const SizedBox.shrink();
    final usuario = store.usuario;
    final items = <(StockGoModule, String, IconData)>[
      (StockGoModule.inicio, 'Mi negocio', Icons.home_rounded),
      (StockGoModule.inventario, 'Catálogo', Icons.grid_view_rounded),
      if (usuario?.puedeVender == true)
        (StockGoModule.ventas, 'Vender', Icons.shopping_bag_rounded),
      if (usuario?.puedeAdministrar == true) ...[
        (StockGoModule.equipo, 'Equipo', Icons.groups_rounded),
        (StockGoModule.conexion, 'Conectar', Icons.wifi_rounded),
      ],
    ];
    final index = items.indexWhere((item) => item.$1 == current);
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: StockGoTheme.line)),
      ),
      child: NavigationBar(
        height: 74,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFD9F2FF),
        surfaceTintColor: Colors.transparent,
        selectedIndex: index < 0 ? 0 : index,
        labelBehavior: items.length > 3
            ? NavigationDestinationLabelBehavior.onlyShowSelected
            : NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: !enabled
            ? null
            : (value) => StockGoModuleMenu(
                store: store,
                current: current,
              ).open(context, items[value].$1),
        destinations: [
          for (final item in items)
            NavigationDestination(
              icon: Icon(item.$3, color: StockGoTheme.muted),
              selectedIcon: Icon(item.$3, color: StockGoTheme.teal),
              label: item.$2,
            ),
        ],
      ),
    );
  }
}
