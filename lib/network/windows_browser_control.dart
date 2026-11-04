import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../data/stockgo_repository.dart';
import '../data/stockgo_store.dart';

/// Puente de la aplicación Windows para administrar el servidor desde esta PC.
/// Nunca escucha en la Wi-Fi: el inventario usa su servidor LAN independiente.
class WindowsBrowserControl {
  WindowsBrowserControl({required this.store, this.webRoot});
  final StockGoStore store;
  final String? webRoot;
  HttpServer? _server;
  bool _ocupado = false;
  int get puerto => _server?.port ?? 0;

  Future<void> iniciar({int port = 8079}) async {
    await store.inicializar();
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    _server!.listen(_atender);
  }

  Future<void> detener() async => _server?.close(force: true);

  bool _origenPermitido(String? origin) {
    if (origin == null) return true;
    final uri = Uri.tryParse(origin);
    return uri != null &&
        uri.scheme == 'http' &&
        ['localhost', '127.0.0.1'].contains(uri.host) &&
        [8080, puerto].contains(uri.port);
  }

  Future<Map<String, dynamic>> _body(HttpRequest request) async {
    if (request.headers.contentType?.mimeType != 'application/json') {
      throw const StockGoException('La solicitud debe usar JSON.');
    }
    final bytes = <int>[];
    await for (final chunk in request) {
      bytes.addAll(chunk);
      if (bytes.length > 4096) {
        throw const StockGoException('Solicitud demasiado grande.');
      }
    }
    return (jsonDecode(utf8.decode(bytes)) as Map).cast<String, dynamic>();
  }

  Future<void> _atender(HttpRequest request) async {
    final response = request.response;
    final origin = request.headers.value('Origin');
    response.headers.contentType = ContentType.json;
    response.headers.set('Cache-Control', 'no-store');
    try {
      if (!_origenPermitido(origin)) {
        response.statusCode = 403;
        response.write(
          jsonEncode({'error': 'Abre StockGo desde el navegador de esta PC.'}),
        );
        return;
      }
      if (origin != null) {
        response.headers.set('Access-Control-Allow-Origin', origin);
        response.headers.set('Vary', 'Origin');
        response.headers.set(
          'Access-Control-Allow-Methods',
          'GET, POST, OPTIONS',
        );
        response.headers.set('Access-Control-Allow-Headers', 'Content-Type');
        response.headers.set('Access-Control-Allow-Private-Network', 'true');
      }
      if (request.method == 'OPTIONS') {
        response.statusCode = 204;
        return;
      }
      if (request.uri.path == '/desktop/businesses' &&
          request.method == 'GET') {
        await store.inicializar();
        response.write(
          jsonEncode({
            'negocios': [
              for (final n in store.negocios) {'id': n.id, 'nombre': n.nombre},
            ],
            'activo': store.servidorActivo,
          }),
        );
      } else if (request.uri.path == '/desktop/start' &&
          request.method == 'POST') {
        if (_ocupado) {
          response.statusCode = 409;
          response.write(jsonEncode({'error': 'Hay otra operación en curso.'}));
          return;
        }
        _ocupado = true;
        try {
          final body = await _body(request);
          final negocio = store.negocios
              .where((n) => n.id == body['negocioId'])
              .firstOrNull;
          if (negocio == null) {
            throw const StockGoException(
              'Selecciona un negocio registrado en la aplicación Windows.',
            );
          }
          final user = body['usuario'] as String;
          final password = body['password'] as String;
          // Autenticación independiente: un vendedor no altera la sesión de la app.
          final repo = StockGoRepository(factory: store.factory);
          try {
            await repo.inicializar(
              ruta: negocio.ruta,
              crearUsuariosDemo: false,
              singleInstance: false,
            );
            await repo.iniciarSesion(user, password);
            if (repo.usuario?.puedeAdministrar != true) {
              throw const StockGoException(
                'Solo el administrador de este negocio puede activar el servidor.',
              );
            }
          } finally {
            await repo.cerrarBaseDeDatos();
          }
          if (store.conectado ||
              (store.usuario != null &&
                  store.negocioSeleccionado != negocio.id)) {
            throw const StockGoException(
              'Cierra la sesión del otro negocio en la aplicación Windows antes de cambiar de servidor.',
            );
          }
          if (store.usuario == null) await store.seleccionarNegocio(negocio.id);
          await store.iniciarSesion(user, password);
          await store.iniciarServidor();
          response.write(
            jsonEncode({
              'codigo': store.codigoParaDireccion('http://127.0.0.1:8081'),
              'nombreNegocio': store.nombreNegocio,
            }),
          );
        } finally {
          _ocupado = false;
        }
      } else if (request.method == 'GET' &&
          !request.uri.path.startsWith('/desktop/')) {
        await _archivo(request);
      } else {
        response.statusCode = 404;
        response.write(jsonEncode({'error': 'Ruta no encontrada.'}));
      }
    } on StockGoException catch (e) {
      response.statusCode = 403;
      response.write(jsonEncode({'error': e.mensaje}));
    } catch (_) {
      response.statusCode = 400;
      response.write(
        jsonEncode({
          'error': 'No se pudo completar la operación. Revisa los datos y el puerto 8081.',
        }),
      );
    } finally {
      await response.close();
    }
  }

  Future<void> _archivo(HttpRequest request) async {
    final roots = [
      ?webRoot,
      p.join(p.dirname(Platform.resolvedExecutable), 'data', 'web'),
      p.join(Directory.current.path, 'build', 'web'),
    ];
    String? root;
    for (final candidate in roots) {
      if (await File(p.join(candidate, 'index.html')).exists()) {
        root = p.absolute(candidate);
        break;
      }
    }
    if (root == null) {
      request.response.statusCode = 503;
      request.response.write(
        jsonEncode({
          'error': 'La interfaz web no está incluida. Compila con scripts/compilar_windows.ps1.',
        }),
      );
      return;
    }
    final path = request.uri.path == '/'
        ? 'index.html'
        : request.uri.path.substring(1);
    final target = p.normalize(p.join(root, path));
    if (!p.isWithin(root, target)) {
      request.response.statusCode = 403;
      return;
    }
    final file = File(target);
    if (!await file.exists()) {
      request.response.statusCode = 404;
      return;
    }
    final types = {
      '.html': 'text/html',
      '.js': 'application/javascript',
      '.wasm': 'application/wasm',
      '.json': 'application/json',
      '.css': 'text/css',
      '.png': 'image/png',
      '.svg': 'image/svg+xml',
      '.woff2': 'font/woff2',
    };
    request.response.headers.contentType = ContentType.parse(
      types[p.extension(target)] ?? 'application/octet-stream',
    );
    await request.response.addStream(file.openRead());
  }
}
