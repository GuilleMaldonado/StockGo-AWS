import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite_common/sqlite_api.dart';

import '../models/producto.dart';
import '../models/usuario.dart';
import '../models/venta.dart';
import '../models/negocio.dart';
import '../network/stockgo_api.dart';
import '../network/codigo_negocio.dart';
import '../network/local_host.dart';
import '../network/hosting.dart';
import 'stockgo_repository.dart';
export 'stockgo_repository.dart' show StockGoException;

class StockGoStore extends ChangeNotifier {
  StockGoStore({required this.factory})
    : local = StockGoRepository(factory: factory) {
    _catalogo = local;
  }
  final DatabaseFactory factory;
  StockGoRepository local;
  late final StockGoRepository _catalogo;
  final Map<int, StockGoRepository> _repositorios = {};
  List<Negocio> _negocios = [];
  List<Negocio> get negocios => List.unmodifiable(_negocios);
  int? _negocioId;
  int? get negocioSeleccionado => _negocioId;
  String? _nombreRemoto;
  String get nombreNegocio => conectado
      ? (_nombreRemoto ?? 'Negocio conectado')
      : _negocios
                .where((n) => n.id == _negocioId)
                .map((n) => n.nombre)
                .firstOrNull ??
            'Inventario local anterior';
  StockGoApi? _api;
  Usuario? _remoto;
  StockGoHost? _host;
  List<String> _direcciones = [];
  String? get codigoServidor => !conectado && usuario?.puedeAdministrar == true
      ? _host?.codigoConexion
      : null;
  bool get admiteServidorLocal => !kIsWeb;
  bool get servidorActivo => _host?.activo ?? false;
  List<String> get direccionesServidor => List.unmodifiable(_direcciones);
  bool get conectado => _api != null;
  String? get direccionServidor => _api?.base.toString();
  Usuario? get usuario => conectado ? _remoto : local.usuario;

  Future<void> inicializar({String? ruta}) async {
    if (conectado) return;
    await _catalogo.inicializar(ruta: ruta);
    _negocios = await _catalogo.listarNegocios();
    if (local != _catalogo) await local.inicializar();
  }

  Future<void> seleccionarNegocio(int? id) async {
    if (usuario != null || conectado) {
      throw const StockGoException(
        'Cierra sesión y usa el modo local para cambiar de negocio.',
      );
    }
    await detenerServidor();
    await inicializar();
    if (id == null) {
      local = _catalogo;
    } else {
      final negocio = _negocios.where((n) => n.id == id).firstOrNull;
      if (negocio == null) {
        throw const StockGoException('El negocio no existe.');
      }
      final repo = _repositorios.putIfAbsent(
        id,
        () => StockGoRepository(factory: factory),
      );
      await repo.inicializar(ruta: negocio.ruta, crearUsuariosDemo: false);
      local = repo;
    }
    _host = null;
    _negocioId = id;
    notifyListeners();
  }

  Future<void> conectar(
    String direccion, {
    String codigo = '',
    bool permitirVPN = false,
  }) async {
    if (usuario != null) {
      throw const StockGoException(
        'Cierra la sesión antes de cambiar de servidor.',
      );
    }
    if (!RegExp(
      r'^(\d{6}|[A-F0-9]{32})'
      r'$',
    ).hasMatch(codigo.trim())) {
      throw const StockGoException(
        'Ingresa el identificador del negocio que muestra el administrador en StockGo.',
      );
    }
    final api = StockGoApi(direccion, permitirVPN: permitirVPN)
      ..codigoConexion = codigo.trim();
    try {
      final health = await api.pedir('POST', 'connect', {
        'codigo': codigo.trim(),
      });
      _nombreRemoto = health['nombreNegocio'] as String?;
    } catch (_) {
      api.dispose();
      rethrow;
    }
    _api?.dispose();
    _api = api;
    _remoto = null;
    notifyListeners();
  }

  Future<void> conectarConCodigo(String codigo) async {
    final datos = CodigoNegocio.leer(codigo);
    await conectar(
      datos.direccion,
      codigo: datos.identificador,
      permitirVPN: datos.vpn,
    );
  }

