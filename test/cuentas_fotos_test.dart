import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:aplicacion_android/data/stockgo_store.dart';
import 'package:aplicacion_android/models/producto.dart';
import 'package:aplicacion_android/models/usuario.dart';

void main() {
  late StockGoStore store;
  setUpAll(() async {
    sqfliteFfiInit();
    store = StockGoStore(factory: databaseFactoryFfi);
    await store.inicializar(ruta: inMemoryDatabasePath);
  });
  tearDownAll(() async {
    await store.cerrarBaseDeDatos();
    store.dispose();
  });

  test('Una cuenta nueva puede iniciar sesión y cerrar su sesión', () async {
    store.cerrarSesion();
    await store.crearUsuario(
      'cuenta.nueva',
      'NuevaClave123!',
      nombres: 'Ana',
      apellidos: 'Perez',
    );
    expect(store.usuario, isNull);
    await store.iniciarSesion('CUENTA.NUEVA', 'NuevaClave123!');
    expect(store.usuario!.rol, Rol.vendedor);
    store.cerrarSesion();
    expect(store.usuario, isNull);
    await expectLater(
      store.buscarProductos(),
      throwsA(isA<StockGoException>()),
    );
    await expectLater(
      store.crearUsuario(
        'cuenta.nueva',
        'OtraClave123!',
        nombres: 'Ana',
        apellidos: 'Perez',
      ),
      throwsA(isA<StockGoException>()),
    );
  });

  test(
    'Solo un administrador puede crear otra cuenta administrativa',
    () async {
      store.cerrarSesion();
      await expectLater(
        store.crearUsuario(
          'nuevoadmin',
          'ClaveAdmin123!',
          rol: Rol.administrador,
          nombres: 'Ana',
          apellidos: 'Perez',
        ),
        throwsA(isA<StockGoException>()),
      );
      await store.iniciarSesion('admin', 'Admin123!');
      await store.crearUsuario(
        'nuevoadmin',
        'ClaveAdmin123!',
        rol: Rol.administrador,
        nombres: 'Ana',
        apellidos: 'Perez',
      );
      expect(store.usuario!.nombre, 'admin');
      store.cerrarSesion();
      await store.iniciarSesion('nuevoadmin', 'ClaveAdmin123!');
      expect(store.usuario!.puedeAdministrar, isTrue);
      await expectLater(
        store.crearUsuario('ab', 'corta', nombres: 'Ana', apellidos: 'Perez'),
        throwsA(isA<StockGoException>()),
      );
    },
  );

  test('La imagen se conserva al reabrir SQLite y puede quitarse', () async {
    final dir = await Directory.systemTemp.createTemp('stockgo_fotos_');
    final db = StockGoStore(factory: databaseFactoryFfi);
    final ruta = '${dir.path}/stockgo.db';
    final imagen = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jFzQAAAAASUVORK5CYII=',
    );
    try {
      await db.inicializar(ruta: ruta);
      await db.iniciarSesion('admin', 'Admin123!');
      final id = await db.guardarProducto(
        Producto(
          nombre: 'Con foto',
          codigo: 'FOTO-1',
          precio: 10,
          cantidad: 2,
          imagen: imagen,
        ),
      );
      await db.cerrarBaseDeDatos();
      await db.inicializar(ruta: ruta);
      await db.iniciarSesion('admin', 'Admin123!');
      expect(
        (await db.obtenerProductoPorId(id))!.imagen,
        orderedEquals(imagen),
      );
      await db.guardarProducto(
        Producto(
          id: id,
          nombre: 'Sin foto',
          codigo: 'FOTO-1',
          precio: 10,
          cantidad: 2,
        ),
      );
      expect((await db.obtenerProductoPorId(id))!.imagen, isNull);
    } finally {
      await db.cerrarBaseDeDatos();
      db.dispose();
      await dir.delete(recursive: true);
    }
  });

  test(
    'Migración 2 a 3 agrega fotos sin perder productos ni usuarios',
    () async {
      final dir = await Directory.systemTemp.createTemp('stockgo_v2_');
      final ruta = '${dir.path}/stockgo.db';
      final old = await databaseFactoryFfi.openDatabase(
        ruta,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, _) async {
            await db.execute(
              'CREATE TABLE usuarios (id INTEGER PRIMARY KEY, nombre TEXT, password_hash TEXT, salt TEXT, rol TEXT)',
            );
            await db.execute(
              'CREATE TABLE productos (id INTEGER PRIMARY KEY, nombre TEXT, codigo TEXT, precio REAL, cantidad INTEGER, activo INTEGER)',
            );
            await db.insert('usuarios', {
              'id': 5,
              'nombre': 'Anterior',
              'password_hash': 'igual',
              'salt': 'igual',
              'rol': 'vendedor',
            });
            await db.insert('productos', {
              'id': 8,
              'nombre': 'Anterior',
              'codigo': 'ANT',
              'precio': 5.5,
              'cantidad': 10,
              'activo': 1,
            });
          },
        ),
      );
      await old.close();
      final migrated = StockGoStore(factory: databaseFactoryFfi);
      try {
        await migrated.inicializar(ruta: ruta);
        migrated.entrarComoInvitado();
        final producto = (await migrated.buscarProductos()).single;
        expect(producto.id, 8);
        expect(producto.cantidad, 10);
        expect(producto.imagen, isNull);
        await migrated.cerrarBaseDeDatos();
        final check = await databaseFactoryFfi.openDatabase(ruta);
        try {
          expect((await check.query('usuarios')).single['id'], 5);
        } finally {
          await check.close();
        }
      } finally {
        await migrated.cerrarBaseDeDatos();
        migrated.dispose();
        await dir.delete(recursive: true);
      }
    },
  );
}
