import 'conexion_fichas_widget_test.dart' as preview;

import 'dart:io';

import 'package:aplicacion_android/data/stockgo_repository.dart';
import 'package:aplicacion_android/network/stockgo_lan_server.dart';
import 'package:aplicacion_android/network/codigo_negocio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:aplicacion_android/main.dart';
import 'package:aplicacion_android/data/stockgo_store.dart';

void main() {
  late StockGoStore store;
  late StockGoLanServer server;
  late StockGoRepository master;
  late Directory dir;
  setUpAll(() async {
    HttpOverrides.global = null;
    sqfliteFfiInit();
    store = StockGoStore(factory: databaseFactoryFfi);
    await store.inicializar(ruta: inMemoryDatabasePath);
    dir = await Directory.systemTemp.createTemp('stockgo_registro_ui_');
    master = StockGoRepository(factory: databaseFactoryFfi);
    await master.inicializar(
      ruta: '${dir.path}/maestro.db',
      crearUsuariosDemo: false,
    );
    await master.crearPropietario(
      'dueno',
      'DuenoClave123!',
      nombres: 'Ana',
      apellidos: 'Perez',
    );
    await master.asignarNombreNegocio('Aceitera del vendedor');
    server = StockGoLanServer(
      factory: databaseFactoryFfi,
      ruta: master.databasePath,
    );
    await server.iniciar(port: 0, address: InternetAddress.loopbackIPv4);
    await store.conectarConCodigo(
      CodigoNegocio(
        'http://127.0.0.1:${server.puerto}',
        server.codigoConexion,
      ).codificar(),
    );
  });
  tearDownAll(() async {
    await store.cerrarBaseDeDatos();
    store.dispose();
    await server.detener();
    await master.cerrarBaseDeDatos();
    await dir.delete(recursive: true);
  });

  testWidgets(
    'Crear cuenta, iniciar sesión y salir del inventario limpia la navegación',
    (tester) async {
      await tester.pumpWidget(StockGoApp(store: store));
      await tester.ensureVisible(find.text('Crear cuenta'));
      await tester.pump();
      await tester.tap(find.text('Crear cuenta'));
      await settle(tester);
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Ana');
      await tester.ensureVisible(fields.at(1));
      await tester.pump();
      await tester.enterText(fields.at(1), 'Perez');
      await tester.ensureVisible(fields.at(2));
      await tester.pump();
      await tester.enterText(fields.at(2), 'usuario.nuevo');
      await tester.ensureVisible(fields.at(3));
      await tester.pump();
      await tester.enterText(fields.at(3), 'MiClaveNueva123!');
      await tester.ensureVisible(fields.at(4));
      await tester.pump();
      await tester.enterText(fields.at(4), 'MiClaveNueva123!');
      final crear = find.widgetWithText(FilledButton, 'Crear cuenta');
      await tester.ensureVisible(crear);
      await tester.pump();
      await tester.tap(crear);
      await settle(tester);
      expect(find.text('Bienvenido de nuevo'), findsOneWidget);
      expect(store.usuario, isNull);
      final loginFields = find.byType(TextFormField);
      await tester.ensureVisible(loginFields.at(1));
      await tester.pump();
      await tester.enterText(loginFields.at(1), 'MiClaveNueva123!');
      await tester.ensureVisible(find.text('Iniciar sesión'));
      await tester.pump();
      await tester.tap(find.text('Iniciar sesión'));
      await settle(tester);
      expect(find.text('Hola, Ana Perez'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Consultar Productos'),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.tap(find.text('Consultar Productos'));
      await settle(tester);
      expect(find.text('Inventario'), findsOneWidget);
      await tester.tap(find.text('Cerrar sesión'));
      await settle(tester);
      expect(store.usuario, isNull);
      expect(find.text('Bienvenido de nuevo'), findsOneWidget);
      expect(find.text('Inventario'), findsNothing);
      expect(
        Navigator.of(tester.element(find.text('Bienvenido de nuevo'))).canPop(),
        isFalse,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      store.usarLocal();
      await tester.pump(const Duration(seconds: 30));
    },
  );

  testWidgets('Invitado puede cerrar sesión desde el inventario', (
    tester,
  ) async {
    store.cerrarSesion();
    await tester.pumpWidget(StockGoApp(store: store));
    await tester.ensureVisible(find.text('Continuar como invitado'));
    await tester.pump();
    await tester.tap(find.text('Continuar como invitado'));
    await settle(tester);
    await tester.scrollUntilVisible(
      find.text('Consultar Productos'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.tap(find.text('Consultar Productos'));
    await settle(tester);
    await tester.tap(find.text('Cerrar sesión'));
    await settle(tester);
    expect(store.usuario, isNull);
    expect(find.text('Crear cuenta'), findsOneWidget);
    expect(find.text('Inventario'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('El Login se adapta a una pantalla de teléfono', (tester) async {
    store.cerrarSesion();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await preview.fuentesPreview(tester);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('vista_login'),
        child: StockGoApp(store: store),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1500));
    expect(tester.takeException(), isNull);
    await preview.capturar(tester, 'vista_login', 'login_movil');
    if (const bool.fromEnvironment('CAPTURAR_UI')) {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      await tester.pumpAndSettle();
      await preview.capturar(tester, 'vista_login', 'login_escritorio');
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.text('Crear cuenta'));
    await tester.pump();
    expect(find.text('Crear cuenta'), findsOneWidget);
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 240; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    if (i >= 15 && find.byType(CircularProgressIndicator).evaluate().isEmpty) {
      await tester.pump(const Duration(milliseconds: 400));
      return;
    }
  }
  fail('La operación no finalizó en el tiempo esperado.');
}
