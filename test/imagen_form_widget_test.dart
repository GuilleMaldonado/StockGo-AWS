import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:aplicacion_android/data/stockgo_store.dart';
import 'package:aplicacion_android/models/producto.dart';
import 'package:aplicacion_android/models/usuario.dart';
import 'package:aplicacion_android/screens/producto_form_screen.dart';
import 'package:aplicacion_android/widgets/stockgo_background.dart';

import 'conexion_fichas_widget_test.dart' as preview;

class FotoStore extends StockGoStore {
  FotoStore() : super(factory: databaseFactoryFfi);
  Producto? guardado;
  @override
  Usuario get usuario =>
      const Usuario(id: 1, nombre: 'admin', rol: Rol.administrador);
  @override
  Future<int> guardarProducto(Producto producto) async {
    guardado = producto;
    return 1;
  }
}

const productoBase = Producto(
  id: 1,
  nombre: 'Aceite',
  codigo: 'ACE-1',
  precio: 100,
  cantidad: 3,
  categoria: 'Lubricante',
  ficha: {
    'marca': 'Mobil',
    'lote': 'MOBIL-A',
    'tipo': 'Motor',
    'unidadVenta': 'Botella',
    'viscosidadSAE': '5W-30',
  },
);

Future<Uint8List> png() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 40, 30),
    ui.Paint()..color = const ui.Color(0xFF137C66),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(40, 30);
  try {
    return (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
        .asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}

void main() {
  testWidgets('Ficha móvil permite navegar sin perder el botón de guardar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await preview.fuentesPreview(tester);
    final store = FotoStore();
    await tester.pumpWidget(
      MaterialApp(
        theme: preview.temaPreview(),
        home: RepaintBoundary(
          key: const ValueKey('ficha_movil'),
          child: StockGoBackground(
            child: ProductoFormScreen(store: store, producto: productoBase),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Guardar producto').hitTestable(), findsOneWidget);
    await preview.capturar(tester, 'ficha_movil', 'producto-form-movil');
    await tester.tap(find.text('2 · Precios y stock'));
    await tester.pumpAndSettle();
    expect(find.text('Guardar producto').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });
  testWidgets(
    'Seleccionar imagen muestra preview, termina procesamiento y guarda sus bytes',
    (tester) async {
      final bytes = (await tester.runAsync(png))!;
      final store = FotoStore();
      var seleccionada = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ProductoFormScreen(
                      store: store,
                      producto: productoBase,
                      seleccionarImagen: () async {
                        seleccionada = true;
                        return bytes;
                      },
                    ),
                  ),
                ),
                child: const Text('Abrir formulario'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir formulario'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Subir imagen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Subir imagen'));
      await esperar(tester);
      expect(seleccionada, isTrue);
      expect(find.text('Quitar imagen'), findsOneWidget);
      expect(find.text('Procesando imagen…'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Guardar producto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar producto'));
      await esperar(tester);
      expect(store.guardado?.imagen, isNotNull);
      final codec = await tester.runAsync(
        () => ui.instantiateImageCodec(store.guardado!.imagen!),
      );
      final frame = await tester.runAsync(codec!.getNextFrame);
      expect(frame!.image.width, 40);
      frame.image.dispose();
      codec.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    },
  );

  testWidgets(
    'Imagen inválida informa error y vuelve a habilitar el formulario',
    (tester) async {
      final store = FotoStore();
      await tester.pumpWidget(
        MaterialApp(
          home: ProductoFormScreen(
            store: store,
            producto: productoBase,
            seleccionarImagen: () async => Uint8List.fromList([1, 2, 3]),
          ),
        ),
      );
      await tester.ensureVisible(find.text('Subir imagen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Subir imagen'));
      await esperar(tester);
      expect(
        find.textContaining('Este archivo no es una imagen compatible'),
        findsOneWidget,
      );
      expect(find.text('Subir imagen'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Guardar producto'),
      );
      expect(button.onPressed, isNotNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    },
  );
}

Future<void> esperar(WidgetTester tester) async {
  for (var i = 0; i < 120; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    if (i >= 10 && find.byType(CircularProgressIndicator).evaluate().isEmpty) {
      await tester.pumpAndSettle();
      return;
    }
  }
  fail('El formulario quedó bloqueado después de seleccionar imagen.');
}
