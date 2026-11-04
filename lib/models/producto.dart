import 'dart:typed_data';

import 'ficha_producto.dart';

class Producto {
  const Producto({
    this.id,
    required this.nombre,
    required this.codigo,
    required this.precio,
    required this.cantidad,
    this.activo = true,
    this.imagen,
    this.categoria = 'Repuesto',
    this.ficha = const {},
    this.costo = 0,
    this.stockMinimo = 0,
  });

  final int? id;
  final String nombre;
  final String codigo;
  final double precio;
  final int cantidad;
  final bool activo;
  final Uint8List? imagen;
  final String categoria;
  final Map<String, String> ficha;
  final double costo;
  final int stockMinimo;

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'nombre': nombre,
    'codigo': codigo,
    'precio': precio,
    'cantidad': cantidad,
    'activo': activo ? 1 : 0,
    'imagen': imagen,
    'categoria': categoria,
    'costo': costo,
    'stockMinimo': stockMinimo,
    for (final campo in camposProducto)
      campo.clave: ficha[campo.clave]?.trim() ?? '',
  };

  factory Producto.fromMap(Map<String, Object?> map) => Producto(
    id: map['id'] as int?,
    categoria: map['categoria'] as String? ?? 'Repuesto',
    costo: (map['costo'] as num? ?? 0).toDouble(),
    stockMinimo: map['stockMinimo'] as int? ?? 0,
    ficha: {
      for (final campo in camposProducto)
        campo.clave: map[campo.clave] as String? ?? '',
    },
    nombre: map['nombre'] as String,
    codigo: map['codigo'] as String,
    precio: (map['precio'] as num).toDouble(),
    cantidad: map['cantidad'] as int,
    activo: map['activo'] == 1,
    imagen: map['imagen'] == null
        ? null
        : Uint8List.fromList((map['imagen'] as List).cast<int>()),
  );
}
