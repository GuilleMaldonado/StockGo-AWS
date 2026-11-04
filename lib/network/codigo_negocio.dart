import 'dart:convert';

import '../data/stockgo_repository.dart';
import 'stockgo_api.dart';

/// Paquete de conexión: dirección actual y identidad persistente del negocio.
class CodigoNegocio {
  const CodigoNegocio(this.direccion, this.identificador, {this.vpn = false});
  final String direccion;
  final String identificador;
  final bool vpn;
  String codificar() =>
      'SG1-${base64UrlEncode(utf8.encode(jsonEncode({'url': direccion, 'negocio': identificador, if (vpn) 'vpn': true}))).replaceAll('=', '')}';
  static CodigoNegocio leer(String texto) {
    try {
      final limpio = texto.trim();
      if (!limpio.startsWith('SG1-') || limpio.length > 1024) {
        throw const FormatException();
      }
      final data = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(limpio.substring(4)))),
      ) as Map;
      final url = data['url'] as String;
      final id = data['negocio'] as String;
      if (!RegExp(r'^[A-F0-9]{32}$').hasMatch(id)) {
        throw const FormatException();
      }
      final vpn = data['vpn'] == true;
      final api = StockGoApi(url, permitirVPN: vpn);
      api.dispose();
      return CodigoNegocio(url, id, vpn: vpn);
    } on StockGoException {
      rethrow;
    } catch (_) {
      throw const StockGoException(
        'Código de negocio inválido. Copia el código completo que empieza con SG1- desde el dispositivo maestro.',
      );
    }
  }
}
