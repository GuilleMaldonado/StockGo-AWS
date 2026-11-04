import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:aplicacion_android/data/stockgo_store.dart';
import 'package:aplicacion_android/network/windows_browser_control.dart';
import 'package:aplicacion_android/network/codigo_negocio.dart';

void main() {
  test('El puente Windows exige el administrador del negocio y el equipo no mezcla empresas', () async {
    sqfliteFfiInit();
    final dir = await Directory.systemTemp.createTemp(
      'stockgo_windows_equipo_',
    );
    final store = StockGoStore(factory: databaseFactoryFfi);
    final client = StockGoStore(factory: databaseFactoryFfi);
    final control = WindowsBrowserControl(store: store);
    try {
      await store.inicializar(ruta: '${dir.path}/catalogo.db');
      await store.crearPropietario(
        'dueno.a',
        'ClaveDueno123!',
        nombreNegocio: 'Aceitera A',
        nombres: 'Ana',
        apellidos: 'Perez',
      );
      final a = store.negocioSeleccionado!;
      await store.iniciarSesion('dueno.a', 'ClaveDueno123!');
      await store.crearUsuario(
        'vendedor.a',
        'ClaveEquipo123!',
        nombres: 'Ana',
        apellidos: 'Perez',
      );
      expect(
        (await store.listarUsuarios()).map((u) => u.nombre),
        contains('vendedor.a'),
      );
      store.cerrarSesion();
      await store.crearPropietario(
        'dueno.b',
        'ClaveDueno456!',
        nombreNegocio: 'Repuestos B',
        nombres: 'Ana',
        apellidos: 'Perez',
      );
      await store.iniciarSesion('dueno.b', 'ClaveDueno456!');
      await store.crearUsuario(
        'vendedor.b',
        'ClaveEquipo456!',
        nombres: 'Ana',
        apellidos: 'Perez',
      );
      expect(
        (await store.listarUsuarios()).map((u) => u.nombre),
        isNot(contains('vendedor.a')),
      );
      store.cerrarSesion();
      await control.iniciar(port: 0);
      final base = 'http://127.0.0.1:${control.puerto}';
      Future<http.Response> start(
        String user,
        String password, {
        String origin = 'http://localhost:8080',
      }) => http.post(
        Uri.parse('$base/desktop/start'),
        headers: {'Content-Type': 'application/json', 'Origin': origin},
        body: jsonEncode({
          'negocioId': a,
          'usuario': user,
          'password': password,
        }),
      );
      expect(
        (await start(
          'dueno.a',
          'ClaveDueno123!',
          origin: 'https://sitio-ajeno.example',
        )).statusCode,
        403,
      );
      expect((await start('vendedor.a', 'ClaveEquipo123!')).statusCode, 403);
      expect(store.servidorActivo, isFalse);
      expect(store.usuario, isNull);
      expect((await start('dueno.b', 'ClaveDueno456!')).statusCode, 403);
      final response = await start('dueno.a', 'ClaveDueno123!');
      expect(response.statusCode, 200, reason: response.body);
      expect(store.servidorActivo, isTrue);
      final codigo = (jsonDecode(response.body) as Map)['codigo'] as String;
      expect(CodigoNegocio.leer(codigo).direccion, 'http://127.0.0.1:8081');
      await client.conectarConCodigo(codigo);
      await client.iniciarSesion('dueno.a', 'ClaveDueno123!');
      final equipo = await client.listarUsuarios();
      expect(equipo.map((u) => u.nombre), contains('vendedor.a'));
      expect(equipo.map((u) => u.nombre), isNot(contains('vendedor.b')));
      final login = await http.post(
        Uri.parse('http://127.0.0.1:8081/auth/login'),
        headers: {
          'Content-Type': 'application/json',
          'X-StockGo-Code': CodigoNegocio.leer(codigo).identificador,
        },
        body: jsonEncode({'usuario': 'dueno.a', 'password': 'ClaveDueno123!'}),
      );
      final token = (jsonDecode(login.body) as Map)['token'] as String;
      final raw = await http.get(
        Uri.parse('http://127.0.0.1:8081/users'),
        headers: {
          'Authorization': 'Bearer $token',
          'X-StockGo-Code': CodigoNegocio.leer(codigo).identificador,
        },
      );
      expect(raw.statusCode, 200);
      final datos = raw.body;
      expect(datos, isNot(contains('password')));
      expect(datos, isNot(contains('salt')));
    } finally {
      client.dispose();
      await control.detener();
      await store.detenerServidor();
      await store.cerrarBaseDeDatos();
      store.dispose();
      await dir.delete(recursive: true);
    }
  });
}
