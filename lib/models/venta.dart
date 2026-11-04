class LineaVenta {
  const LineaVenta({
    required this.productoId,
    required this.cantidad,
    this.precioEsperadoCentavos,
  });
  final int productoId;
  final int cantidad;
  final int? precioEsperadoCentavos;
  Map<String, Object?> toMap() => {
    'productoId': productoId,
    'cantidad': cantidad,
    if (precioEsperadoCentavos != null)
      'precioEsperadoCentavos': precioEsperadoCentavos,
  };
}

class Venta {
  const Venta({
    required this.id,
    required this.fecha,
    required this.vendedor,
    required this.totalCentavos,
    required this.detalles,
    this.codigoVendedor = '',
  });
  final int id;
  final String fecha;
  final String vendedor;
  final String codigoVendedor;
  final int totalCentavos;
  final List<Map<String, Object?>> detalles;
  Map<String, Object?> toMap() => {
    'id': id,
    'fecha': fecha,
    'vendedor': vendedor,
    'codigoVendedor': codigoVendedor,
    'totalCentavos': totalCentavos,
    'detalles': detalles,
  };
  factory Venta.fromMap(Map<String, Object?> map) => Venta(
    id: map['id'] as int,
    fecha: map['fecha'] as String,
    vendedor: map['vendedor'] as String,
    codigoVendedor: map['codigoVendedor'] as String? ?? '',
    totalCentavos: map['totalCentavos'] as int,
    detalles: (map['detalles'] as List? ?? [])
        .map((d) => (d as Map).cast<String, Object?>())
        .toList(),
  );
}
