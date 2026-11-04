import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aplicacion_android/models/producto.dart';
import 'package:aplicacion_android/models/usuario.dart';
import 'package:aplicacion_android/screens/productos_screen.dart';
import 'package:aplicacion_android/widgets/stockgo_background.dart';

import 'conexion_fichas_widget_test.dart' as preview;
import 'ventas_widget_test.dart' show VentasDePrueba;

class CatalogoVisual extends VentasDePrueba {
  CatalogoVisual(super.rol);
  @override
  Future<List<Producto>> buscarProductos({
    String busqueda = '',
    bool incluirInactivos = false,
  }) async => const [
    Producto(
      id: 1,
      nombre: 'Aceite sintético 5W-30',
      codigo: 'LUB-001',
      precio: 129.90,
      cantidad: 24,
      categoria: 'Lubricante',
    ),
    Producto(
      id: 2,
      nombre: 'Filtro de aceite',
      codigo: 'FLT-002',
      precio: 65,
      cantidad: 12,
      categoria: 'Filtro',
    ),
    Producto(
      id: 3,
      nombre: 'Bujía de iridio',
      codigo: 'REP-003',
      precio: 90,
      cantidad: 8,
    ),
    Producto(
      id: 4,
      nombre: 'Juego de herramientas',
      codigo: 'ACC-004',
      precio: 185,
      cantidad: 4,
      categoria: 'Accesorio',
    ),
  ];
}

void main() {
  for (final size in [
    const Size(390, 844),
    const Size(1200, 900),
    const Size(320, 780),
  ]) {
    testWidgets(
      'Catálogo visual filtra categorías y conserva permisos a ${size.width}',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await preview.fuentesPreview(tester);
        final store = CatalogoVisual(Rol.administrador);
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('catalogo_celeste'),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: preview.temaPreview(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(size.width == 320 ? 1.3 : 1),
                ),
                child: StockGoBackground(child: child!),
              ),
              home: ProductosScreen(store: store),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(SliverGrid), findsOneWidget);
        expect(find.text('Aceite sintético 5W-30'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await preview.capturar(
          tester,
          'catalogo_celeste',
          'catalogo-celeste-${size.width.toInt()}',
        );
        final categorias = find.byWidgetPredicate(
          (widget) =>
              widget is ListView && widget.scrollDirection == Axis.horizontal,
        );
        await tester.ensureVisible(categorias);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Lubricantes'),
          100,
          scrollable: find.descendant(
            of: categorias,
            matching: find.byType(Scrollable),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Lubricantes'));
        await tester.pumpAndSettle();
        expect(find.text('Filtro de aceite'), findsNothing);
        expect(find.text('Aceite sintético 5W-30'), findsOneWidget);
        await tester.ensureVisible(find.text('Aceite sintético 5W-30'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Aceite sintético 5W-30'));
        await tester.pumpAndSettle();
        expect(find.text('Editar'), findsOneWidget);
        expect(find.text('Cantidad disponible: 24'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        store.dispose();
      },
    );
  }
}
