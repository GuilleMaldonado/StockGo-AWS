import 'venta.dart';

class RendimientoVenta {
  int ventas = 0;
  int unidades = 0;
  int ingreso = 0;
}

/// Calcula sobre los precios y costos guardados al vender, no los actuales.
class ResumenVentas {
  ResumenVentas(List<Venta> ventas) {
    for (final venta in ventas) {
      tickets++;
      ingreso += venta.totalCentavos;
      final clave = venta.codigoVendedor.isEmpty
          ? venta.vendedor
          : '${venta.vendedor} · ${venta.codigoVendedor}';
      final vendedor = vendedores.putIfAbsent(clave, RendimientoVenta.new);
      vendedor.ventas++;
      vendedor.ingreso += venta.totalCentavos;
      for (final detalle in venta.detalles) {
        final cantidad = (detalle['cantidad'] as num).toInt();
        final precio = (detalle['precioCentavos'] as num).toInt();
        final costo = (detalle['costoCentavos'] as num?)?.toInt();
        unidades += cantidad;
        vendedor.unidades += cantidad;
        if (costo == null) {
          costosCompletos = false;
        } else {
          costoTotal += costo * cantidad;
        }
        final producto = productos.putIfAbsent(
          '${detalle['nombre']} · ${detalle['codigo']}',
          RendimientoVenta.new,
        );
        producto.ventas++;
        producto.unidades += cantidad;
        producto.ingreso += precio * cantidad;
      }
    }
  }
  int tickets = 0;
  int ingreso = 0;
  int unidades = 0;
  int costoTotal = 0;
  bool costosCompletos = true;
  int get ticketPromedio => tickets == 0 ? 0 : (ingreso / tickets).round();
  int get margenBruto => ingreso - costoTotal;
  final Map<String, RendimientoVenta> vendedores = {};
  final Map<String, RendimientoVenta> productos = {};
}
