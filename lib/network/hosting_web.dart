import 'package:sqflite_common/sqlite_api.dart';

import '../data/stockgo_repository.dart';

class StockGoHost {
  StockGoHost({required DatabaseFactory factory, required String ruta});
  String? get codigoConexion => null;
  bool get activo => false;
  Future<List<String>> iniciar() async => throw const StockGoException(
    'El navegador puede conectarse a un servidor. Para alojarlo usa la app Android/iOS o el servidor de PC.',
  );
  Future<void> detener() async {}
}
