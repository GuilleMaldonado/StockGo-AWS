import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:aplicacion_android/data/stockgo_store.dart';
import 'package:aplicacion_android/models/producto.dart';
import 'package:aplicacion_android/models/usuario.dart';
import 'package:aplicacion_android/models/venta.dart';
import 'package:aplicacion_android/screens/ventas_screen.dart';
import 'package:aplicacion_android/screens/productos_screen.dart';
import 'package:aplicacion_android/widgets/stockgo_background.dart';

import 'conexion_fichas_widget_test.dart' as preview;

class VentasDePrueba extends StockGoStore {
  VentasDePrueba(this.rol) : super(factory: databaseFactoryFfi);
  final Rol rol;
  final ventas = <Venta>[];
  List<LineaVenta>? registrado;
  @override
  Usuario get usuario => Usuario(
    id: 1,
    nombre: 'ana',
    rol: rol,
    nombres: 'Ana',
    apellidos: 'Perez',
    codigoInterno: 'VD-ANA',
  );
  @override
  String get nombreNegocio => 'Aceitera Central';
  @override
  Future<List<Producto>> buscarProductos({
    String busqueda = '',
    bool incluirInactivos = false,
  }) async => [
    const Producto(
      id: 1,
      nombre: 'Aceite sintético 5W-30',
      codigo: 'ACE-5W30-L001',
      precio: 10.25,
      costo: 7,
      cantidad: 3,
      categoria: 'Lubricante',
      ficha: {'lote': 'FAB-2026-A', 'unidadVenta': 'Botella'},
    ),
  ];
  @override
  Future<List<Venta>> listarVentas() async => ventas;
  @override
  Future<Venta> registrarVenta(
    List<LineaVenta> lineas,
    String solicitud,
  ) async {
    registrado = lineas;
    final venta = Venta(
      id: 1,
      fecha: DateTime.now().toUtc().toIso8601String(),
      vendedor: 'ana',
      totalCentavos: 1025 * lineas.single.cantidad,
      detalles: [
        {
          'nombre': 'Aceite sintético 5W-30',
          'codigo': 'ACE-5W30-L001',
          'lote': 'FAB-2026-A',
          'unidad': 'Botella',
          'cantidad': lineas.single.cantidad,
          'precioCentavos': 1025,
        },
      ],
    );
    ventas.add(venta);
    return venta;
  }
}

void main() {
  testWidgets(
    'Vendedor arma venta con lote, revisa total y confirma en móvil',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await preview.fuentesPreview(tester);
      final store = VentasDePrueba(Rol.vendedor);
      await tester.pumpWidget(
        MaterialApp(
          theme: preview.temaPreview(),
          home: RepaintBoundary(
            key: const ValueKey('vista_ventas'),
            child: StockGoBackground(child: VentasScreen(store: store)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Agregar producto a la venta'));
      await tester.tap(find.text('Agregar producto a la venta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aceite sintético 5W-30'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byIcon(Icons.add_circle_outline));
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();
      expect(find.text('Total: 20.50'), findsOneWidget);
      expect(find.textContaining('FAB-2026-A'), findsOneWidget);
      await tester.drag(find.byType(ListView).first, const Offset(0, 500));
      await tester.pumpAndSettle();
      await preview.capturar(tester, 'vista_ventas', 'ventas-movil');
      await tester.scrollUntilVisible(
        find.text('Confirmar venta'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar venta'));
      await tester.pumpAndSettle();
      expect(store.registrado, isNull);
      await tester.tap(find.text('Registrar venta'));
      await tester.pumpAndSettle();
      expect(store.registrado!.single.cantidad, 2);
      expect(store.registrado!.single.precioEsperadoCentavos, 1025);
      expect(find.text('Venta #1 · 20.50'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    },
  );
  testWidgets('Invitado no puede abrir el punto de venta', (tester) async {
    final store = VentasDePrueba(Rol.invitado);
    await tester.pumpWidget(MaterialApp(home: VentasScreen(store: store)));
    await tester.pumpAndSettle();
    expect(
      find.text('Los invitados no pueden registrar ventas.'),
      findsOneWidget,
    );
    expect(find.text('Confirmar venta'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });
  testWidgets(
    'Vendedor abre la venta directamente desde la ficha del inventario',
    (tester) async {
      final store = VentasDePrueba(Rol.vendedor);
      await tester.pumpWidget(MaterialApp(home: ProductosScreen(store: store)));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Nueva venta'), findsOneWidget);
      await tester.tap(find.text('Aceite sintético 5W-30'));
      await tester.pumpAndSettle();
      expect(find.text('Editar'), findsNothing);
      await tester.tap(find.text('Vender'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('1 · Cantidad'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 · Cantidad'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Todo el lote'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aplicar cantidad'));
      await tester.pumpAndSettle();
      expect(find.text('Total: 30.75'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    },
  );
}
