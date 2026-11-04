import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:aplicacion_android/main.dart';
import 'package:aplicacion_android/models/producto.dart';
import 'package:aplicacion_android/data/stockgo_store.dart';

void main() {
  late StockGoStore store;
  setUpAll(() async {
    sqfliteFfiInit();
    store = StockGoStore(factory: databaseFactoryFfi);
    await store.inicializar(ruta: inMemoryDatabasePath);
    await store.iniciarSesion('admin', 'Admin123!');
    await store.guardarProducto(
      const Producto(
        nombre: 'Producto de consulta',
        codigo: 'CONSULTA-001',
        precio: 10,
        cantidad: 7,
      ),
    );
    store.cerrarSesion();
  });
  tearDownAll(() async {
    await store.cerrarBaseDeDatos();
    store.dispose();
  });

  testWidgets('El Login ofrece acceso de invitado y valida campos', (
    tester,
  ) async {
    store.cerrarSesion();
    await tester.pumpWidget(StockGoApp(store: store));
    expect(find.text('StockGo'), findsOneWidget);
    expect(find.text('Continuar como invitado'), findsOneWidget);
    await tester.ensureVisible(find.text('Iniciar sesión'));
    await tester.pump();
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pump();
    expect(find.text('Ingresa tu usuario.'), findsOneWidget);
    expect(find.text('Ingresa tu contraseña.'), findsOneWidget);
  });

  testWidgets('Admin registra un producto y aparece en el inventario', (
    tester,
  ) async {
    await tester.runAsync(() => store.iniciarSesion('admin', 'Admin123!'));
    await tester.pumpWidget(StockGoApp(store: store));
    await tester.runAsync(() async {
      await tester.scrollUntilVisible(
        find.text('Gestionar Productos'),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.tap(find.text('Gestionar Productos'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await settleDatabase(tester);
    await tester.tap(find.text('Agregar producto'));
    await settleDatabase(tester);
    final fields = find.byType(TextFormField);
    await tester.ensureVisible(fields.at(0));
    await tester.pump();
    await tester.enterText(fields.at(0), 'Cuaderno de prueba');
    await tester.ensureVisible(fields.at(1));
    await tester.pump();
    await tester.enterText(fields.at(1), 'UI-001');
    await tester.ensureVisible(fields.at(2));
    await tester.pump();
    await tester.enterText(fields.at(2), '15,50');
    await tester.ensureVisible(fields.at(3));
    await tester.pump();
    await tester.enterText(fields.at(3), '20');
    for (final entry in {
      'marca': 'Bosch',
      'tipo': 'Filtro',
      'unidadVenta': 'Unidad',
    }.entries) {
      final field = find.byKey(ValueKey('ficha_${entry.key}'));
      await tester.ensureVisible(field);
      await tester.pump();
      if (entry.key == 'marca') {
        await tester.enterText(field, entry.value);
      } else {
        final dropdown = find.descendant(
          of: field,
          matching: find.byType(DropdownButtonFormField<String>),
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await tester.ensureVisible(dropdown);
        await tester.pumpAndSettle();
        await tester.tap(dropdown);
        await tester.pumpAndSettle();
        await tester.tap(find.text(entry.value).last);
        await tester.pumpAndSettle();
      }
    }
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Guardar producto'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Guardar producto'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await settleDatabase(tester);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await settleDatabase(tester);
    expect(find.text('Cuaderno de prueba'), findsOneWidget);
    expect(find.text('Disponible: 20'), findsOneWidget);
    await tester.tap(find.text('Cuaderno de prueba'));
    await settleDatabase(tester);
    expect(find.text('Editar'), findsOneWidget);
    expect(find.text('Desactivar'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final invitado in [false, true]) {
    testWidgets(
      '${invitado ? 'Invitado' : 'Vendedor'} consulta sin controles de edición',
      (tester) async {
        if (invitado) {
          store.entrarComoInvitado();
        } else {
          await tester.runAsync(
            () => store.iniciarSesion('vendedor', 'Vendedor123!'),
          );
        }
        await tester.pumpWidget(StockGoApp(store: store));
        await tester.runAsync(() async {
          await tester.scrollUntilVisible(
            find.text('Consultar Productos'),
            160,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pump();
          await tester.tap(find.text('Consultar Productos'));
          await tester.pump();
          await Future<void>.delayed(const Duration(milliseconds: 300));
        });
        await settleDatabase(tester);
        expect(find.text('Agregar producto'), findsNothing);
        expect(find.text('Mostrar también desactivados'), findsNothing);
        await tester.tap(find.text('Producto de consulta'));
        await settleDatabase(tester);
        expect(find.text('Cantidad disponible: 7'), findsOneWidget);
        expect(find.text('Editar'), findsNothing);
        expect(find.text('Desactivar'), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

// SQLite FFI finaliza en tiempo real; pumpAndSettle solo avanza el reloj simulado.
Future<void> settleDatabase(WidgetTester tester) async {
  for (var i = 0; i < 100; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    if (i >= 15 && find.byType(CircularProgressIndicator).evaluate().isEmpty) {
      await tester.pump(const Duration(milliseconds: 400));
      return;
    }
  }
  fail('SQLite no terminó la operación dentro del tiempo esperado.');
}
