import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_common/sqlite_api.dart';

/// Keeps installed application updates separate from the user's databases.
Future<void> prepararDatosWindows(
  DatabaseFactory factory, {
  required String destino,
  required String anterior,
}) async {
  final catalogo = p.join(destino, 'stockgo.db');
  final origen = p.join(anterior, 'stockgo.db');
  if (!File(catalogo).existsSync() &&
      File(origen).existsSync() &&
      !p.equals(p.absolute(destino), p.absolute(anterior))) {
    await Directory(p.dirname(destino)).create(recursive: true);
    final temporal = await Directory(p.dirname(destino))
        .createTemp('migracion-');
    Future<void> copiar(String desde, String hasta) async {
      final db = await factory.openDatabase(
        desde,
        options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
      );
      try {
        // SQLite snapshots include committed WAL contents; copying files does not.
        await db.execute('VACUUM INTO ?', [hasta]);
      } finally {
        await db.close();
      }
    }

    await copiar(origen, p.join(temporal.path, 'stockgo.db'));
    final db = await factory.openDatabase(p.join(temporal.path, 'stockgo.db'));
    try {
      final tablas = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'negocios'",
      );
      if (tablas.isNotEmpty) {
        for (final negocio in await db.query('negocios')) {
          final id = negocio['id'] as int;
          final desde = negocio['ruta'] as String;
          final nombre = 'stockgo.db_negocio_$id.db';
          if (!File(desde).existsSync()) {
            throw StateError(
              'No se encontró la base de datos del negocio $id.',
            );
          }
          await copiar(desde, p.join(temporal.path, nombre));
          await db.update(
            'negocios',
            {'ruta': p.join(destino, nombre)},
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      }
    } finally {
      await db.close();
    }
    if (Directory(destino).existsSync()) {
      // Never overwrite an existing database or remove user files.
      if (await Directory(destino).list().isEmpty) {
        await Directory(destino).delete();
      } else {
        throw StateError(
          'La carpeta de datos contiene archivos; se conserva la copia en ${temporal.path}.',
        );
      }
    }
    await temporal.rename(destino);
  }
  await Directory(destino).create(recursive: true);
  await factory.setDatabasesPath(destino);
}
