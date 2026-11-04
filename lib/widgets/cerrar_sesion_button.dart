import 'package:flutter/material.dart';

import '../data/stockgo_store.dart';

class CerrarSesionButton extends StatelessWidget {
  const CerrarSesionButton({
    super.key,
    required this.store,
    this.enabled = true,
  });
  final StockGoStore store;
  final bool enabled;
  void _cerrar(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    store.cerrarSesion();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: MediaQuery.sizeOf(context).width < 600
        ? IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: enabled ? () => _cerrar(context) : null,
            icon: const Icon(Icons.logout_rounded),
          )
        : TextButton.icon(
            onPressed: !enabled ? null : () => _cerrar(context),
            icon: const Icon(Icons.logout, size: 19),
            label: const Text('Cerrar sesión'),
          ),
  );
}
