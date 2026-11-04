import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:aplicacion_android/data/stockgo_store.dart';
import 'package:aplicacion_android/models/producto.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  test('Varios negocios: nombres únicos, usuarios e inventarios separados y persistentes', () async {
    final dir = await Directory.systemTemp.createTemp('stockgo_negocios_');
    final path = '${dir.path}/catalogo.db';
    final store = StockGoStore(factory: databaseFactoryFfi);
    final reopened = StockGoStore(factory: databaseFactoryFfi);
    try {
      await store.inicializar(ruta: path);
      await store.crearPropietario(
        'propietario',
        'ClaveSegura123!',
        nombreNegocio: 'Aceitera Central',
        nombres: 'Ana',
        apellidos: 'Perez',
      );
      final first = store.negocioSeleccionado!;
      await store.iniciarSesion('propietario', 'ClaveSegura123!');
      await store.guardarProducto(
        const Producto(
          nombre: 'Aceite sintético',
          codigo: 'ACE-1',
          precio: 100,
          cantidad: 8,
          categoria: 'Lubricante',
          costo: 70,
          stockMinimo: 2,
          ficha: {
            'marca': 'Castrol',
            'lote': 'CASTROL-A',
            'tipo': 'Aceite de motor',
            'unidadVenta': 'Botella',
            'viscosidadSAE': '5W-30',
            'normaAPI': 'Según etiqueta',
            'presentacion': '1 L',
          },
        ),
      );
      store.cerrarSesion();
      await expectLater(
        store.crearPropietario(
          'otro',
          'ClaveSegura123!',
          nombreNegocio: '  ACEITERA   CENTRAL  ',
          nombres: 'Ana',
          apellidos: 'Perez',
        ),
        throwsA(isA<StockGoException>()),
      );
      await store.crearPropietario(
        'propietario',
        'OtraClave123!',
        nombreNegocio: 'Repuestos del Sur',
        nombres: 'Ana',
        apellidos: 'Perez',
      );
      final second = store.negocioSeleccionado!;
      expect(second, isNot(first));
      await expectLater(
        store.iniciarSesion('propietario', 'ClaveSegura123!'),
        throwsA(isA<StockGoException>()),
      );
      await store.iniciarSesion('propietario', 'OtraClave123!');
      expect(await store.buscarProductos(), isEmpty);
      await store.guardarProducto(
        const Producto(
          nombre: 'Bujía',
          codigo: 'ACE-1',
          precio: 35,
          cantidad: 12,
          ficha: {
            'marca': 'NGK',
            'calibre': '14 mm',
            'compatibilidad': 'Aplicación verificada en catálogo',
          },
        ),
      );
      store.cerrarSesion();
      await store.seleccionarNegocio(first);
      await store.iniciarSesion('propietario', 'ClaveSegura123!');
      final oil = (await store.buscarProductos(busqueda: 'Castrol')).single;
      expect(oil.nombre, 'Aceite sintético');
      expect(oil.ficha['viscosidadSAE'], '5W-30');
      expect(oil.costo, 70);
      expect(oil.stockMinimo, 2);
      await expectLater(
        store.seleccionarNegocio(second),
        throwsA(isA<StockGoException>()),
      );
      store.cerrarSesion();
      await store.cerrarBaseDeDatos();
      await reopened.inicializar(ruta: path);
      expect(reopened.negocios.length, 2);
      await reopened.seleccionarNegocio(second);
      await reopened.iniciarSesion('propietario', 'OtraClave123!');
      expect(
        (await reopened.buscarProductos()).single.ficha['calibre'],
        '14 mm',
      );
    } finally {
      store.dispose();
      reopened.dispose();
      await store.cerrarBaseDeDatos();
      await reopened.cerrarBaseDeDatos();
      await dir.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('Migración 4 a 10 conserva el producto y foto y agrega ficha, ventas y seguridad', () async {
    final dir = await Directory.systemTemp.createTemp('stockgo_migracion_');
    final path = '${dir.path}/old.db';
    final old = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 4,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE usuarios(id INTEGER PRIMARY KEY, nombre TEXT, password_hash TEXT, salt TEXT, rol TEXT)',
          );
          await db.execute(
            'CREATE TABLE configuracion(clave TEXT PRIMARY KEY, valor TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE productos(id INTEGER PRIMARY KEY, nombre TEXT, codigo TEXT, precio REAL, cantidad INTEGER, activo INTEGER, imagen BLOB)',
          );
          await db.insert('productos', {
            'id': 1,
            'nombre': 'Filtro existente',
            'codigo': 'F-1',
            'precio': 20.0,
            'cantidad': 5,
            'activo': 1,
            'imagen': Uint8List.fromList([1, 2, 3]),
          });
        },
      ),
    );
    await old.close();
    final store = StockGoStore(factory: databaseFactoryFfi);
    try {
      await store.inicializar(ruta: path);
      store.entrarComoInvitado();
      final product = (await store.buscarProductos()).single;
      expect(product.nombre, 'Filtro existente');
      expect(product.imagen, orderedEquals([1, 2, 3]));
      expect(product.categoria, 'Repuesto');
      expect(product.ficha['marca'], '');
      final db = await databaseFactoryFfi.openDatabase(path);
      expect(await db.getVersion(), 10);
      expect(
        (await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type = 'table'",
        )).map((r) => r['name']),
        containsAll(['ventas', 'venta_detalles']),
      );
      final columns = (await db.rawQuery('PRAGMA table_info(productos)'))
          .map((r) => r['name']);
      expect(
        columns,
        containsAll([
          'marca',
          'tipo',
          'calibre',
          'viscosidadSAE',
          'compatibilidad',
          'costo',
          'stockMinimo',
        ]),
      );
    } finally {
      store.dispose();
      await store.cerrarBaseDeDatos();
      await dir.delete(recursive: true);
    }
  });
}
