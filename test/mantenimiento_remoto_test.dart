import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:aplicacion_android/data/stockgo_store.dart';
import 'package:aplicacion_android/data/stockgo_repository.dart';
import 'package:aplicacion_android/models/producto.dart';
import 'package:aplicacion_android/models/venta.dart';
import 'package:aplicacion_android/network/codigo_negocio.dart';
import 'package:aplicacion_android/network/local_host.dart';
import 'package:aplicacion_android/network/stockgo_api.dart';
import 'package:aplicacion_android/network/stockgo_lan_server.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  test('VPN requiere código explícito y no habilita HTTP público', () {
    const id = '43956F651D95419F2695D5F57DA93E81';
    expect(esHostTunel('100.64.0.1'), true);
    expect(esHostTunel('100.127.255.255'), true);
    for (final host in [
      '100.63.0.1',
      '100.128.0.1',
      '100.999.0.1',
      '100.64.example.com',
    ]) {
      expect(esHostTunel(host), false);
    }
    expect(
      () => StockGoApi('http://100.64.0.1:8081'),
      throwsA(isA<StockGoException>()),
    );
    final codigo = const CodigoNegocio(
      'http://100.64.0.1:8081',
      id,
      vpn: true,
    ).codificar();
    final datos = CodigoNegocio.leer(codigo);
    expect(datos.vpn, true);
    expect(datos.identificador, id);
    final api = StockGoApi(datos.direccion, permitirVPN: datos.vpn)..dispose();
    expect(api.base.host, '100.64.0.1');
    expect(
      () => StockGoApi('http://8.8.8.8', permitirVPN: true),
      throwsA(isA<StockGoException>()),
    );
    expect(
      CodigoNegocio.leer(
        const CodigoNegocio('http://192.168.0.2:8081', id).codificar(),
      ).vpn,
      false,
    );
  });

  test('Restablecimiento autorizado, cambio obligatorio, revocación y costos privados por red', () async {
    final dir = await Directory.systemTemp.createTemp('stockgo_mantenimiento_');
    final ruta = '${dir.path}/negocio.db';
    final repo = StockGoRepository(factory: databaseFactoryFfi);
    final sesionLocal = StockGoRepository(factory: databaseFactoryFfi);
    final server = StockGoLanServer(factory: databaseFactoryFfi, ruta: ruta);
    final admin = StockGoStore(factory: databaseFactoryFfi);
    final seller = StockGoStore(factory: databaseFactoryFfi);
    final guest = StockGoStore(factory: databaseFactoryFfi);
    try {
      await repo.inicializar(ruta: ruta, crearUsuariosDemo: false);
      await repo.crearPropietario(
        'dueno',
        'Dueno123!',
        nombres: 'Ana',
        apellidos: 'Perez',
      );
      await repo.iniciarSesion('dueno', 'Dueno123!');
      await repo.crearUsuario(
        'vendedor.uno',
        'Inicial123!',
        nombres: 'Luis',
        apellidos: 'Lopez',
      );
      final id = (await repo.listarUsuarios())
          .firstWhere((u) => u.nombre == 'vendedor.uno')
          .id;
      await repo.guardarProducto(
        const Producto(
          nombre: 'Filtro',
          codigo: 'F-001',
          precio: 10,
          costo: 6,
          cantidad: 5,
          ficha: {'proveedor': 'Proveedor privado'},
        ),
      );
      await sesionLocal.inicializar(ruta: ruta, crearUsuariosDemo: false);
      await sesionLocal.iniciarSesion('vendedor.uno', 'Inicial123!');
      await server.iniciar(port: 0, address: InternetAddress.loopbackIPv4);
      final url = 'http://127.0.0.1:${server.puerto}';
      for (final cliente in [admin, seller, guest]) {
        await cliente.conectar(url, codigo: server.codigoConexion);
      }
      await admin.iniciarSesion('dueno', 'Dueno123!');
      await seller.iniciarSesion('vendedor.uno', 'Inicial123!');
      await guest.entrarInvitado();
      expect((await admin.buscarProductos()).single.costo, 6);
      expect((await seller.buscarProductos()).single.costo, 0);
      expect((await guest.buscarProductos()).single.costo, 0);
      expect((await guest.buscarProductos()).single.ficha['proveedor'], '');
      final producto = (await admin.buscarProductos()).single;
      final venta = await seller.registrarVenta([
        LineaVenta(productoId: producto.id!, cantidad: 1),
      ], 'venta_costos_privados_001');
      expect(venta.detalles.single.containsKey('costoCentavos'), false);
      expect(
        (await seller.listarVentas()).single.detalles.single.containsKey(
          'costoCentavos',
        ),
        false,
      );
      expect(
        (await admin.listarVentas()).single.detalles.single['costoCentavos'],
        600,
      );
      await expectLater(
        guest.restablecerPassword(id, 'Dueno123!'),
        throwsA(isA<StockGoException>()),
      );
      await expectLater(
        admin.restablecerPassword(id, 'Incorrecta'),
        throwsA(isA<StockGoException>()),
      );
      final temporal = await admin.restablecerPassword(id, 'Dueno123!');
      expect(temporal.length, greaterThan(20));
      await expectLater(
        seller.buscarProductos(),
        throwsA(isA<StockGoException>()),
      );
      await expectLater(
        sesionLocal.buscarProductos(),
        throwsA(isA<StockGoException>()),
      );
      await expectLater(
        seller.iniciarSesion('vendedor.uno', 'Inicial123!'),
        throwsA(isA<StockGoException>()),
      );
      await seller.iniciarSesion('vendedor.uno', temporal);
      expect(seller.usuario!.requiereCambioPassword, true);
      await expectLater(
        seller.buscarProductos(),
        throwsA(isA<StockGoException>()),
      );
      await seller.cambiarPassword(temporal, 'Personal123!');
      expect(seller.usuario!.requiereCambioPassword, false);
      expect((await seller.buscarProductos()).single.nombre, 'Filtro');
      await expectLater(
        seller.iniciarSesion('vendedor.uno', temporal),
        throwsA(isA<StockGoException>()),
      );
      final eventos = await admin.listarAuditoria();
      expect(
        eventos.map((e) => e['accion']),
        containsAll(['restablecer_password', 'cambiar_password']),
      );
      expect(jsonEncode(eventos), isNot(contains(temporal)));
      expect(jsonEncode(eventos), isNot(contains('Personal123!')));
      await expectLater(
        seller.listarAuditoria(),
        throwsA(isA<StockGoException>()),
      );
      // Restablecer otra vez no permite reutilizar la temporal anterior.
      final nueva = await admin.restablecerPassword(id, 'Dueno123!');
      expect(nueva, isNot(temporal));
      await expectLater(
        seller.buscarProductos(),
        throwsA(isA<StockGoException>()),
      );
      final db = await databaseFactoryFfi.openDatabase(ruta);
      await db.update(
        'usuarios',
        {'temporalHasta': '2000-01-01T00:00:00Z'},
        where: 'id = ?',
        whereArgs: [id],
      );
      await expectLater(
        seller.iniciarSesion('vendedor.uno', nueva),
        throwsA(isA<StockGoException>()),
      );
      // No se requieren contraseñas reales para comprobar el límite de acceso.
      int status = 0;
      for (var i = 0; i < 11; i++) {
        final respuesta = await http.post(
          Uri.parse('$url/auth/register'),
          headers: {
            'Content-Type': 'application/json',
            'X-StockGo-Code': server.codigoConexion,
          },
          body: '{}',
        );
        status = respuesta.statusCode;
      }
      expect(status, 429);
    } finally {
      for (final store in [admin, seller, guest]) {
        store.dispose();
      }
      await server.detener();
      await sesionLocal.cerrarBaseDeDatos();
      await repo.cerrarBaseDeDatos();
      await dir.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('Migración de v9 conserva cuentas y permite recuperación', () async {
    final ruta = inMemoryDatabasePath;
    final db = await databaseFactoryFfi.openDatabase(
      ruta,
      options: OpenDatabaseOptions(
        version: 9,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE usuarios (id INTEGER PRIMARY KEY, nombre TEXT, password_hash TEXT, salt TEXT, rol TEXT, nombres TEXT, apellidos TEXT, codigoInterno TEXT)',
          );
          await db.insert('usuarios', {
            'id': 7,
            'nombre': 'cuenta.anterior',
            'rol': 'vendedor',
          });
        },
      ),
    );
    // Un archivo temporal conserva la base entre aperturas para probar onUpgrade.
    final dir = await Directory.systemTemp.createTemp('stockgo_migracion10_');
    final archivo = '${dir.path}/v9.db';
    await db.execute("VACUUM INTO '${archivo.replaceAll("'", "''")}'");
    await db.close();
    final repo = StockGoRepository(factory: databaseFactoryFfi);
    try {
      await repo.inicializar(ruta: archivo, crearUsuariosDemo: false);
      final migrated = await databaseFactoryFfi.openDatabase(archivo);
      expect(await migrated.getVersion(), 10);
      final row = (await migrated.query('usuarios')).single;
      expect(row['nombre'], 'cuenta.anterior');
      expect(row['versionCredencial'], 0);
      expect(row['requiereCambioPassword'], 0);
      expect(await migrated.query('auditoria_seguridad'), isEmpty);
    } finally {
      await repo.cerrarBaseDeDatos();
      await dir.delete(recursive: true);
    }
  });
}
