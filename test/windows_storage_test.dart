import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:aplicacion_android/data/platform/windows_storage.dart';

void main() {
  test('La instalación conserva negocios y sus datos fuera del programa', () async {
    sqfliteFfiInit();
    final factory = databaseFactoryFfi;
    final anteriorPath = await factory.getDatabasesPath();
    final root = await Directory.systemTemp.createTemp('stockgo-storage-test-');
    final legacy = p.join(root.path, 'antiguo');
    final destino = p.join(root.path, 'datos');
    await Directory(legacy).create();
    final negocioPath = p.join(legacy, 'stockgo.db_negocio_1.db');
    final negocio = await factory.openDatabase(negocioPath);
    await negocio.execute(
      'CREATE TABLE productos (nombre TEXT, cantidad INTEGER)',
    );
    await negocio.insert('productos', {
      'nombre': 'Aceite prueba',
      'cantidad': 7,
    });
    await negocio.close();
    final catalogo = await factory.openDatabase(p.join(legacy, 'stockgo.db'));
    await catalogo.execute(
      'CREATE TABLE negocios (id INTEGER PRIMARY KEY, nombre TEXT, ruta TEXT)',
    );
    await catalogo.insert('negocios', {
      'id': 1,
      'nombre': 'Empresa prueba',
      'ruta': negocioPath,
    });
    await catalogo.close();
    try {
      await prepararDatosWindows(factory, destino: destino, anterior: legacy);
      final nuevo = await factory.openDatabase(p.join(destino, 'stockgo.db'));
      final registros = await nuevo.query('negocios');
      expect(registros.single['nombre'], 'Empresa prueba');
      expect(
        registros.single['ruta'],
        p.join(destino, 'stockgo.db_negocio_1.db'),
      );
      await nuevo.close();
      final inventario = await factory.openDatabase(
        registros.single['ruta'] as String,
      );
      expect((await inventario.query('productos')).single['cantidad'], 7);
      await inventario.insert('productos', {'nombre': 'Nuevo', 'cantidad': 2});
      await inventario.close();
      await prepararDatosWindows(factory, destino: destino, anterior: legacy);
      final conservado = await factory.openDatabase(
        registros.single['ruta'] as String,
      );
      expect((await conservado.query('productos')).length, 2);
      await conservado.close();
      expect(File(p.join(legacy, 'stockgo.db')).existsSync(), isTrue);
    } finally {
      await factory.setDatabasesPath(anteriorPath);
      // Only the unique temporary directory created by this test is removed.
      await root.delete(recursive: true);
    }
  });
}