  Future<void> entrarConCodigo(
    String codigo,
    String nombre,
    String password,
  ) async {
    if (usuario != null) {
      throw const StockGoException(
        'Cierra sesión antes de entrar a otro negocio.',
      );
    }
    final datos = CodigoNegocio.leer(codigo);
    final api = StockGoApi(datos.direccion, permitirVPN: datos.vpn)
      ..codigoConexion = datos.identificador;
    try {
      final negocio = await api.pedir('POST', 'connect', {
        'codigo': datos.identificador,
      });
      final sesion = await api.pedir('POST', 'auth/login', {
        'usuario': nombre.trim(),
        'password': password,
      });
      final cuenta = Usuario.fromMap(
        (sesion['usuario'] as Map).cast<String, Object?>(),
      );
      api.token = sesion['token'] as String;
      _api?.dispose();
      _api = api;
      _nombreRemoto = negocio['nombreNegocio'] as String?;
      _remoto = cuenta;
      notifyListeners();
    } catch (_) {
      api.dispose();
      rethrow;
    }
  }

  String? codigoParaDireccion(String direccion) {
    final id = codigoServidor;
    if (id == null || !servidorActivo) return null;
    return CodigoNegocio(
      direccion,
      id,
      vpn: esHostTunel(Uri.parse(direccion).host),
    ).codificar();
  }

  void usarLocal() {
    if (usuario != null) throw const StockGoException('Cierra sesión primero.');
    _api?.dispose();
    _api = null;
    _remoto = null;
    notifyListeners();
  }

  Future<void> iniciarSesion(String nombre, String password) async {
    if (!conectado) {
      await local.iniciarSesion(nombre, password);
    } else {
      final data = await _api!.pedir('POST', 'auth/login', {
        'usuario': nombre,
        'password': password,
      });
      _api!.token = data['token'] as String;
      _remoto = Usuario.fromMap(
        (data['usuario'] as Map).cast<String, Object?>(),
      );
    }
    notifyListeners();
  }

  Future<void> entrarInvitado() async {
    if (!conectado) {
      local.entrarComoInvitado();
    } else {
      final data = await _api!.pedir('POST', 'auth/guest');
      _api!.token = data['token'] as String;
      _remoto = Usuario.fromMap(
        (data['usuario'] as Map).cast<String, Object?>(),
      );
    }
    notifyListeners();
  }

  void entrarComoInvitado() {
    if (conectado) {
      throw const StockGoException(
        'Usa el acceso de invitado conectado al servidor.',
      );
    }
    local.entrarComoInvitado();
    notifyListeners();
  }

  Future<void> iniciarServidor() async {
    if (conectado || usuario?.puedeAdministrar != true) {
      throw const StockGoException(
        'Solo el administrador de este dispositivo puede alojar el negocio.',
      );
    }
    if (!await local.negocioConfigurado()) {
      throw const StockGoException(
        'Primero crea tu negocio desde Crear cuenta → Crear mi negocio. Después inicia sesión con esa cuenta.',
      );
    }
    _host ??= StockGoHost(factory: factory, ruta: local.databasePath);
    try {
      _direcciones = await _host!.iniciar();
    } on StockGoException {
      rethrow;
    } catch (_) {
      throw const StockGoException(
        'No se pudo abrir el servidor. Revisa el puerto 8081, la red Wi-Fi y los permisos de red local.',
      );
    }
    notifyListeners();
  }

  Future<void> detenerServidor() async {
    await _host?.detener();
    _direcciones = [];
    notifyListeners();
  }

  void cerrarSesion() {
    unawaited(_host?.detener() ?? Future<void>.value());
    _direcciones = [];
    final api = _api;
    if (api != null) unawaited(api.salir().catchError((_) {}));
    _remoto = null;
    local.cerrarSesion();
    notifyListeners();
  }

  Future<List<Usuario>> listarUsuarios() async {
    if (usuario?.puedeAdministrar != true) {
      throw const StockGoException(
        'Solo el administrador puede ver el equipo.',
      );
    }
    if (!conectado) return local.listarUsuarios();
    final data = await _api!.pedir('GET', 'users');
    return (data['usuarios'] as List)
        .map((u) => Usuario.fromMap((u as Map).cast<String, Object?>()))
        .toList();
  }

