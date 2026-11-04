import 'dart:io';

import 'package:path/path.dart' as p;

import 'windows_storage.dart';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' as mobile;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<DatabaseFactory> crearDatabaseFactory() async {
  if (defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux) {
    sqfliteFfiInit();
    if (defaultTargetPlatform == TargetPlatform.windows) {
      final local = Platform.environment['LOCALAPPDATA'];
      if (local == null) {
        throw StateError('Windows no proporcionó LOCALAPPDATA.');
      }
      await prepararDatosWindows(
        databaseFactoryFfi,
        destino: p.join(local, 'StockGo', 'databases'),
        anterior: await databaseFactoryFfi.getDatabasesPath(),
      );
    }
    return databaseFactoryFfi;
  }
  return mobile.databaseFactory;
}
