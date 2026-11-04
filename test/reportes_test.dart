import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:aplicacion_android/data/stockgo_repository.dart';
import 'package:aplicacion_android/models/producto.dart';
import 'package:aplicacion_android/models/usuario.dart';
import 'package:aplicacion_android/models/venta.dart';
import 'package:aplicacion_android/models/resumen_ventas.dart';
import 'package:aplicacion_android/screens/reportes_screen.dart';

import 'ventas_widget_test.dart' show VentasDePrueba;
import 'conexion_fichas_widget_test.dart' as preview;

Venta ejemplo(int id, {int? costo = 600}) => Venta(
  id: id,
  fecha: DateTime.now().toUtc().toIso8601String(),
  vendedor: 'Ana Perez',
  codigoVendedor: 'VD-001',
  totalCentavos: 2000,
  detalles: [
    {
      'nombre': 'Aceite',
      'codigo': 'ACE-001',
      'lote': 'LOTE-A',
      'cantidad': 2,
      'precioCentavos': 1000,
      'costoCentavos': ?costo,
    },
  ],
);

void main() {
  setUpAll(sqfliteFfiInit);
  test('Totales, margen histórico y costos incompletos', () {
    final resumen = ResumenVentas([ejemplo(1), ejemplo(2)]);
    expect(resumen.ingreso, 4000);
    expect(resumen.unidades, 4);
    expect(resumen.ticketPromedio, 2000);
    expect(resumen.margenBruto, 1600);
    expect(resumen.vendedores['Ana Perez · VD-001']!.ventas, 2);
    expect(resumen.productos['Aceite · ACE-001']!.unidades, 4);
    expect(ResumenVentas([ejemplo(1, costo: null)]).costosCompletos, false);
    expect(ResumenVentas([]).ticketPromedio, 0);
  });

  test('El historial conserva más de 100 ventas', () async {
    final dir = await Directory.systemTemp.createTemp('stockgo_reportes_');
    final repo = StockGoRepository(factory: databaseFactoryFfi);
    try {
      await repo.inicializar(
        ruta: '${dir.path}/ventas.db',
        crearUsuariosDemo: false,
      );
      await repo.crearPropietario(
        'dueno',
        'Admin123!',
        nombres: 'Ana',
        apellidos: 'Perez',
      );
      await repo.iniciarSesion('dueno', 'Admin123!');
      final producto = await repo.guardarProducto(
        const Producto(
          nombre: 'Filtro',
          codigo: 'F-001',
          precio: 10,
          costo: 5,
          cantidad: 105,
        ),
      );
      for (var i = 0; i < 105; i++) {
        await repo.registrarVenta([
          LineaVenta(productoId: producto, cantidad: 1),
        ], 'reportes_solicitud_$i');
      }
      final ventas = await repo.listarVentas();
      expect(ventas.length, 105);
      expect(ResumenVentas(ventas).ingreso, 105000);
    } finally {
      await repo.cerrarBaseDeDatos();
      await dir.delete(recursive: true);
    }
  });

  for (final rol in [Rol.administrador, Rol.vendedor]) {
    testWidgets('Reportes móviles, detalle y permisos: $rol', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await preview.fuentesPreview(tester);
      final store = VentasDePrueba(rol)..ventas.add(ejemplo(1));
      await tester.pumpWidget(
        MaterialApp(
          theme: preview.temaPreview(),
          home: ReportesScreen(store: store),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ventas completadas'), findsOneWidget);
      expect(
        find.text('Margen bruto estimado'),
        rol == Rol.administrador ? findsOneWidget : findsNothing,
      );
      await tester.scrollUntilVisible(find.text('Venta #1 · Q 20.00'), 300);
      await tester.tap(find.text('Venta #1 · Q 20.00'));
      await tester.pumpAndSettle();
      expect(find.text('Vendió: Ana Perez · VD-001'), findsOneWidget);
      expect(find.textContaining('LOTE-A'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
