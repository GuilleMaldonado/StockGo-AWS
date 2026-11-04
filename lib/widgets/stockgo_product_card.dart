import 'package:flutter/material.dart';

import '../models/producto.dart';
import '../theme/stockgo_theme.dart';
import 'producto_imagen.dart';

IconData iconoCategoria(String? categoria) => switch (categoria) {
  'Lubricante' => Icons.oil_barrel_rounded,
  'Filtro' => Icons.filter_alt_rounded,
  'Aditivo' => Icons.water_drop_rounded,
  'Accesorio' => Icons.car_repair_rounded,
  'Repuesto' => Icons.settings_rounded,
  _ => Icons.grid_view_rounded,
};
String pluralCategoria(String categoria) => switch (categoria) {
  'Repuesto' => 'Repuestos',
  'Lubricante' => 'Lubricantes',
  'Filtro' => 'Filtros',
  'Aditivo' => 'Aditivos',
  'Accesorio' => 'Accesorios',
  _ => categoria,
};

class StockGoProductCard extends StatelessWidget {
  const StockGoProductCard({
    super.key,
    required this.producto,
    required this.onTap,
  });
  final Producto producto;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              if (producto.imagen != null)
                ProductoImagen(
                  imagen: producto.imagen,
                  width: double.infinity,
                  height: 156,
                  radius: 0,
                )
              else
                Container(
                  height: 156,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFE0F4FF), Color(0xFFF5FBFF)],
                    ),
                  ),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .85),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: StockGoTheme.blue.withValues(alpha: .09),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        iconoCategoria(producto.categoria),
                        size: 52,
                        color: StockGoTheme.teal,
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .94),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    producto.activo ? 'Activo' : 'Inactivo',
                    style: TextStyle(
                      fontSize: 10,
                      color: producto.activo
                          ? StockGoTheme.green
                          : StockGoTheme.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  producto.categoria.toUpperCase(),
                  style: const TextStyle(
                    color: StockGoTheme.teal,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .8,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  producto.nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Código: ${producto.codigo}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: StockGoTheme.muted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Precio: ${producto.precio.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: StockGoTheme.teal,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Disponible: ${producto.cantidad}',
                  style: TextStyle(
                    color: producto.cantidad == 0
                        ? Theme.of(context).colorScheme.error
                        : StockGoTheme.muted,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
