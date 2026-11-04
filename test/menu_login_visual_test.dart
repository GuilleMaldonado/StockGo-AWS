import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:aplicacion_android/data/stockgo_store.dart';
import 'package:aplicacion_android/models/usuario.dart';
import 'package:aplicacion_android/screens/home_screen.dart';
import 'package:aplicacion_android/screens/login_screen.dart';
import 'package:aplicacion_android/widgets/stockgo_background.dart';

import 'conexion_fichas_widget_test.dart' as preview;
import 'ventas_widget_test.dart' show VentasDePrueba;

class LoginVisualStore extends StockGoStore {
  LoginVisualStore() : super(factory: databaseFactoryFfi);
  @override
  Future<void> inicializar({String? ruta}) async {}
}

void main() {
  for (final size in [const Size(390, 844), const Size(1200, 900)]) {
    testWidgets('Login con relieve no recorta campos a ${size.width}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await preview.fuentesPreview(tester);
      final store = LoginVisualStore();
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('login_relieve'),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: preview.temaPreview(),
            builder: (context, child) => StockGoBackground(child: child!),
            home: LoginScreen(store: store),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await preview.capturar(
        tester,
        'login_relieve',
        size.width > 600 ? 'login-relieve-escritorio' : 'login-relieve-movil',
      );
      await tester.scrollUntilVisible(
        find.text('Iniciar sesión'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();
      expect(find.text('Ingresa tu usuario.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    });
  }
  for (final rol in [Rol.invitado, Rol.vendedor, Rol.administrador]) {
    testWidgets(
      'Menú muestra módulos del rol ${rol.name} y permite volver a inicio',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await preview.fuentesPreview(tester);
        final store = VentasDePrueba(rol);
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('menu_modulos'),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: preview.temaPreview(),
              builder: (context, child) => StockGoBackground(child: child!),
              home: HomeScreen(store: store),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Abrir módulos'));
        await tester.pumpAndSettle();
        expect(find.text('Inventario · Stock'), findsOneWidget);
        expect(
          find.text('Compartir inventario'),
          rol == Rol.administrador ? findsWidgets : findsNothing,
        );
        expect(
          find.text('Ventas'),
          rol == Rol.invitado ? findsNothing : findsWidgets,
        );
        await preview.capturar(tester, 'menu_modulos', 'menu-${rol.name}');
        await tester.tap(find.text('Inventario · Stock'));
        await tester.pumpAndSettle();
        expect(find.text('Catálogo del negocio'), findsOneWidget);
        if (rol != Rol.invitado) {
          await tester.tap(find.byTooltip('Abrir módulos'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Ventas').last);
          await tester.pumpAndSettle();
          expect(find.text('Vende con el inventario al día'), findsOneWidget);
        }
        await tester.tap(find.byTooltip('Abrir módulos'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Inicio'));
        await tester.pumpAndSettle();
        expect(find.text('Hola, Ana Perez'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        store.dispose();
      },
    );
  }
}
