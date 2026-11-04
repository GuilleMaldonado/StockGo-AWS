import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:aplicacion_android/data/stockgo_store.dart';
import 'package:aplicacion_android/data/stockgo_repository.dart';
import 'package:aplicacion_android/network/codigo_negocio.dart';
import 'package:aplicacion_android/network/stockgo_lan_server.dart';
import 'package:aplicacion_android/models/producto.dart';

void main() {
  test('Código de negocio conecta vendedores al maestro correcto y persiste al reiniciar', () async {
    sqfliteFfiInit();
    final dir = await Directory.systemTemp.createTemp('stockgo_empresas_');
    final servers = <StockGoLanServer>[];
    final repos = <StockGoRepository>[];
    final clients = <StockGoStore>[];
    try {
      for (var i = 0; i < 2; i++) {
        final repo = StockGoRepository(factory: databaseFactoryFfi);
        repos.add(repo);
        final path = '${dir.path}/empresa_$i.db';
        await repo.inicializar(ruta: path, crearUsuariosDemo: false);
        await repo.crearPropietario(
          'dueno',
          'DuenoClave123!',
          nombres: 'Ana',
          apellidos: 'Perez',
        );
        await repo.asignarNombreNegocio('Empresa $i');
        await repo.iniciarSesion('dueno', 'DuenoClave123!');
        await repo.crearUsuario(
          'vendedor',
          'VendedorClave123!',
          nombres: 'Ana',
          apellidos: 'Perez',
        );
        await repo.guardarProducto(
          Producto(
            nombre: 'Producto $i',
            codigo: 'P-$i',
            precio: 10,
            cantidad: i + 1,
          ),
        );
        final server = StockGoLanServer(
          factory: databaseFactoryFfi,
          ruta: path,
        );
        servers.add(server);
        await server.iniciar(port: 0, address: InternetAddress.loopbackIPv4);
        final code = CodigoNegocio(
          'http://127.0.0.1:${server.puerto}',
          server.codigoConexion,
        ).codificar();
        final client = StockGoStore(factory: databaseFactoryFfi);
        clients.add(client);
        await expectLater(
          client.entrarConCodigo(code, 'vendedor', 'Incorrecta123!'),
          throwsA(isA<StockGoException>()),
        );
        expect(client.conectado, isFalse);
        expect(client.usuario, isNull);
        await client.entrarConCodigo(code, 'vendedor', 'VendedorClave123!');
        expect(client.nombreNegocio, 'Empresa $i');
        expect((await client.buscarProductos()).single.nombre, 'Producto $i');
        await expectLater(
          client.guardarProducto(
            const Producto(nombre: 'No', codigo: 'NO', precio: 1, cantidad: 1),
          ),
          throwsA(isA<StockGoException>()),
        );
      }
      expect(servers[0].codigoConexion, isNot(servers[1].codigoConexion));
      final otro = StockGoStore(factory: databaseFactoryFfi);
      clients.add(otro);
      final incorrecto = CodigoNegocio(
        'http://127.0.0.1:${servers[1].puerto}',
        servers[0].codigoConexion,
      ).codificar();
      await expectLater(
        otro.entrarConCodigo(incorrecto, 'vendedor', 'VendedorClave123!'),
        throwsA(isA<StockGoException>()),
      );
      expect(otro.conectado, isFalse);
      final identidad = servers[0].codigoConexion;
      await servers[0].detener();
      await servers[0].iniciar(port: 0, address: InternetAddress.loopbackIPv4);
      expect(servers[0].codigoConexion, identidad);
      await otro.conectarConCodigo(
        CodigoNegocio(
          'http://127.0.0.1:${servers[0].puerto}',
          identidad,
        ).codificar(),
      );
      expect(otro.nombreNegocio, 'Empresa 0');
      final direccionAnterior = otro.direccionServidor;
      await expectLater(
        otro.entrarConCodigo(
          CodigoNegocio(
            'http://127.0.0.1:${servers[1].puerto}',
            servers[1].codigoConexion,
          ).codificar(),
          'vendedor',
          'Incorrecta123!',
        ),
        throwsA(isA<StockGoException>()),
      );
      expect(otro.nombreNegocio, 'Empresa 0');
      expect(otro.direccionServidor, direccionAnterior);
      expect(otro.usuario, isNull);
    } finally {
      for (final client in clients) {
        client.dispose();
      }
      for (final server in servers) {
        await server.detener();
      }
      for (final repo in repos) {
        await repo.cerrarBaseDeDatos();
      }
      await dir.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
  test('Código inválido o dirigido a HTTP público se rechaza', () {
    expect(
      () => CodigoNegocio.leer('123456'),
      throwsA(isA<StockGoException>()),
    );
    expect(
      () => CodigoNegocio.leer(
        CodigoNegocio('http://example.com', 'A' * 32).codificar(),
      ),
      throwsA(isA<StockGoException>()),
    );
  });
}
