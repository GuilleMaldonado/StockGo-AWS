import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:sqflite_common/sqlite_api.dart';

import '../data/stockgo_repository.dart';
import '../models/producto.dart';
import '../models/usuario.dart';
import '../models/venta.dart';
import 'local_host.dart';

class _ApiError implements Exception {
  const _ApiError(this.status, this.message);
  final int status;
  final String message;
}

class _SesionServidor {
  _SesionServidor(this.repo)
    : expires = DateTime.now().add(const Duration(hours: 8));
  final StockGoRepository repo;
  final DateTime expires;
}

class StockGoLanServer {
  StockGoLanServer({required this.factory, required this.ruta});
  final DatabaseFactory factory;
  final String ruta;
  String _codigoConexion = '';
  String get codigoConexion => _codigoConexion;
  String get codigoInicial => _codigoConexion;
  final Map<String, _SesionServidor> _sesiones = {};
  final Map<String, ({DateTime inicio, int cantidad})> _intentos = {};
  HttpServer? _server;
  StockGoRepository? _master;
  bool get activo => _server != null;
  int get puerto => _server?.port ?? 0;

  Future<List<String>> iniciar({
    int port = 8081,
    InternetAddress? address,
  }) async {
    if (activo) return direcciones();
    final master = StockGoRepository(factory: factory);
    await master.inicializar(ruta: ruta, crearUsuariosDemo: false);
    _master = master;
    final server = await HttpServer.bind(
      address ?? InternetAddress.anyIPv4,
      port,
    );
    _server = server;
    _codigoConexion = await master.obtenerCodigoNegocio();
    server.listen((request) => unawaited(_atender(request)), onError: (_) {});
    return direcciones();
  }