  Future<Map<String, String>> codigosInvitacion() async {
    if (usuario?.puedeAdministrar != true) {
      throw const StockGoException(
        'Solo el administrador puede invitar vendedores.',
      );
    }
    if (conectado) {
      final data = await _api!.pedir('GET', 'server/info');
      final url = _api!.base.toString().replaceAll(RegExp(r'/$'), '');
      final mismaPc = ['127.0.0.1', 'localhost'].contains(_api!.base.host);
      final urls =
          <String>{url, ...(data['direcciones'] as List).cast<String>()}.where(
            (u) =>
                mismaPc ||
                !['127.0.0.1', 'localhost'].contains(Uri.parse(u).host),
          );
      return {
        for (final u in urls)
          u: CodigoNegocio(
            u,
            data['codigo'] as String,
            vpn: esHostTunel(Uri.parse(u).host),
          ).codificar(),
      };
    }
    if (!servidorActivo) {
      throw const StockGoException(
        'Inicia el servidor desde Compartir inventario para invitar vendedores.',
      );
    }
    return {for (final url in _direcciones) url: codigoParaDireccion(url)!};
  }

  Future<void> crearUsuario(
    String nombre,
    String password, {
    Rol rol = Rol.vendedor,
    String nombres = '',
    String apellidos = '',
  }) async {
    if (!conectado) {
      await local.crearUsuario(
        nombre,
        password,
        rol: rol,
        nombres: nombres,
        apellidos: apellidos,
      );
    } else {
      final endpoint = usuario?.puedeAdministrar == true
          ? 'users'
          : 'auth/register';
      if (rol == Rol.administrador && usuario?.puedeAdministrar != true) {
        throw const StockGoException(
          'Solo el administrador puede asignar ese rol.',
        );
      }
      await _api!.pedir('POST', endpoint, {
        'usuario': nombre,
        'password': password,
        'rol': rol.name,
        'nombres': nombres,
        'apellidos': apellidos,
      });
    }
  }

  Future<void> crearPropietario(
    String nombre,
    String password, {
    String codigoInicial = '',
    String nombreNegocio = '',
    String nombres = '',
    String apellidos = '',
  }) async {
    if (!conectado) {
      if (nombreNegocio.trim().isEmpty) {
        await local.crearPropietario(
          nombre,
          password,
          nombres: nombres,
          apellidos: apellidos,
        );
      } else {
        if (usuario != null) {
          throw const StockGoException(
            'Cierra sesión antes de crear otro negocio.',
          );
        }
        await inicializar();
        final negocio = await _catalogo.reservarNegocio(nombreNegocio);
        final repo = StockGoRepository(factory: factory);
        try {
          await repo.inicializar(ruta: negocio.ruta, crearUsuariosDemo: false);
          await repo.crearPropietario(
            nombre,
            password,
            nombres: nombres,
            apellidos: apellidos,
          );
          await repo.asignarNombreNegocio(negocio.nombre);
          await repo.obtenerCodigoNegocio();
        } catch (_) {
          await _catalogo.cancelarReservaNegocio(negocio.id);
          await repo.cerrarBaseDeDatos();
          rethrow;
        }
        _repositorios[negocio.id] = repo;
        await seleccionarNegocio(negocio.id);
      }
    } else {
      await _api!.pedir('POST', 'setup', {
        'usuario': nombre,
        'password': password,
        'codigo': codigoInicial,
        'nombres': nombres,
        'apellidos': apellidos,
      });
    }
  }

  Future<bool> negocioConfigurado() async {
    if (!conectado) return local.negocioConfigurado();
    return (await _api!.pedir('GET', 'health'))['configurado'] as bool;
  }

