import 'package:flutter/material.dart';

import '../data/stockgo_store.dart';
import '../screens/equipo_screen.dart';
import '../screens/productos_screen.dart';
import '../screens/servidor_screen.dart';
import '../theme/stockgo_theme.dart';

class NegocioPasos extends StatelessWidget {
  const NegocioPasos({super.key, required this.store});
  final StockGoStore store;
  @override
  Widget build(BuildContext context) {
    final pasos = <(String, String, IconData, Widget?)>[
      (
        '1 · Negocio creado',
        'Tu cuenta es el administrador de ${store.nombreNegocio}.',
        Icons.storefront_outlined,
        null,
      ),
      (
        '2 · Registra los productos',
        'Completa precio de compra, venta, existencias y lote del fabricante.',
        Icons.inventory_2_outlined,
        ProductosScreen(store: store),
      ),
      (
        '3 · Agrega vendedores',
        'Crea sus usuarios desde Vendedores y equipo. Cada cuenta pertenece a este negocio.',
        Icons.groups_outlined,
        EquipoScreen(store: store),
      ),
      (
        '4 · Activa el servidor',
        'En el dispositivo maestro, abre Compartir inventario e inicia el servidor.',
        Icons.hub_outlined,
        store.conectado ? null : ServidorScreen(store: store),
      ),
      (
        '5 · Comparte la invitación',
        'Copia el código desde Vendedores y equipo. El vendedor entra con ese código, su usuario y contraseña.',
        Icons.send_outlined,
        EquipoScreen(store: store),
      ),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pon tu negocio en marcha',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Un maestro comparte los datos; el equipo trabaja sobre ese mismo inventario.',
            ),
            const SizedBox(height: 18),
            for (final paso in pasos)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: StockGoTheme.teal.withValues(alpha: .1),
                    child: Icon(paso.$3, color: StockGoTheme.teal),
                  ),
                  title: Text(
                    paso.$1,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(paso.$2),
                  trailing: paso.$4 == null
                      ? const Icon(
                          Icons.check_circle_outline,
                          color: StockGoTheme.green,
                        )
                      : const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: paso.$4 == null
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => paso.$4!),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
