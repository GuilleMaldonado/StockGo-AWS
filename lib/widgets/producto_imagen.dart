import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/stockgo_theme.dart';

class ProductoImagen extends StatelessWidget {
  const ProductoImagen({
    super.key,
    this.imagen,
    this.width,
    this.height = 160,
    this.radius = 16,
  });
  final Uint8List? imagen;
  final double? width;
  final double height;
  final double radius;
  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: width,
      height: height,
      color: const Color(0xFFEDF4F2),
      child: const Center(
        child: Icon(
          Icons.inventory_2_outlined,
          size: 36,
          color: StockGoTheme.teal,
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: imagen == null
          ? placeholder
          : Image.memory(
              imagen!,
              width: width,
              height: height,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (context, error, stack) => placeholder,
            ),
    );
  }
}

class EstadoProducto extends StatelessWidget {
  const EstadoProducto({super.key, required this.activo});
  final bool activo;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: activo ? const Color(0xFFE6F5EE) : const Color(0xFFF1F2F5),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      activo ? 'Activo' : 'Inactivo',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: activo ? StockGoTheme.teal : StockGoTheme.muted,
      ),
    ),
  );
}
