import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:aplicacion_android/data/stockgo_store.dart';
import 'package:aplicacion_android/models/usuario.dart';
import 'package:aplicacion_android/screens/servidor_screen.dart';

class StoreMaestro extends StockGoStore {
  StoreMaestro(this.nativo) : super(factory: databaseFactoryFfi);
  final bool nativo;
  bool encendido = false;
  @override
  bool get admiteServidorLocal => nativo;
  @override
  Usuario get usuario =>
      const Usuario(id: 1, nombre: 'admin', rol: Rol.administrador);
  @override
  String get nombreNegocio => 'Aceitera Central';
  @override
  bool get servidorActivo => encendido;
  @override
  String? get codigoServidor => encendido ? 'A' * 32 : null;
  @override
  List<String> get direccionesServidor =>
      encendido ? ['http://192.168.1.10:8081'] : [];
  @override
  Future<void> iniciarServidor() async {
    encendido = true;
    notifyListeners();
  }

  @override
  Future<void> detenerServidor() async {
    encendido = false;
    notifyListeners();
  }
}

void main() {
  testWidgets(
    'Web muestra pasos utilizables y no ofrece un servidor detenido ni botón falso',
    (tester) async {
      final store = StoreMaestro(false);
      await tester.pumpWidget(MaterialApp(home: ServidorScreen(store: store)));
      expect(find.text('Servidor detenido'), findsNothing);
      expect(find.text('Iniciar servidor'), findsNothing);
      await tester.ensureVisible(find.text('Preparar dispositivo maestro'));
      await tester.tap(find.text('Preparar dispositivo maestro'));
      await tester.pumpAndSettle();
      expect(find.text('Preparar el dispositivo maestro'), findsOneWidget);
      expect(find.text('Android'), findsOneWidget);
      expect(find.text('Windows'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    },
  );
  testWidgets(
    'Administrador nativo inicia y detiene desde el control principal',
    (tester) async {
      final store = StoreMaestro(true);
      await tester.pumpWidget(MaterialApp(home: ServidorScreen(store: store)));
      await tester.ensureVisible(find.text('Iniciar servidor'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Iniciar servidor'));
      await tester.pumpAndSettle();
      expect(store.servidorActivo, isTrue);
      await tester.drag(find.byType(ListView), const Offset(0, 1000));
      await tester.pumpAndSettle();
      expect(find.text('● Servidor activo'), findsOneWidget);
      await tester.ensureVisible(find.text('Detener servidor'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Detener servidor'));
      await tester.pumpAndSettle();
      expect(store.servidorActivo, isFalse);
      await tester.drag(find.byType(ListView), const Offset(0, 1000));
      await tester.pumpAndSettle();
      expect(find.text('Servidor detenido'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    },
  );
}
