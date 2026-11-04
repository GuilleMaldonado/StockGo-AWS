import 'package:sqflite_common/sqlite_api.dart';

import 'stockgo_lan_server.dart';

class StockGoHost {
  StockGoHost({required DatabaseFactory factory, required String ruta})
    : _server = StockGoLanServer(factory: factory, ruta: ruta);
  final StockGoLanServer _server;
  String? get codigoConexion => _server.activo ? _server.codigoConexion : null;
  bool get activo => _server.activo;
  Future<List<String>> iniciar() => _server.iniciar();
  Future<void> detener() => _server.detener();
}
