import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aplicacion_android/models/usuario.dart';
import 'package:aplicacion_android/screens/home_screen.dart';
import 'package:aplicacion_android/screens/registro_screen.dart';
import 'package:aplicacion_android/widgets/stockgo_background.dart';

import 'conexion_fichas_widget_test.dart' as preview;
import 'ventas_widget_test.dart' show VentasDePrueba;

void main() {
  testWidgets(
    'Registro estrecho permite elegir negocio sin recortar opciones',
    (tester) async {
      tester.view.physicalSize = const Size(320, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = VentasDePrueba(Rol.invitado);
      await tester.pumpWidget(
        MaterialApp(
          theme: preview.temaPreview(),
          home: RegistroScreen(store: store),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Crear mi negocio'),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Crear mi negocio'));
      await tester.pumpAndSettle();
      expect(find.text('Nombre de la empresa'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    },
  );
  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.macOS,
    TargetPlatform.windows,
  ]) {
    testWidgets(
      'Inicio y acceso al inventario sin desbordamientos en ${platform.name}',
      (tester) async {
        final desktop =
            platform == TargetPlatform.macOS ||
            platform == TargetPlatform.windows;
        tester.view.physicalSize = desktop
            ? const Size(1200, 900)
            : const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await preview.fuentesPreview(tester);
        final store = VentasDePrueba(Rol.administrador);
        await tester.pumpWidget(
          MaterialApp(
            theme: preview.temaPreview().copyWith(platform: platform),
            home: RepaintBoundary(
              key: const ValueKey('inicio_moderno'),
              child: StockGoBackground(child: HomeScreen(store: store)),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await preview.capturar(
          tester,
          'inicio_moderno',
          'inicio-${platform.name}',
        );
        await tester.scrollUntilVisible(
          find.text('Gestionar Productos'),
          160,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Gestionar Productos'));
        await tester.pumpAndSettle();
        expect(find.text('Catálogo del negocio'), findsOneWidget);
        expect(find.text('Agregar producto'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        store.dispose();
      },
    );
  }
  testWidgets(
    'Inicio de vendedor en móvil estrecho y texto ampliado conserva ventas',
    (tester) async {
      tester.view.physicalSize = const Size(320, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = VentasDePrueba(Rol.vendedor);
      await tester.pumpWidget(
        MaterialApp(
          theme: preview.temaPreview(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: HomeScreen(store: store),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Ventas'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ventas'));
      await tester.pumpAndSettle();
      expect(find.text('Vende con el inventario al día'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    },
  );
}
