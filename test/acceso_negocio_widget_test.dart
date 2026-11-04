import 'package:aplicacion_android/data/stockgo_store.dart';
import 'package:aplicacion_android/widgets/acceso_negocio_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AccesoDePrueba extends StockGoStore {
  AccesoDePrueba() : super(factory: databaseFactoryFfi);
  List<String>? recibido;
  @override
  Future<void> entrarConCodigo(
    String codigo,
    String nombre,
    String password,
  ) async {
    recibido = [codigo, nombre, password];
    if (password != 'Correcta123!') {
      throw const StockGoException('Usuario o contraseña incorrectos.');
    }
  }
}

void main() {
  testWidgets(
    'Código y cuenta se envían juntos y un error permite corregir la contraseña',
    (tester) async {
      final store = AccesoDePrueba();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => AccesoNegocioDialog(store: store),
                ),
                child: const Text('Entrar'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();
      expect(find.text('Dirección del servidor'), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('codigo_negocio_conexion')),
        'SG1-codigo',
      );
      await tester.enterText(
        find.byKey(const ValueKey('usuario_negocio_conexion')),
        'vendedor',
      );
      await tester.enterText(
        find.byKey(const ValueKey('password_negocio_conexion')),
        'Incorrecta',
      );
      await tester.tap(find.text('Conectar e iniciar sesión'));
      await tester.pumpAndSettle();
      expect(find.text('Usuario o contraseña incorrectos.'), findsOneWidget);
      expect(store.recibido, ['SG1-codigo', 'vendedor', 'Incorrecta']);
      await tester.enterText(
        find.byKey(const ValueKey('password_negocio_conexion')),
        'Correcta123!',
      );
      await tester.tap(find.text('Conectar e iniciar sesión'));
      await tester.pumpAndSettle();
      expect(store.recibido, ['SG1-codigo', 'vendedor', 'Correcta123!']);
      expect(find.byType(AccesoNegocioDialog), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    },
  );
}