  Future<List<String>> direcciones() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    );
    // Las redes de VirtualBox, Hyper-V y VPN no suelen ser accesibles al teléfono.
    // Conservamos las alternativas, pero priorizamos Wi-Fi/Ethernet física.
    bool virtual(NetworkInterface i) => RegExp(
      r'virtual|vbox|vmware|vethernet|docker|wsl|vpn|tun|tap',
      caseSensitive: false,
    ).hasMatch(i.name);
    interfaces.sort((a, b) {
      final prioridad = (virtual(a) ? 1 : 0).compareTo(virtual(b) ? 1 : 0);
      return prioridad != 0 ? prioridad : a.index.compareTo(b.index);
    });
    return [
      'http://127.0.0.1:$puerto',
      ...interfaces
          .expand((i) => i.addresses)
          .where((a) => !a.isLoopback)
          .map((a) => 'http://${a.address}:$puerto'),
    ];
  }

  Future<void> detener() async {
    await _server?.close(force: true);
    _server = null;
    _sesiones.clear();
    _intentos.clear();
    _codigoConexion = '';
  }

  Future<StockGoRepository> _repo() async {
    final repo = StockGoRepository(factory: factory);
    await repo.inicializar(ruta: ruta, crearUsuariosDemo: false);
    return repo;
  }

  String _token(StockGoRepository repo) {
    _sesiones.removeWhere(
      (key, value) => value.expires.isBefore(DateTime.now()),
    );
    if (_sesiones.length >= 200) {
      throw const _ApiError(503, 'Demasiadas sesiones. Intenta más tarde.');
    }
    final random = Random.secure();
    final token = base64UrlEncode(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
    _sesiones[token] = _SesionServidor(repo);
    return token;
  }

  Future<StockGoRepository> _autenticar(
    HttpRequest request, {
    bool permitirCambio = false,
  }) async {
    final header = request.headers.value(HttpHeaders.authorizationHeader) ?? '';
    final token = header.startsWith('Bearer ') ? header.substring(7) : '';
    final session = _sesiones[token];
    if (session == null || session.expires.isBefore(DateTime.now())) {
      _sesiones.remove(token);
      throw const _ApiError(
        401,
        'La sesión expiró. Cierra sesión y vuelve a entrar.',
      );
    }
    await session.repo.validarSesion(permitirCambio: permitirCambio);
    return session.repo;
  }

  Map<String, Object?> _usuario(Usuario usuario) => {
    'id': usuario.id,
    'nombre': usuario.nombre,
    'rol': usuario.rol.name,
    'nombres': usuario.nombres,
    'apellidos': usuario.apellidos,
    'codigoInterno': usuario.codigoInterno,
    'requiereCambioPassword': usuario.requiereCambioPassword,
    'versionCredencial': usuario.versionCredencial,
  };
  Map<String, Object?> _producto(Producto p, bool administrador) {
    final data = <String, Object?>{
      ...p.toMap(),
      'id': p.id,
      'nombre': p.nombre,
      'codigo': p.codigo,
      'precio': p.precio,
      'cantidad': p.cantidad,
      'activo': p.activo,
      'imagen': p.imagen == null ? null : base64Encode(p.imagen!),
    };
    if (!administrador) {
      data.remove('costo');
      data.remove('proveedor');
    }
    return data;
  }

  Map<String, Object?> _venta(Venta venta, bool administrador) => {
    ...venta.toMap(),
    'detalles': [
      for (final detalle in venta.detalles)
        {
          for (final campo in detalle.entries)
            if (administrador || campo.key != 'costoCentavos')
              campo.key: campo.value,
        },
    ],
  };

  void _limitar(HttpRequest request, String path) {
    final ahora = DateTime.now();
    _intentos.removeWhere(
      (_, valor) =>
          ahora.difference(valor.inicio) >= const Duration(minutes: 1),
    );
    final clave = '${request.connectionInfo?.remoteAddress.address}|$path';
    final previo = _intentos[clave];
    if ((previo?.cantidad ?? 0) >= 10 ||
        (previo == null && _intentos.length >= 1000)) {
      throw const _ApiError(
        429,
        'Demasiados intentos. Espera un minuto antes de volver a intentar.',
      );
    }
    _intentos[clave] = (
      inicio: previo?.inicio ?? ahora,
      cantidad: (previo?.cantidad ?? 0) + 1,
    );
  }

  Future<Map<String, dynamic>> _body(HttpRequest request) async {
    final bytes = <int>[];
    final limite = request.uri.path.startsWith('/products')
        ? 8 * 1024 * 1024
        : 64 * 1024;
    await for (final chunk in request) {
      if (bytes.length + chunk.length > limite) {
        throw const _ApiError(413, 'La solicitud es demasiado grande.');
      }
      bytes.addAll(chunk);
    }
    if (bytes.isEmpty) return {};
    return (jsonDecode(utf8.decode(bytes)) as Map).cast<String, dynamic>();
  }

  bool _origenLocal(String origin) {
    final uri = Uri.tryParse(origin);
    if (uri == null || !['http', 'https'].contains(uri.scheme)) return false;
    return esHostLocal(uri.host);
  }

  Future<void> _atender(HttpRequest request) async {
    final response = request.response;
    response.headers.contentType = ContentType.json;
    response.headers.set('Cache-Control', 'no-store');
    final origin = request.headers.value('Origin');
    if (origin != null && _origenLocal(origin)) {
      response.headers.set('Access-Control-Allow-Origin', origin);
      response.headers.set('Vary', 'Origin');
      response.headers.set(
        'Access-Control-Allow-Methods',
        'GET, POST, PUT, OPTIONS',
      );
      response.headers.set(
        'Access-Control-Allow-Headers',
        'Content-Type, Authorization, X-StockGo-Code',
      );
      response.headers.set('Access-Control-Allow-Private-Network', 'true');
    }
    try {
      if (origin != null && !_origenLocal(origin)) {
        throw const _ApiError(403, 'Origen no autorizado.');
      }
      if (request.method == 'OPTIONS') {
        response.statusCode = 204;
        return;
      }
      final path = request.uri.path.replaceAll(RegExp(r'^/|/$'), '');
      final method = request.method;
      if (method == 'POST' &&
          [
            'connect',
            'auth/login',
            'auth/guest',
            'auth/register',
            'setup',
            'auth/password',
            'users/reset-password',
          ].contains(path)) {
        _limitar(request, path);
      }
      Map<String, Object?> result;
      if (path != 'health' &&
          path != 'connect' &&
          request.headers.value('X-StockGo-Code') != codigoConexion) {
        throw const _ApiError(
          403,
          'Código de conexión incorrecto. Solicítalo al administrador desde Compartir inventario.',
        );
      }
      if (path == 'connect' && method == 'POST') {
        final body = await _body(request);
        if (body['codigo'] != codigoConexion) {
          throw const _ApiError(
            403,
            'Código de conexión incorrecto. Revisa el código que muestra StockGo en el dispositivo administrador.',
          );
        }
        response.write(
          jsonEncode({
            'ok': true,
            'nombreNegocio': await _master!.leerNombreNegocio(),
          }),
        );
        return;
      }
      if (path == 'health' && method == 'GET') {
        result = {
          'nombre': 'StockGo',
          'configurado': await _master!.negocioConfigurado(),
          'nombreNegocio': await _master!.leerNombreNegocio(),
        };
      } else if (path == 'setup' && method == 'POST') {
        final body = await _body(request);
        if (body['codigo'] != codigoInicial) {
          throw const _ApiError(
            403,
            'Código incorrecto. Revísalo en Compartir inventario dentro de StockGo.',
          );
        }
        await _master!.crearPropietario(
          body['usuario'] as String,
          body['password'] as String,
          nombres: body['nombres'] as String? ?? '',
          apellidos: body['apellidos'] as String? ?? '',
        );
        result = {'ok': true};
      } else if (path == 'auth/register' && method == 'POST') {
        if (!await _master!.negocioConfigurado()) {
          throw const _ApiError(409, 'Primero configura al dueño del negocio.');
        }
        final body = await _body(request);
        final repo = await _repo();
        await repo.crearUsuario(
          body['usuario'] as String,
          body['password'] as String,
          nombres: body['nombres'] as String? ?? '',
          apellidos: body['apellidos'] as String? ?? '',
        );
        result = {'ok': true};
      } else if ((path == 'auth/login' || path == 'auth/guest') &&
          method == 'POST') {
        if (!await _master!.negocioConfigurado()) {
          throw const _ApiError(
            409,
            'Primero crea el negocio y su administrador.',
          );
        }
        final repo = await _repo();
        if (path == 'auth/login') {
          final body = await _body(request);
          await repo.iniciarSesion(
            body['usuario'] as String,
            body['password'] as String,
          );
        } else {
          repo.entrarComoInvitado();
        }
        result = {'token': _token(repo), 'usuario': _usuario(repo.usuario!)};
      } else {
        final repo = await _autenticar(
          request,
          permitirCambio: path == 'auth/password' || path == 'auth/logout',
        );
        if (path == 'auth/password' && method == 'POST') {
          final body = await _body(request);
          final usuario = await repo.cambiarPassword(
            body['actual'] as String,
            body['nueva'] as String,
          );
          _sesiones.removeWhere(
            (_, sesion) =>
                sesion.repo != repo && sesion.repo.usuario?.id == usuario.id,
          );
          result = {'usuario': _usuario(usuario)};
        } else if (path == 'users/reset-password' && method == 'POST') {
          final body = await _body(request);
          final id = body['usuarioId'] as int;
          final temporal = await repo.restablecerPassword(
            id,
            body['passwordAdmin'] as String,
          );
          _sesiones.removeWhere((_, sesion) => sesion.repo.usuario?.id == id);
          result = {'temporal': temporal, 'validezMinutos': 30};
        } else if (path == 'security/audit' && method == 'GET') {
          result = {'eventos': await repo.listarAuditoria()};
        } else if (path == 'auth/profile' && method == 'PUT') {
          final body = await _body(request);
          result = {
            'usuario': _usuario(
              await repo.completarPerfil(
                body['nombres'] as String,
                body['apellidos'] as String,
              ),
            ),
          };
        } else if (path == 'auth/logout' && method == 'POST') {
          _sesiones.remove(
            request.headers
                .value(HttpHeaders.authorizationHeader)!
                .substring(7),
          );
          result = {'ok': true};
        } else if (path == 'users' && method == 'GET') {
          result = {
            'usuarios': (await repo.listarUsuarios()).map(_usuario).toList(),
            'nombreNegocio': await _master!.leerNombreNegocio(),
          };
        } else if (path == 'server/info' && method == 'GET') {
          if (!repo.usuario!.puedeAdministrar) {
            throw const _ApiError(
              403,
              'Solo el administrador puede invitar al equipo.',
            );
          }
          result = {
            'codigo': codigoConexion,
            'direcciones': await direcciones(),
          };
        } else if (path == 'users' && method == 'POST') {
          if (!repo.usuario!.puedeAdministrar) {
            throw const _ApiError(
              403,
              'Solo el administrador crea usuarios con roles.',
            );
          }
          final body = await _body(request);
          await repo.crearUsuario(
            body['usuario'] as String,
            body['password'] as String,
            rol: Rol.values.byName(body['rol'] as String),
            nombres: body['nombres'] as String? ?? '',
            apellidos: body['apellidos'] as String? ?? '',
          );
          result = {'ok': true};
        } else if (path == 'sales' && method == 'GET') {
          result = {
            'ventas': (await repo.listarVentas())
                .map((v) => _venta(v, repo.usuario!.puedeAdministrar))
                .toList(),
          };
        } else if (path == 'sales' && method == 'POST') {
          final body = await _body(request);
          final lineas = (body['lineas'] as List)
              .map(
                (l) => LineaVenta(
                  productoId: l['productoId'] as int,
                  cantidad: l['cantidad'] as int,
                  precioEsperadoCentavos: l['precioEsperadoCentavos'] as int?,
                ),
              )
              .toList();
          final venta = await repo.registrarVenta(
            lineas,
            body['solicitud'] as String,
          );
          result = {'venta': _venta(venta, repo.usuario!.puedeAdministrar)};
        } else if (path == 'products' && method == 'GET') {
          final productos = await repo.buscarProductos(
            busqueda: request.uri.queryParameters['q'] ?? '',
            incluirInactivos:
                request.uri.queryParameters['inactivos'] == 'true',
          );
          result = {
            'productos': productos
                .map((p) => _producto(p, repo.usuario!.puedeAdministrar))
                .toList(),
          };
        } else {
          final parts = path.split('/');
          final id = parts.length > 1 ? int.tryParse(parts[1]) : null;
          if (parts.first != 'products') {
            throw const _ApiError(404, 'Ruta no encontrada.');
          }
          if (parts.length == 2 && id != null && method == 'GET') {
            final producto = await repo.obtenerProductoPorId(id);
            result = {
              'producto': producto == null
                  ? null
                  : _producto(producto, repo.usuario!.puedeAdministrar),
            };
          } else if (parts.length == 3 &&
              id != null &&
              parts[2] == 'deactivate' &&
              method == 'POST') {
            if (!repo.usuario!.puedeAdministrar) {
              throw const _ApiError(
                403,
                'No tienes permiso para desactivar productos.',
              );
            }
            await repo.desactivarProducto(id);
            result = {'ok': true};
          } else if ((parts.length == 1 && method == 'POST') ||
              (parts.length == 2 && id != null && method == 'PUT')) {
            if (!repo.usuario!.puedeAdministrar) {
              throw const _ApiError(
                403,
                'No tienes permiso para agregar o editar productos.',
              );
            }
            final body = await _body(request);
            final saved = await repo.guardarProducto(
              Producto.fromMap({
                ...body,
                'id': method == 'PUT' ? id : null,
                'activo': 1,
                'imagen': body['imagen'] == null
                    ? null
                    : base64Decode(body['imagen'] as String),
              }),
            );
            result = {'id': saved};
          } else {
            throw const _ApiError(404, 'Ruta no encontrada.');
          }
        }
      }
      response.write(jsonEncode(result));
    } on _ApiError catch (e) {
      response.statusCode = e.status;
      response.write(jsonEncode({'error': e.message}));
    } on StockGoException catch (e) {
      response.statusCode = 400;
      response.write(jsonEncode({'error': e.mensaje}));
    } on FormatException {
      response.statusCode = 400;
      response.write(jsonEncode({'error': 'Datos inválidos.'}));
    } on TypeError {
      response.statusCode = 400;
      response.write(
        jsonEncode({'error': 'Faltan campos o tienen un formato incorrecto.'}),
      );
    } catch (_) {
      response.statusCode = 500;
      response.write(
        jsonEncode({
          'error': 'No se pudo completar la operación en el servidor.',
        }),
      );
    } finally {
      await response.close();
    }
  }
}