  Map<String, Object?> _jsonProducto(Producto p) => {
    ...p.toMap(),
    'id': p.id,
    'nombre': p.nombre,
    'codigo': p.codigo,
    'precio': p.precio,
    'cantidad': p.cantidad,
    'activo': p.activo,
    'imagen': p.imagen == null ? null : base64Encode(p.imagen!),
  };
  Producto _leerProducto(Map<String, dynamic> data) => Producto.fromMap({
    ...data,
    'activo': data['activo'] == true ? 1 : 0,
    'imagen': data['imagen'] == null
        ? null
        : base64Decode(data['imagen'] as String),
  });
  Future<List<Producto>> buscarProductos({
    String busqueda = '',
    bool incluirInactivos = false,
  }) async {
    if (!conectado) {
      return local.buscarProductos(
        busqueda: busqueda,
        incluirInactivos: incluirInactivos,
      );
    }
    final query = Uri(
      queryParameters: {'q': busqueda, 'inactivos': '$incluirInactivos'},
    ).query;
    final data = await _api!.pedir('GET', 'products?$query');
    return (data['productos'] as List)
        .map((p) => _leerProducto((p as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<Producto?> obtenerProductoPorId(int id) async {
    if (!conectado) return local.obtenerProductoPorId(id);
    final data = await _api!.pedir('GET', 'products/$id');
    return data['producto'] == null
        ? null
        : _leerProducto((data['producto'] as Map).cast<String, dynamic>());
  }

  Future<int> guardarProducto(Producto producto) async {
    if (!conectado) return local.guardarProducto(producto);
    final data = await _api!.pedir(
      producto.id == null ? 'POST' : 'PUT',
      producto.id == null ? 'products' : 'products/${producto.id}',
      _jsonProducto(producto),
    );
    return data['id'] as int;
  }

  Future<void> desactivarProducto(int id) async {
    if (!conectado) {
      await local.desactivarProducto(id);
    } else {
      await _api!.pedir('POST', 'products/$id/deactivate');
    }
  }

  Future<Venta> registrarVenta(
    List<LineaVenta> lineas,
    String solicitud,
  ) async {
    if (!conectado) return local.registrarVenta(lineas, solicitud);
    final data = await _api!.pedir('POST', 'sales', {
      'solicitud': solicitud,
      'lineas': lineas.map((l) => l.toMap()).toList(),
    });
    return Venta.fromMap((data['venta'] as Map).cast<String, Object?>());
  }

  Future<List<Venta>> listarVentas() async {
    if (!conectado) return local.listarVentas();
    final data = await _api!.pedir('GET', 'sales');
    return (data['ventas'] as List)
        .map((v) => Venta.fromMap((v as Map).cast<String, Object?>()))
        .toList();
  }

  Future<String> restablecerPassword(
    int usuarioId,
    String passwordAdmin,
  ) async {
    if (!conectado) return local.restablecerPassword(usuarioId, passwordAdmin);
    final data = await _api!.pedir('POST', 'users/reset-password', {
      'usuarioId': usuarioId,
      'passwordAdmin': passwordAdmin,
    });
    return data['temporal'] as String;
  }

  Future<void> cambiarPassword(String actual, String nueva) async {
    if (!conectado) {
      await local.cambiarPassword(actual, nueva);
    } else {
      final data = await _api!.pedir('POST', 'auth/password', {
        'actual': actual,
        'nueva': nueva,
      });
      _remoto = Usuario.fromMap(
        (data['usuario'] as Map).cast<String, Object?>(),
      );
    }
    notifyListeners();
  }

  Future<List<Map<String, Object?>>> listarAuditoria() async {
    if (!conectado) return local.listarAuditoria();
    final data = await _api!.pedir('GET', 'security/audit');
    return (data['eventos'] as List)
        .map((e) => (e as Map).cast<String, Object?>())
        .toList();
  }

  Future<void> completarPerfil(String nombres, String apellidos) async {
    if (!conectado) {
      await local.completarPerfil(nombres, apellidos);
    } else {
      final data = await _api!.pedir('PUT', 'auth/profile', {
        'nombres': nombres,
        'apellidos': apellidos,
      });
      _remoto = Usuario.fromMap(
        (data['usuario'] as Map).cast<String, Object?>(),
      );
    }
    notifyListeners();
  }

  Future<void> cerrarBaseDeDatos() async {
    await _host?.detener();
    for (final repo in _repositorios.values) {
      await repo.cerrarBaseDeDatos();
    }
    await _catalogo.cerrarBaseDeDatos();
  }

  @override
  void dispose() {
    _api?.dispose();
    unawaited(_host?.detener() ?? Future<void>.value());
    super.dispose();
  }
}
