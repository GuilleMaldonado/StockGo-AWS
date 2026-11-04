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

  test(
    'Login rechaza credenciales incorrectas y obtiene el rol de SQLite',
    () async {
      store.cerrarSesion();
      await expectLater(
        store.iniciarSesion('admin', 'incorrecta'),
        throwsA(isA<StockGoException>()),
      );
      expect(store.usuario, isNull);
      await store.iniciarSesion('ADMIN', 'Admin123!');
      expect(store.usuario!.rol, Rol.administrador);
    },
  );

  test(
    'Admin registra, busca, edita y desactiva sin borrar el historial',
    () async {
      await store.iniciarSesion('admin', 'Admin123!');
      final id = await store.guardarProducto(
        const Producto(
          nombre: 'Cuaderno',
          codigo: 'cuad-001',
          precio: 15.5,
          cantidad: 20,
        ),
      );
      final encontrados = await store.buscarProductos(busqueda: 'Cuad');
      expect(encontrados.single.id, id);
      expect(encontrados.single.codigo, 'CUAD-001');
      expect((await store.buscarProductos(busqueda: 'cuad-001')).single.id, id);
      await store.guardarProducto(
        Producto(
          id: id,
          nombre: 'Cuaderno grande',
          codigo: 'CUAD-001',
          precio: 18.5,
          cantidad: 30,
        ),
      );
      expect((await store.obtenerProductoPorId(id))!.cantidad, 30);
      await store.desactivarProducto(id);
      expect(await store.buscarProductos(busqueda: 'CUAD-001'), isEmpty);
      expect((await store.obtenerProductoPorId(id))!.activo, isFalse);
      expect(
        (await store.buscarProductos(
          busqueda: 'CUAD-001',
          incluirInactivos: true,
        )).single.id,
        id,
      );
      await expectLater(
        store.guardarProducto(
          const Producto(
            nombre: 'Otro',
            codigo: 'cuad-001',
            precio: 2,
            cantidad: 1,
          ),
        ),
        throwsA(isA<StockGoException>()),
      );
      await expectLater(
        store.guardarProducto(
          Producto(
            id: id,
            nombre: 'Reactivar',
            codigo: 'CUAD-001',
            precio: 2,
            cantidad: 1,
          ),
        ),
        throwsA(isA<StockGoException>()),
      );
    },
  );

  test(
    'Vendedor e invitado pueden consultar pero no escribir ni ver inactivos',
    () async {
      await store.iniciarSesion('admin', 'Admin123!');
      final id = await store.guardarProducto(
        const Producto(
          nombre: 'Solo lectura',
          codigo: 'LECT-001',
          precio: 1,
          cantidad: 2,
        ),
      );
      final inactiveId = await store.guardarProducto(
        const Producto(
          nombre: 'Historial',
          codigo: 'HIST-001',
          precio: 1,
          cantidad: 2,
        ),
      );
      await store.desactivarProducto(inactiveId);
      for (final rol in [Rol.vendedor, Rol.invitado]) {
        if (rol == Rol.vendedor) {
          await store.iniciarSesion('vendedor', 'Vendedor123!');
        } else {
          store.entrarComoInvitado();
        }
        expect(
          (await store.buscarProductos(busqueda: 'LECT-001')).single.id,
          id,
        );
        expect(await store.obtenerProductoPorId(inactiveId), isNull);
        expect(
          await store.buscarProductos(
            busqueda: 'HIST-001',
            incluirInactivos: true,
          ),
          isEmpty,
        );
        await expectLater(
          store.guardarProducto(
            const Producto(
              nombre: 'No autorizado',
              codigo: 'NO',
              precio: 1,
              cantidad: 1,
            ),
          ),
          throwsA(isA<StockGoException>()),
        );
        await expectLater(
          store.guardarProducto(
            Producto(
              id: id,
              nombre: 'No autorizado',
              codigo: 'LECT-001',
              precio: 1,
              cantidad: 1,
            ),
          ),
          throwsA(isA<StockGoException>()),
        );
        await expectLater(
          store.desactivarProducto(id),
          throwsA(isA<StockGoException>()),
        );
      }
      store.cerrarSesion();
      await expectLater(
        store.buscarProductos(),
        throwsA(isA<StockGoException>()),
      );
    },
  );

  test('Valida datos y busca caracteres SQL como texto literal', () async {
    await store.iniciarSesion('admin', 'Admin123!');
    await expectLater(
      store.guardarProducto(
        const Producto(nombre: '', codigo: 'VACIO', precio: -1, cantidad: -1),
      ),
      throwsA(isA<StockGoException>()),
    );
    await store.guardarProducto(
      const Producto(
        nombre: 'Descuento 10%_especial',
        codigo: 'PROMO',
        precio: 0,
        cantidad: 0,
      ),
    );
    expect(
      (await store.buscarProductos(busqueda: '%_')).single.codigo,
      'PROMO',
    );
    expect(await store.buscarProductos(busqueda: "' OR 1=1 --"), isEmpty);
  });

  test('Los productos persisten al cerrar y reabrir SQLite', () async {
    final dir = await Directory.systemTemp.createTemp('stockgo_persistencia_');
    final ruta = '${dir.path}/stockgo.db';
    final local = StockGoStore(factory: databaseFactoryFfi);
    try {
      await local.inicializar(ruta: ruta);
      await local.iniciarSesion('admin', 'Admin123!');
      final id = await local.guardarProducto(
        const Producto(
          nombre: 'Persistente',
          codigo: 'PERSISTE',
          precio: 12.5,
          cantidad: 8,
        ),
      );
      await local.cerrarBaseDeDatos();
      local.cerrarSesion();
      await local.inicializar(ruta: ruta);
      await local.iniciarSesion('admin', 'Admin123!');
      final producto = await local.obtenerProductoPorId(id);
      expect(producto!.nombre, 'Persistente');
      expect(producto.cantidad, 8);
    } finally {
      await local.cerrarBaseDeDatos();
      local.dispose();
      await dir.delete(recursive: true);
    }
  });

  test('La migración SQLite 1 a 10 conserva usuarios y agrega productos, ventas y seguridad', () async {
    final dir = await Directory.systemTemp.createTemp('stockgo_migracion_');
    final ruta = '${dir.path}/stockgo.db';
    final oldDb = await databaseFactoryFfi.openDatabase(
      ruta,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE usuarios (id INTEGER PRIMARY KEY, nombre TEXT, '
            'password_hash TEXT, salt TEXT, rol TEXT)',
          );
          await db.insert('usuarios', {
            'id': 17,
            'nombre': 'Existente',
            'password_hash': 'conservar',
            'salt': 'conservar',
            'rol': 'administrador',
          });
        },
      ),
    );
    await oldDb.close();
    final migrated = StockGoStore(factory: databaseFactoryFfi);
    try {
      await migrated.inicializar(ruta: ruta);
      migrated.entrarComoInvitado();
      expect(await migrated.buscarProductos(), isEmpty);
      await migrated.cerrarBaseDeDatos();
      final db = await databaseFactoryFfi.openDatabase(ruta);
      try {
        expect(await db.getVersion(), 10);
        final usuarios = await db.query('usuarios');
        expect(usuarios.single['id'], 17);
        expect(usuarios.single['password_hash'], 'conservar');
      } finally {
        await db.close();
      }
    } finally {
      await migrated.cerrarBaseDeDatos();
      migrated.dispose();
      await dir.delete(recursive: true);
    }
  });
}
