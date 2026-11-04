import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aplicacion_android/models/usuario.dart';
import 'package:aplicacion_android/network/codigo_negocio.dart';
import 'package:aplicacion_android/screens/servidor_screen.dart';

import 'conexion_fichas_widget_test.dart' as preview;

class RedesDePrueba extends preview.ServidorDePrueba {
  RedesDePrueba() : super(Rol.administrador);
  @override
  String get codigoServidor => '43956F651D95419F2695D5F57DA93E81';
  @override
  List<String> get direccionesServidor => [
    'http://127.0.0.1:8081',
    'http://192.168.56.1:8081',
    'http://192.168.0.2:8081',
  ];
}

void main() {
  testWidgets(
    'Cambiar la red copia la IP elegida y conserva la identidad del negocio',
    (tester) async {
      await preview.fuentesPreview(tester);
      String? copiado;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copiado = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final store = RedesDePrueba();
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: preview.temaPreview(),
          home: ServidorScreen(store: store),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byType(DropdownButtonFormField<String>),
        250,
      );
      await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('http://192.168.0.2:8081').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Copiar código para el vendedor'));
      await tester.tap(find.text('Copiar código para el vendedor'));
      await tester.pumpAndSettle();
      final datos = CodigoNegocio.leer(copiado!);
      expect(datos.direccion, 'http://192.168.0.2:8081');
      expect(datos.identificador, store.codigoServidor);
      expect(tester.takeException(), isNull);
    },
  );
}
