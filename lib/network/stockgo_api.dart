import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/stockgo_repository.dart';
import 'local_host.dart';

class StockGoApi {
  StockGoApi(String direccion, {bool permitirVPN = false})
    : base = _validar(direccion, permitirVPN);
  final Uri base;
  final http.Client _client = http.Client();
  String? token;
  String codigoConexion = '';

  static Uri _validar(String direccion, bool permitirVPN) {
    final uri = Uri.tryParse(direccion.trim());
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw const StockGoException(
        'Ingresa la dirección del servidor, por ejemplo http://192.168.1.20:8081',
      );
    }
    if (uri.scheme == 'http') {
      final privado = esHostLocal(uri.host);
      if (!privado && !(permitirVPN && esHostTunel(uri.host))) {
        throw const StockGoException(
          'HTTP solo se permite dentro de tu red privada. Para Internet usa HTTPS.',
        );
      }
    }
    return uri.replace(path: '/');
  }

  Future<Map<String, dynamic>> pedir(
    String metodo,
    String ruta, [
    Map<String, Object?>? body,
  ]) async {
    try {
      final request = http.Request(metodo, base.resolve(ruta));
      request.headers['Content-Type'] = 'application/json';
      request.headers['X-StockGo-Code'] = codigoConexion;
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      if (body != null) request.body = jsonEncode(body);
      final response = await http.Response.fromStream(
        await _client.send(request).timeout(const Duration(seconds: 25)),
      ).timeout(const Duration(seconds: 25));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 400) {
        throw StockGoException(
          data['error'] as String? ?? 'El servidor rechazó la solicitud.',
        );
      }
      return data;
    } on StockGoException {
      rethrow;
    } catch (_) {
      throw const StockGoConexionException(
        'No se pudo contactar al servidor. Revisa la dirección, la red Wi-Fi y que el servidor siga abierto.',
      );
    }
  }

  Future<void> salir() async {
    final oldToken = token;
    token = null;
    if (oldToken == null) return;
    await _client
        .post(
          base.resolve('auth/logout'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $oldToken',
            'X-StockGo-Code': codigoConexion,
          },
        )
        .timeout(const Duration(seconds: 10));
  }

  void dispose() => _client.close();
}
