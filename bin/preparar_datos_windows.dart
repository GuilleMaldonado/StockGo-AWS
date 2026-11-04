import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:aplicacion_android/data/platform/windows_storage.dart';

Future<void> main() async {
  if (!Platform.isWindows) throw UnsupportedError('Solo Windows');
  sqfliteFfiInit();
  final local = Platform.environment['LOCALAPPDATA']!;
  await prepararDatosWindows(
    databaseFactoryFfi,
    destino: p.join(local, 'StockGo', 'databases'),
    anterior: await databaseFactoryFfi.getDatabasesPath(),
  );
  stdout.writeln(
    'Datos de StockGo preparados. Las bases originales se conservaron.',
  );
}
