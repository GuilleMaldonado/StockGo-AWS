import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:aplicacion_android/data/stockgo_store.dart';
import 'package:aplicacion_android/models/ficha_producto.dart';
import 'package:aplicacion_android/models/usuario.dart';
import 'package:aplicacion_android/screens/servidor_screen.dart';
import 'package:aplicacion_android/widgets/ficha_tecnica_form.dart';
import 'package:aplicacion_android/theme/stockgo_theme.dart';

class ServidorDePrueba extends StockGoStore {
  ServidorDePrueba(this.rol) : super(factory: databaseFactoryFfi);
  final Rol rol;
  @override
  Usuario get usuario => Usuario(id: 1, nombre: 'equipo', rol: rol);
  @override
  String get nombreNegocio => 'Aceitera Central';
  @override
  bool get servidorActivo => true;
  @override
  String get codigoServidor => '123456';
  @override
  List<String> get direccionesServidor => [
    'http://127.0.0.1:8081',
    'http://192.168.1.10:8081',
  ];
}

void main() {
  testWidgets(
    'Administrador ve código y dirección en la app sin consola, en pantalla móvil',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await fuentesPreview(tester);
      final store = ServidorDePrueba(Rol.administrador);
      await tester.pumpWidget(
        MaterialApp(
          theme: temaPreview(),
          home: RepaintBoundary(
            key: const ValueKey('vista_servidor'),
            child: ServidorScreen(store: store),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('codigo_servidor')), findsOneWidget);
      expect(find.text('123456'), findsOneWidget);
      await capturar(tester, 'vista_servidor', 'servidor');
      final direccionCompartida = find.byWidgetPredicate(
        (widget) =>
            widget is SelectableText &&
            widget.data == 'http://192.168.1.10:8081',
      );
      await tester.scrollUntilVisible(
        direccionCompartida,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(direccionCompartida, findsOneWidget);
      expect(find.textContaining('consola'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    },
  );

  testWidgets('Vendedor no ve el código ni controles para alojar el negocio', (
    tester,
  ) async {
    final store = ServidorDePrueba(Rol.vendedor);
    await tester.pumpWidget(MaterialApp(home: ServidorScreen(store: store)));
    expect(find.byKey(const ValueKey('codigo_servidor')), findsNothing);
    expect(find.text('Detener servidor'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });

  testWidgets(
    'Categoría cambia los campos técnicos de lubricante, repuesto, filtro y aditivo',
    (tester) async {
      if (const bool.fromEnvironment('CAPTURAR_UI')) {
        tester.view.physicalSize = const Size(760, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
      }
      final controllers = {
        for (final campo in camposProducto)
          campo.clave: TextEditingController(),
      };
      final costo = TextEditingController(text: '0');
      final stock = TextEditingController(text: '0');
      String categoria = 'Repuesto';
      final form = StatefulBuilder(
        builder: (context, setState) => FichaTecnicaForm(
          categoria: categoria,
          controllers: controllers,
          costo: costo,
          stockMinimo: stock,
          enabled: true,
          onCategoria: (value) => setState(() => categoria = value),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: temaPreview(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: RepaintBoundary(
                key: const ValueKey('vista_ficha'),
                child: ColoredBox(
                  color: StockGoTheme.background,
                  child: Form(child: form),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('ficha_calibre')), findsOneWidget);
      expect(find.byKey(const ValueKey('ficha_viscosidadSAE')), findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Lubricante'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ficha_viscosidadSAE')), findsOneWidget);
      expect(find.byKey(const ValueKey('ficha_calibre')), findsNothing);
      expect(find.byKey(const ValueKey('ficha_referenciaOEM')), findsNothing);
      await capturar(tester, 'vista_ficha', 'lubricante');
      await tester.tap(find.widgetWithText(ChoiceChip, 'Aditivo'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ficha_dosificacion')), findsOneWidget);
      expect(find.byKey(const ValueKey('ficha_viscosidadSAE')), findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Filtro'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('ficha_gradoFiltracion')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('ficha_valvulaBypass')), findsOneWidget);
      expect(find.byKey(const ValueKey('ficha_normaAPI')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      for (final controller in controllers.values) {
        controller.dispose();
      }
      costo.dispose();
      stock.dispose();
    },
  );
}

Future<void> capturar(WidgetTester tester, String key, String nombre) async {
  if (!const bool.fromEnvironment('CAPTURAR_UI')) return;
  await tester.pump();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(ValueKey(key)),
  );
  await tester.runAsync(() async {
    final imagen = await boundary.toImage(pixelRatio: 1);
    final bytes = await imagen.toByteData(format: ui.ImageByteFormat.png);
    await Directory('build/previews').create(recursive: true);
    await File('build/previews/$nombre.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    imagen.dispose();
  });
}

Future<void> fuentesPreview(WidgetTester tester) async {
  if (!const bool.fromEnvironment('CAPTURAR_UI')) return;
  await tester.runAsync(() async {
    final body = File(r'C:\Windows\Fonts\segoeui.ttf');
    final icons = File(
      r'C:\src\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf',
    );
    if (await body.exists()) {
      await ui.loadFontFromList(await body.readAsBytes(), fontFamily: 'Roboto');
    }
    if (await icons.exists()) {
      await ui.loadFontFromList(
        await icons.readAsBytes(),
        fontFamily: 'MaterialIcons',
      );
    }
  });
}

ThemeData temaPreview() {
  final theme = StockGoTheme.light;
  if (!const bool.fromEnvironment('CAPTURAR_UI')) return theme;
  return theme.copyWith(
    textTheme: theme.textTheme.apply(fontFamily: 'Roboto'),
    appBarTheme: theme.appBarTheme.copyWith(
      titleTextStyle: theme.textTheme.titleLarge?.copyWith(
        fontFamily: 'Roboto',
      ),
    ),
  );
}
