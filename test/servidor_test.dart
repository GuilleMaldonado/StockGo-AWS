import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:aplicacion_android/data/stockgo_store.dart';
import 'package:aplicacion_android/models/producto.dart';
import 'package:aplicacion_android/models/usuario.dart';
import 'package:aplicacion_android/network/stockgo_lan_server.dart';

void main() {
  test(
    'Servidor PC/teléfono comparte fotos y aplica permisos por sesión',
    () async {
      sqfliteFfiInit();
      final dir = await Directory.systemTemp.createTemp('stockgo_red_');
      final server = StockGoLanServer(
        factory: databaseFactoryFfi,
        ruta: '${dir.path}/negocio.db',
      );
      final clients = List.generate(
        3,
        (_) => StockGoStore(factory: databaseFactoryFfi),
      );
      try {
        await server.iniciar(port: 0, address: InternetAddress.loopbackIPv4);
        final url = 'http://127.0.0.1:${server.puerto}';
        final admin = clients[0], seller = clients[1], guest = clients[2];
        await expectLater(
          admin.conectar(url),
          throwsA(isA<StockGoException>()),
        );
        final wrong = server.codigoConexion == '000000' ? '111111' : '000000';
        await expectLater(
          admin.conectar(url, codigo: wrong),
          throwsA(isA<StockGoException>()),
        );
        expect(admin.conectado, isFalse);
        final sinCodigo = await http.post(Uri.parse('$url/auth/guest'));
        expect(sinCodigo.statusCode, 403);
        for (final client in clients) {
          await client.conectar(url, codigo: server.codigoConexion);
        }
        await expectLater(
          admin.crearPropietario(
            'dueno',
            'ClaveDueno123!',
            codigoInicial: '000000',
            nombres: 'Ana',
            apellidos: 'Perez',
          ),
          throwsA(isA<StockGoException>()),
        );
        await admin.crearPropietario(
          'dueno',
          'ClaveDueno123!',
          codigoInicial: server.codigoInicial,
          nombres: 'Ana',
          apellidos: 'Perez',
        );
        await expectLater(
          admin.crearPropietario(
            'otro.dueno',
            'OtraClave123!',
            codigoInicial: server.codigoInicial,
            nombres: 'Ana',
            apellidos: 'Perez',
          ),
          throwsA(isA<StockGoException>()),
        );
        await admin.iniciarSesion('dueno', 'ClaveDueno123!');
        expect(admin.usuario!.rol, Rol.administrador);
        await admin.crearUsuario(
          'equipo',
          'ClaveEquipo123!',
          nombres: 'Ana',
          apellidos: 'Perez',
        );
        await seller.iniciarSesion('equipo', 'ClaveEquipo123!');
        await guest.entrarInvitado();
        expect(
          (await admin.listarUsuarios()).map((u) => u.nombre),
          containsAll(['dueno', 'equipo']),
        );
        for (final client in [seller, guest]) {
          await expectLater(
            client.listarUsuarios(),
            throwsA(isA<StockGoException>()),
          );
          await expectLater(
            client.codigosInvitacion(),
            throwsA(isA<StockGoException>()),
          );
        }
        expect(
          (await admin.codigosInvitacion()).values,
          everyElement(startsWith('SG1-')),
        );
        final bytes = base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jFzQAAAAASUVORK5CYII=',
        );
        final id = await admin.guardarProducto(
          Producto(
            nombre: 'Compartido',
            codigo: 'RED-1',
            precio: 10,
            cantidad: 15,
            imagen: bytes,
            categoria: 'Lubricante',
            ficha: {
              'marca': 'Mobil',
              'viscosidadSAE': '5W-30',
              'lote': 'MOBIL-A',
            },
            costo: 6.5,
            stockMinimo: 3,
          ),
        );
        expect(
          (await seller.buscarProductos()).single.imagen,
          orderedEquals(bytes),
        );
        expect((await guest.buscarProductos()).single.cantidad, 15);
        expect(
          (await seller.buscarProductos(busqueda: 'Mobil'))
              .single
              .ficha['viscosidadSAE'],
          '5W-30',
        );
        for (final client in [seller, guest]) {
          await expectLater(
            client.guardarProducto(
              const Producto(
                nombre: 'Prohibido',
                codigo: 'NO',
                precio: 1,
                cantidad: 1,
              ),
            ),
            throwsA(isA<StockGoException>()),
          );
          await expectLater(
            client.desactivarProducto(id),
            throwsA(isA<StockGoException>()),
          );
          await expectLater(
            client.crearUsuario(
              'admin.falso',
              'ClaveFalsa123!',
              rol: Rol.administrador,
              nombres: 'Ana',
              apellidos: 'Perez',
            ),
            throwsA(isA<StockGoException>()),
          );
        }
        final registro = await http.post(
          Uri.parse('$url/auth/register'),
          headers: {
            'Content-Type': 'application/json',
            'X-StockGo-Code': server.codigoConexion,
          },
          body: jsonEncode({
            'usuario': 'rol.falso',
            'nombres': 'Ana',
            'apellidos': 'Perez',
            'password': 'ClaveFalsa123!',
            'rol': 'administrador',
          }),
        );
        expect(registro.statusCode, 200);
        await seller.iniciarSesion('rol.falso', 'ClaveFalsa123!');
        expect(seller.usuario!.rol, Rol.vendedor);
        await admin.desactivarProducto(id);
        expect(await guest.buscarProductos(incluirInactivos: true), isEmpty);
        expect(
          (await admin.buscarProductos(incluirInactivos: true)).single.activo,
          isFalse,
        );
        guest.cerrarSesion();
        await expectLater(
          guest.buscarProductos(),
          throwsA(isA<StockGoException>()),
        );
      } finally {
        for (final client in clients) {
          client.dispose();
        }
        await server.detener();
        final db = await databaseFactoryFfi.openDatabase(
          '${dir.path}/negocio.db',
        );
        await db.close();
        await dir.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
