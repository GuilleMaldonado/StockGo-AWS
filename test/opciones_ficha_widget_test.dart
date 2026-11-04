import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aplicacion_android/models/ficha_producto.dart';
import 'package:aplicacion_android/widgets/ficha_tecnica_form.dart';

void main() {
  testWidgets(
    'Viscosidad seleccionable conserva datos y permite combinaciones manuales de especificaciones',
    (tester) async {
      final controllers = {
        for (final campo in camposProducto)
          campo.clave: TextEditingController(),
      };
      controllers['tipo']!.text = 'Aceite de motor';
      controllers['viscosidadSAE']!.text = '5W-30';
      final costo = TextEditingController(text: '0');
      final stock = TextEditingController(text: '0');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Form(
                child: FichaTecnicaForm(
                  categoria: 'Lubricante',
                  controllers: controllers,
                  costo: costo,
                  stockMinimo: stock,
                  enabled: true,
                  onCategoria: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      final viscosidad = find.descendant(
        of: find.byKey(const ValueKey('ficha_viscosidadSAE')),
        matching: find.byType(DropdownButtonFormField<String>),
      );
      expect(viscosidad, findsOneWidget);
      var widget = tester.widget<DropdownButtonFormField<String>>(viscosidad);
      expect(widget.initialValue, '5W-30');
      controllers['tipo']!.text = 'Aceite de diferencial';
      await tester.pumpAndSettle();
      widget = tester.widget<DropdownButtonFormField<String>>(viscosidad);
      // El dato existente no se cambia silenciosamente al cambiar el tipo.
      expect(widget.initialValue, '5W-30');
      await tester.ensureVisible(viscosidad);
      await tester.pumpAndSettle();
      await tester.tap(viscosidad);
      await tester.pumpAndSettle();
      expect(find.text('75W-90'), findsWidgets);
      await tester.tap(find.text('75W-90').last);
      await tester.pumpAndSettle();
      expect(controllers['viscosidadSAE']!.text, '75W-90');
      final api = find.descendant(
        of: find.byKey(const ValueKey('ficha_normaAPI')),
        matching: find.byType(DropdownButtonFormField<String>),
      );
      await tester.ensureVisible(api);
      await tester.pumpAndSettle();
      await tester.tap(api);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Otro / combinación (escribir)'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Otro / combinación (escribir)').last);
      await tester.pumpAndSettle();
      final manual = find.descendant(
        of: find.byKey(const ValueKey('ficha_normaAPI')),
        matching: find.byType(TextFormField),
      );
      await tester.ensureVisible(manual);
      await tester.pumpAndSettle();
      await tester.enterText(manual, 'SP / CF según envase');
      expect(controllers['normaAPI']!.text, 'SP / CF según envase');
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
