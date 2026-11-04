import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aplicacion_android/data/stockgo_store.dart';
import 'package:aplicacion_android/models/usuario.dart';
import 'package:aplicacion_android/screens/cambiar_password_screen.dart';
import 'package:aplicacion_android/widgets/restablecer_password_dialog.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'conexion_fichas_widget_test.dart' as preview;

class SoporteDePrueba extends StockGoStore {
  SoporteDePrueba() : super(factory: databaseFactoryFfi);
  String? confirmacion;
  bool actualizado = false;
  @override
  Usuario get usuario => Usuario(
    id: 1,
    nombre: 'dueno',
    rol: Rol.administrador,
    requiereCambioPassword: !actualizado,
  );
  @override
  String get nombreNegocio => 'Negocio de prueba';
  @override
  Future<String> restablecerPassword(int id, String passwordAdmin) async {
    confirmacion = passwordAdmin;
    if (passwordAdmin != 'Admin123!') {
      throw const StockGoException('Contraseña incorrecta.');
    }
    return 'TemporalSoloParaPrueba';
  }

  @override
  Future<void> cambiarPassword(String actual, String nueva) async {
    if (actual != 'TemporalSoloParaPrueba') {
      throw const StockGoException('Contraseña actual incorrecta.');
    }
    actualizado = true;
    notifyListeners();
  }
}

void main() {
  testWidgets(
    'Dialogo exige reautenticación y devuelve la clave sin quedarse bloqueado',
    (tester) async {
      await preview.fuentesPreview(tester);
      final store = SoporteDePrueba();
      addTearDown(store.dispose);
      String? resultado;
      await tester.pumpWidget(
        MaterialApp(
          theme: preview.temaPreview(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  resultado = await showDialog<String>(
                    context: context,
                    builder: (_) => RestablecerPasswordDialog(
                      store: store,
                      usuario: const Usuario(
                        id: 2,
                        nombre: 'vendedor',
                        rol: Rol.vendedor,
                      ),
                    ),
                  );
                },
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Incorrecta');
      await tester.tap(find.text('Generar clave temporal'));
      await tester.pumpAndSettle();
      expect(find.text('Contraseña incorrecta.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Admin123!');
      await tester.tap(find.text('Generar clave temporal'));
      await tester.pumpAndSettle();
      expect(resultado, 'TemporalSoloParaPrueba');
      expect(find.byType(RestablecerPasswordDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Cambio obligatorio en móvil valida confirmación y habilita la cuenta',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await preview.fuentesPreview(tester);
      final store = SoporteDePrueba();
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: preview.temaPreview(),
          home: ListenableBuilder(
            listenable: store,
            builder: (_, _) => store.usuario.requiereCambioPassword
                ? CambiarPasswordScreen(store: store, obligatorio: true)
                : const Scaffold(body: Text('Cuenta habilitada')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final campos = find.byType(TextFormField);
      await tester.enterText(campos.at(0), 'TemporalSoloParaPrueba');
      await tester.enterText(campos.at(1), 'Personal123!');
      await tester.enterText(campos.at(2), 'Otra123!');
      await tester.ensureVisible(find.text('Guardar contraseña'));
      await tester.tap(find.text('Guardar contraseña'));
      await tester.pumpAndSettle();
      expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
      await tester.enterText(campos.at(2), 'Personal123!');
      await tester.ensureVisible(find.text('Guardar contraseña'));
      await tester.tap(find.text('Guardar contraseña'));
      await tester.pumpAndSettle();
      expect(find.text('Cuenta habilitada'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
