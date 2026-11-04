import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:aplicacion_android/main.dart';
import 'package:aplicacion_android/data/stockgo_store.dart';

void main() {
  testWidgets(
    'Crear empresa desde Login selecciona el negocio y permite entrar como administrador',
    (tester) async {
      sqfliteFfiInit();
      final dir = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('stockgo_empresa_ui_'),
      ))!;
      final store = StockGoStore(factory: databaseFactoryFfi);
      await tester.runAsync(
        () => store.inicializar(ruta: '${dir.path}/catalogo.db'),
      );
      try {
        await tester.pumpWidget(StockGoApp(store: store));
        await esperar(tester, () => true);
        await tester.ensureVisible(
          find.widgetWithText(TextButton, 'Crear cuenta'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Crear cuenta'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Crear mi negocio'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Crear mi negocio'));
        await tester.pumpAndSettle();
        for (final entry in {
          'Nombre de la empresa': 'Aceitera Universitaria',
          'Nombres': 'Ana',
          'Apellidos': 'Perez',
          'Usuario de acceso': 'propietario',
          'Contraseña': 'MiClave123!',
          'Confirmar contraseña': 'MiClave123!',
        }.entries) {
          final field = find.widgetWithText(TextFormField, entry.key);
          await tester.ensureVisible(field);
          await tester.pumpAndSettle();
          await tester.enterText(field, entry.value);
        }
        FocusManager.instance.primaryFocus?.unfocus();
        final save = find.widgetWithText(FilledButton, 'Crear cuenta');
        await tester.pumpAndSettle();
        await tester.ensureVisible(save);
        await tester.pumpAndSettle();
        await tester.tap(save);
        await esperar(tester, () => store.negocios.length == 1);
        await tester.pumpAndSettle();
        expect(store.nombreNegocio, 'Aceitera Universitaria');
        expect(find.text('Negocio'), findsOneWidget);
        expect(find.text('Aceitera Universitaria'), findsOneWidget);
        final user = find.widgetWithText(TextFormField, 'Usuario');
        final password = find.widgetWithText(TextFormField, 'Contraseña');
        await tester.ensureVisible(user);
        await tester.pumpAndSettle();
        await tester.enterText(user, 'propietario');
        await tester.ensureVisible(password);
        await tester.pumpAndSettle();
        await tester.enterText(password, 'MiClave123!');
        final login = find.widgetWithText(FilledButton, 'Iniciar sesión');
        await tester.ensureVisible(login);
        await tester.pumpAndSettle();
        await tester.tap(login);
        await esperar(tester, () => store.usuario != null);
        expect(store.usuario!.puedeAdministrar, isTrue);
        await tester.scrollUntilVisible(find.text('Compartir inventario'), 300);
        await tester.pumpAndSettle();
        expect(find.text('Compartir inventario'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() async {
          store.dispose();
          await store.cerrarBaseDeDatos();
          await dir.delete(recursive: true);
        });
      }
    },
  );
}

Future<void> esperar(WidgetTester tester, bool Function() listo) async {
  for (var i = 0; i < 240; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    if (i >= 20 &&
        listo() &&
        find.byType(CircularProgressIndicator).evaluate().isEmpty) {
      await tester.pump(const Duration(milliseconds: 500));
      return;
    }
  }
  fail('No terminó la operación del formulario.');
}
