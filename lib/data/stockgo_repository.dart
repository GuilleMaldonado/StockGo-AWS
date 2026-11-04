import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import 'package:path/path.dart' as p;
import 'package:sqflite_common/sqlite_api.dart';

import '../models/producto.dart';
import '../models/ficha_producto.dart';
import '../models/negocio.dart';
import '../models/usuario.dart';
import '../models/venta.dart';

class StockGoException implements Exception {
  const StockGoException(this.mensaje);
  final String mensaje;
  @override
  String toString() => mensaje;
}

class StockGoConexionException extends StockGoException {
  const StockGoConexionException(super.mensaje);
}

/// Sesión y SQLite. Cada escritura comprueba el rol autenticado.
class StockGoRepository {
  StockGoRepository({required this.factory});
  final DatabaseFactory factory;
  Database? _db;
  Usuario? _usuario;
  Usuario? get usuario => _usuario;
  static final _passwordAlgorithm = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 120000,
    bits: 256,
  );

  Future<void> inicializar({
    String? ruta,
    bool crearUsuariosDemo = true,
    bool singleInstance = true,
  }) async {
    if (_db != null) return;
    final path = ruta ?? p.join(await factory.getDatabasesPath(), 'stockgo.db');
    _db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        singleInstance: singleInstance,
        version: 10,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          await db.execute('''
          CREATE TABLE usuarios (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre TEXT NOT NULL COLLATE NOCASE UNIQUE,
            password_hash TEXT NOT NULL,
            salt TEXT NOT NULL,
            rol TEXT NOT NULL CHECK (rol IN ('administrador', 'vendedor', 'invitado'))
          )
        ''');
          await _crearProductos(db);
          await _crearConfiguracion(db);
          await _ampliarProductos(db);
          await _crearNegocios(db);
          await _crearVentas(db);
          await _ampliarIdentidad(db);
          await _crearMantenimiento(db);
          if (crearUsuariosDemo) {
            await _crearUsuario(db, 'admin', 'Admin123!', Rol.administrador);
            await _crearUsuario(db, 'vendedor', 'Vendedor123!', Rol.vendedor);
          }
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await _crearProductos(db);
          } else if (oldVersion < 3) {
            await db.execute('ALTER TABLE productos ADD COLUMN imagen BLOB');
          }
          if (oldVersion < 4) await _crearConfiguracion(db);
          if (oldVersion < 7) await _ampliarProductos(db);
          if (oldVersion < 6) await _crearNegocios(db);
          if (oldVersion < 8) await _crearVentas(db);
          if (oldVersion < 9) await _ampliarIdentidad(db);
          if (oldVersion < 10) await _crearMantenimiento(db);
        },
      ),
    );
  }

  static Future<void> _ampliarProductos(Database db) async {
    final existing = (await db.rawQuery('PRAGMA table_info(productos)'))
        .map((r) => r['name'])
        .toSet();
    final columns = {
      'categoria': "TEXT NOT NULL DEFAULT 'Repuesto'",
      'costo': 'REAL NOT NULL DEFAULT 0 CHECK (costo >= 0)',
      'stockMinimo': 'INTEGER NOT NULL DEFAULT 0 CHECK (stockMinimo >= 0)',
      for (final campo in camposProducto)
        campo.clave: "TEXT NOT NULL DEFAULT ''",
    };
    for (final entry in columns.entries) {
      if (!existing.contains(entry.key)) {
        await db.execute(
          'ALTER TABLE productos ADD COLUMN ${entry.key} ${entry.value}',
        );
      }
    }
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_productos_marca ON productos(marca COLLATE NOCASE)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_productos_parte ON productos(numeroParte COLLATE NOCASE)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_productos_categoria_activo ON productos(categoria, activo)',
    );
  }

  static Future<void> _crearNegocios(Database db) async {
    await db.execute(
      'CREATE TABLE IF NOT EXISTS negocios (id INTEGER PRIMARY KEY AUTOINCREMENT, nombre TEXT NOT NULL, nombreNormalizado TEXT NOT NULL UNIQUE, ruta TEXT NOT NULL)',
    );
  }

  static Future<void> _crearVentas(Database db) async {
    await db.execute('''CREATE TABLE ventas (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      solicitud TEXT NOT NULL UNIQUE,
      usuarioId INTEGER NOT NULL REFERENCES usuarios(id),
      vendedor TEXT NOT NULL,
      fecha TEXT NOT NULL,
      totalCentavos INTEGER NOT NULL CHECK(totalCentavos > 0)
    )''');
    await db.execute('''CREATE TABLE venta_detalles (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      ventaId INTEGER NOT NULL REFERENCES ventas(id),
      productoId INTEGER NOT NULL REFERENCES productos(id),
      nombre TEXT NOT NULL,
      codigo TEXT NOT NULL,
      lote TEXT NOT NULL,
      vencimiento TEXT NOT NULL,
      unidad TEXT NOT NULL,
      cantidad INTEGER NOT NULL CHECK(cantidad > 0),
      precioCentavos INTEGER NOT NULL CHECK(precioCentavos > 0),
      costoCentavos INTEGER NOT NULL CHECK(costoCentavos >= 0)
    )''');
    await db.execute(
      'CREATE INDEX idx_venta_detalles_venta ON venta_detalles(ventaId)',
    );
    await db.execute('CREATE INDEX idx_ventas_fecha ON ventas(fecha)');
    await db.execute(
      'CREATE INDEX idx_ventas_usuario_fecha ON ventas(usuarioId, id)',
    );
  }

  static Future<void> _ampliarIdentidad(Database db) async {
    for (final campo in ['nombres', 'apellidos', 'codigoInterno']) {
      await db.execute(
        "ALTER TABLE usuarios ADD COLUMN $campo TEXT NOT NULL DEFAULT ''",
      );
    }
    await db.execute(
      "UPDATE usuarios SET codigoInterno = CASE WHEN rol = 'vendedor' THEN 'VD-' ELSE 'US-' END || printf('%08d', id)",
    );
    await db.execute(
      'CREATE UNIQUE INDEX idx_usuario_codigo ON usuarios(codigoInterno) WHERE codigoInterno != \'\'',
    );
    await db.execute(
      "ALTER TABLE ventas ADD COLUMN codigoVendedor TEXT NOT NULL DEFAULT ''",
    );
  }

  static String _codigoPersona(Rol rol) =>
      '${rol == Rol.vendedor ? 'VD' : 'AD'}-${List.generate(8, (_) => 'ABCDEFGHJKLMNPQRSTUVWXYZ'[Random.secure().nextInt(24)]).join()}';
  static void _validarPersona(String nombres, String apellidos) {
    if (Usuario.validarNombre(nombres) != null ||
        Usuario.validarNombre(apellidos) != null) {
      throw const StockGoException(
        'Ingresa nombres y apellidos reales usando letras, sin números.',
      );
    }
  }

  Future<Usuario> completarPerfil(String nombres, String apellidos) async {
    await _requerirSesion();
    if (_usuario == null || _usuario!.rol == Rol.invitado) {
      throw const StockGoException(
        'Inicia sesión para completar tu identidad.',
      );
    }
    _validarPersona(nombres, apellidos);
    await _database.update(
      'usuarios',
      {'nombres': nombres.trim(), 'apellidos': apellidos.trim()},
      where: 'id = ?',
      whereArgs: [_usuario!.id],
    );
    _usuario = Usuario.fromMap(
      (await _database.query(
        'usuarios',
        where: 'id = ?',
        whereArgs: [_usuario!.id],
      )).single,
    );
    return _usuario!;
  }

  Future<void> _requerirVentas() async {
    await _requerirSesion();
    if (!(_usuario?.puedeVender ?? false)) {
      throw const StockGoException(
        'Solo administradores y vendedores pueden registrar o consultar ventas.',
      );
    }
  }

  Future<Venta> registrarVenta(
    List<LineaVenta> lineas,
    String solicitud,
  ) async {
    await _requerirVentas();
    if (!_usuario!.perfilCompleto) {
      throw const StockGoException(
        'Completa tus nombres y apellidos antes de registrar ventas.',
      );
    }
    if (!RegExp(r'^[a-zA-Z0-9_-]{16,80}$').hasMatch(solicitud) ||
        lineas.isEmpty ||
        lineas.length > 200 ||
        lineas.any(
          (l) =>
              l.productoId <= 0 || l.cantidad <= 0 || l.cantidad > 2147483647,
        ) ||
        lineas.map((l) => l.productoId).toSet().length != lineas.length) {
      throw const StockGoException(
        'Selecciona productos distintos y cantidades enteras mayores que cero.',
      );
    }
    final usuario = _usuario!;
    return _database.transaction((txn) async {
      final anteriores = await txn.query(
        'ventas',
        where: 'solicitud = ?',
        whereArgs: [solicitud],
      );
      if (anteriores.isNotEmpty) {
        final anterior = anteriores.single;
        if (anterior['usuarioId'] != usuario.id) {
          throw const StockGoException(
            'Esa solicitud pertenece a otra cuenta.',
          );
        }
        final detalles = await txn.query(
          'venta_detalles',
          where: 'ventaId = ?',
          whereArgs: [anterior['id']],
        );
        final mismoContenido =
            detalles.length == lineas.length &&
            lineas.every(
              (l) => detalles.any(
                (d) =>
                    d['productoId'] == l.productoId &&
                    d['cantidad'] == l.cantidad,
              ),
            );
        if (!mismoContenido) {
          throw const StockGoException(
            'La venta ya fue registrada con otros productos.',
          );
        }
        return Venta.fromMap({...anterior, 'detalles': detalles});
      }
      final detalles = <Map<String, Object?>>[];
      var total = 0;
      final hoy = DateTime.now().toIso8601String().substring(0, 10);
      for (final linea in lineas) {
        final rows = await txn.query(
          'productos',
          where: 'id = ? AND activo = 1',
          whereArgs: [linea.productoId],
        );
        if (rows.isEmpty) {
          throw const StockGoException(
            'Un producto ya no está disponible. Actualiza el inventario.',
          );
        }
        final p = Producto.fromMap(rows.single);
        if (p.precio < p.costo) {
          throw StockGoException(
            '${p.nombre} tiene un precio de venta inferior al de compra. El administrador debe corregirlo.',
          );
        }
        if (['Lubricante', 'Aditivo'].contains(p.categoria) &&
            (p.ficha['lote'] ?? '').trim().isEmpty) {
          throw StockGoException(
            'Registra el lote del fabricante de ${p.nombre} antes de venderlo.',
          );
        }
        if (p.cantidad < linea.cantidad) {
          throw StockGoException(
            'Stock insuficiente de ${p.nombre}. Disponible: ${p.cantidad}.',
          );
        }
        final vence = p.ficha['vencimiento'] ?? '';
        if (vence.isNotEmpty && vence.compareTo(hoy) < 0) {
          throw StockGoException(
            '${p.nombre} está vencido. No se puede vender.',
          );
        }
        final precio = (p.precio * 100).round();
        if (linea.precioEsperadoCentavos != null &&
            linea.precioEsperadoCentavos != precio) {
          throw StockGoException(
            'El precio de ${p.nombre} cambió. Actualiza el inventario y revisa el total antes de confirmar.',
          );
        }
        if (precio <= 0) {
          throw StockGoException(
            '${p.nombre} necesita un precio de venta mayor que cero.',
          );
        }
        final cambio = await txn.rawUpdate(
          'UPDATE productos SET cantidad = cantidad - ? WHERE id = ? AND activo = 1 AND cantidad >= ?',
          [linea.cantidad, p.id, linea.cantidad],
        );
        if (cambio != 1) {
          throw const StockGoException(
            'Las existencias cambiaron. Vuelve a revisar la venta.',
          );
        }
        if (linea.cantidad > (9007199254740991 - total) ~/ precio) {
          throw const StockGoException('El total supera el límite permitido.');
        }
        total += precio * linea.cantidad;
        if (total > 9007199254740991) {
          throw const StockGoException('El total supera el límite permitido.');
        }
        detalles.add({
          'productoId': p.id,
          'nombre': p.nombre,
          'codigo': p.codigo,
          'lote': p.ficha['lote'] ?? '',
          'vencimiento': vence,
          'unidad': p.ficha['unidadVenta'] ?? '',
          'cantidad': linea.cantidad,
          'precioCentavos': precio,
          'costoCentavos': (p.costo * 100).round(),
        });
      }
      final fecha = DateTime.now().toUtc().toIso8601String();
      final id = await txn.insert('ventas', {
        'solicitud': solicitud,
        'usuarioId': usuario.id,
        'vendedor': usuario.nombreCompleto,
        'codigoVendedor': usuario.codigoInterno,
        'fecha': fecha,
        'totalCentavos': total,
      });
      for (final detalle in detalles) {
        await txn.insert('venta_detalles', {...detalle, 'ventaId': id});
      }
      return Venta(
        id: id,
        fecha: fecha,
        vendedor: usuario.nombreCompleto,
        codigoVendedor: usuario.codigoInterno,
        totalCentavos: total,
        detalles: detalles,
      );
    });
  }

  Future<List<Venta>> listarVentas() async {
    await _requerirVentas();
    final rows = await _database.query(
      'ventas',
      where: _usuario!.puedeAdministrar ? null : 'usuarioId = ?',
      whereArgs: _usuario!.puedeAdministrar ? null : [_usuario!.id],
      orderBy: 'id DESC',
    );
    final ventas = <Venta>[];
    for (final row in rows) {
      final detalles = await _database.query(
        'venta_detalles',
        where: 'ventaId = ?',
        whereArgs: [row['id']],
      );
      ventas.add(Venta.fromMap({...row, 'detalles': detalles}));
    }
    return ventas;
  }

  Future<List<Negocio>> listarNegocios() async => (await _database.query(
    'negocios',
    orderBy: 'nombre COLLATE NOCASE',
  )).map(Negocio.fromMap).toList();

  Future<Negocio> reservarNegocio(String nombre) async {
    final limpio = nombre.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (limpio.length < 3 || limpio.length > 100) {
      throw const StockGoException(
        'El nombre de empresa debe tener entre 3 y 100 caracteres.',
      );
    }
    try {
      return await _database.transaction((txn) async {
        final id = await txn.insert('negocios', {
          'nombre': limpio,
          'nombreNormalizado': limpio.toLowerCase(),
          'ruta': '',
        });
        final ruta = '${databasePath}_negocio_$id.db';
        await txn.update(
          'negocios',
          {'ruta': ruta},
          where: 'id = ?',
          whereArgs: [id],
        );
        return Negocio(id: id, nombre: limpio, ruta: ruta);
      });
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw const StockGoException(
          'Ya existe una empresa con ese nombre en este dispositivo.',
        );
      }
      rethrow;
    }
  }

  Future<void> cancelarReservaNegocio(int id) => _database
      .delete('negocios', where: 'id = ?', whereArgs: [id])
      .then((_) {});
  Future<void> asignarNombreNegocio(String nombre) async {
    await _database.insert('configuracion', {
      'clave': 'nombreEmpresa',
      'valor': nombre,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> leerNombreNegocio() async {
    final rows = await _database.query(
      'configuracion',
      where: 'clave = ?',
      whereArgs: ['nombreEmpresa'],
    );
    return rows.isEmpty ? null : rows.first['valor'] as String;
  }

  /// Identificador de 128 bits persistente por base de negocio.
  Future<String> obtenerCodigoNegocio() => _database.transaction((txn) async {
    final rows = await txn.query(
      'configuracion',
      where: 'clave = ?',
      whereArgs: ['codigoNegocio'],
    );
    if (rows.isNotEmpty) return rows.first['valor'] as String;
    final random = Random.secure();
    final codigo = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join().toUpperCase();
    await txn.insert('configuracion', {
      'clave': 'codigoNegocio',
      'valor': codigo,
    });
    return codigo;
  });

  String get databasePath => _database.path;

  static Future<void> _crearConfiguracion(Database db) async {
    await db.execute(
      'CREATE TABLE IF NOT EXISTS configuracion (clave TEXT PRIMARY KEY, valor TEXT NOT NULL)',
    );
  }

  Future<bool> negocioConfigurado() async {
    final filas = await _database.query(
      'configuracion',
      where: 'clave = ?',
      whereArgs: ['propietario'],
    );
    return filas.isNotEmpty;
  }

  Future<void> crearPropietario(
    String nombre,
    String password, {
    String nombres = '',
    String apellidos = '',
  }) async {
    _validarPersona(nombres, apellidos);
    final usuario = nombre.trim().toLowerCase();
    if (!RegExp(r'^[a-z._-]{3,40}$').hasMatch(usuario) ||
        password.length < 8 ||
        password.length > 128 ||
        ['admin', 'vendedor'].contains(usuario)) {
      throw const StockGoException(
        'Elige un usuario propio (distinto de admin y vendedor) y una contraseña de 8 a 128 caracteres.',
      );
    }
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final hash = await _hash(password, salt);
    final demoSalt = List<int>.generate(16, (_) => random.nextInt(256));
    final disabledHash = await _hash(
      base64UrlEncode(List<int>.generate(32, (_) => random.nextInt(256))),
      demoSalt,
    );
    try {
      await _database.transaction((txn) async {
        final config = await txn.query(
          'configuracion',
          where: 'clave = ?',
          whereArgs: ['propietario'],
        );
        if (config.isNotEmpty) {
          throw const StockGoException(
            'El negocio ya tiene un dueño. Solicita una cuenta al administrador.',
          );
        }
        final id = await txn.insert('usuarios', {
          'nombre': usuario,
          'password_hash': hash,
          'salt': base64Encode(salt),
          'rol': Rol.administrador.name,
          'nombres': nombres.trim(),
          'apellidos': apellidos.trim(),
          'codigoInterno': _codigoPersona(Rol.administrador),
        });
        await txn.insert('configuracion', {
          'clave': 'propietario',
          'valor': '$id',
        });
        // Los accesos de demostración no quedan habilitados en un negocio compartido.
        await txn.update(
          'usuarios',
          {'password_hash': disabledHash, 'salt': base64Encode(demoSalt)},
          where: 'nombre IN (?, ?)',
          whereArgs: ['admin', 'vendedor'],
        );
      });
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw const StockGoException(
          'Ese usuario ya existe. Elige otro nombre para el dueño.',
        );
      }
      rethrow;
    }
  }

  static Future<void> _crearProductos(Database db) async {
    await db.execute('''
      CREATE TABLE productos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        codigo TEXT NOT NULL COLLATE NOCASE UNIQUE,
        precio REAL NOT NULL CHECK (precio >= 0),
        cantidad INTEGER NOT NULL CHECK (cantidad >= 0),
        activo INTEGER NOT NULL DEFAULT 1 CHECK (activo IN (0, 1)), imagen BLOB
      )
    ''');
  }

  static Future<String> _hash(String password, List<int> salt) async {
    final key = await _passwordAlgorithm.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    return base64Encode(await key.extractBytes());
  }

  static Future<void> _crearUsuario(
    Database db,
    String nombre,
    String password,
    Rol rol, {
    String nombres = '',
    String apellidos = '',
  }) async {
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    await db.insert('usuarios', {
      'nombre': nombre,
      'password_hash': await _hash(password, salt),
      'salt': base64Encode(salt),
      'rol': rol.name,
      'nombres': nombres,
      'apellidos': apellidos,
      'codigoInterno': _codigoPersona(rol),
    });
  }

  Database get _database {
    final db = _db;
    if (db == null) {
      throw const StockGoException('La base de datos no está lista.');
    }
    return db;
  }

  Future<void> iniciarSesion(String nombre, String password) async {
    final rows = await _database.query(
      'usuarios',
      where: 'nombre = ?',
      whereArgs: [nombre.trim()],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const StockGoException('Usuario o contraseña incorrectos.');
    }
    final row = rows.first;
    if (!await _passwordCoincide(password, row)) {
      throw const StockGoException('Usuario o contraseña incorrectos.');
    }
    if (row['requiereCambioPassword'] == 1) {
      final vence = DateTime.tryParse(row['temporalHasta'] as String? ?? '');
      if (vence == null || !vence.isAfter(DateTime.now().toUtc())) {
        throw const StockGoException(
          'La contraseña temporal venció. Solicita otra al administrador.',
        );
      }
    }
    _usuario = Usuario.fromMap(row);
  }

  static Future<bool> _passwordCoincide(
    String password,
    Map<String, Object?> row,
  ) async {
    if (password.isEmpty || password.length > 128) {
      return false;
    }
    final candidate = base64Decode(
      await _hash(password, base64Decode(row['salt'] as String)),
    );
    final expected = base64Decode(row['password_hash'] as String);
    var difference = candidate.length ^ expected.length;
    for (var i = 0; i < min(candidate.length, expected.length); i++) {
      difference |= candidate[i] ^ expected[i];
    }
    return difference == 0;
  }

  static Future<void> _crearMantenimiento(Database db) async {
    await db.execute(
      'ALTER TABLE usuarios ADD COLUMN versionCredencial INTEGER NOT NULL DEFAULT 0',
    );
    await db.execute(
      'ALTER TABLE usuarios ADD COLUMN requiereCambioPassword INTEGER NOT NULL DEFAULT 0',
    );
    await db.execute(
      "ALTER TABLE usuarios ADD COLUMN temporalHasta TEXT NOT NULL DEFAULT ''",
    );
    await db.execute('''CREATE TABLE auditoria_seguridad (
      id INTEGER PRIMARY KEY AUTOINCREMENT, fecha TEXT NOT NULL,
      actorId INTEGER NOT NULL, actor TEXT NOT NULL, objetivoId INTEGER NOT NULL,
      objetivo TEXT NOT NULL, accion TEXT NOT NULL)''');
  }

  Future<void> validarSesion({bool permitirCambio = false}) =>
      _requerirSesion(permitirCambio: permitirCambio);

  Future<String> restablecerPassword(
    int usuarioId,
    String passwordAdmin,
  ) async {
    await _requerirAdmin();
    final actor = _usuario!;
    if (usuarioId == actor.id) {
      throw const StockGoException(
        'Para tu cuenta utiliza Cambiar mi contraseña.',
      );
    }
    final filaActor = (await _database.query(
      'usuarios',
      where: 'id = ?',
      whereArgs: [actor.id],
    )).single;
    if (!await _passwordCoincide(passwordAdmin, filaActor)) {
      throw const StockGoException(
        'La contraseña del administrador es incorrecta.',
      );
    }
    final temporal =
        'SG-${base64UrlEncode(List.generate(18, (_) => Random.secure().nextInt(256)))}';
    final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final hash = await _hash(temporal, salt);
    await _database.transaction((txn) async {
      final vigente = await txn.query(
        'usuarios',
        where:
            'id = ? AND versionCredencial = ? AND requiereCambioPassword = 0',
        whereArgs: [actor.id, actor.versionCredencial],
      );
      if (vigente.isEmpty) {
        throw const StockGoException('Tu acceso cambió. Vuelve a ingresar.');
      }
      final destino = await txn.query(
        'usuarios',
        where: 'id = ?',
        whereArgs: [usuarioId],
      );
      if (destino.isEmpty) {
        throw const StockGoException('La cuenta no pertenece a este negocio.');
      }
      final objetivo = destino.single;
      await txn.update(
        'usuarios',
        {
          'password_hash': hash,
          'salt': base64Encode(salt),
          'versionCredencial': (objetivo['versionCredencial'] as int) + 1,
          'requiereCambioPassword': 1,
          'temporalHasta': DateTime.now()
              .toUtc()
              .add(const Duration(minutes: 30))
              .toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [usuarioId],
      );
      await txn.insert('auditoria_seguridad', {
        'fecha': DateTime.now().toUtc().toIso8601String(),
        'actorId': actor.id,
        'actor': actor.nombreCompleto,
        'objetivoId': usuarioId,
        'objetivo': objetivo['nombre'],
        'accion': 'restablecer_password',
      });
    });
    return temporal;
  }

  Future<Usuario> cambiarPassword(String actual, String nueva) async {
    await _requerirSesion(permitirCambio: true);
    if (_usuario!.rol == Rol.invitado) {
      throw const StockGoException('El invitado no tiene contraseña.');
    }
    if (nueva.length < 8 ||
        nueva.length > 128 ||
        nueva == actual ||
        nueva.trim().isEmpty) {
      throw const StockGoException(
        'Usa una contraseña diferente de 8 a 128 caracteres.',
      );
    }
    final actor = _usuario!;
    final row = (await _database.query(
      'usuarios',
      where: 'id = ?',
      whereArgs: [actor.id],
    )).single;
    if (!await _passwordCoincide(actual, row)) {
      throw const StockGoException('La contraseña actual es incorrecta.');
    }
    final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final hash = await _hash(nueva, salt);
    await _database.transaction((txn) async {
      final cambios = await txn.update(
        'usuarios',
        {
          'password_hash': hash,
          'salt': base64Encode(salt),
          'versionCredencial': actor.versionCredencial + 1,
          'requiereCambioPassword': 0,
          'temporalHasta': '',
        },
        where: 'id = ? AND versionCredencial = ?',
        whereArgs: [actor.id, actor.versionCredencial],
      );
      if (cambios != 1) {
        throw const StockGoException('Tu acceso cambió. Vuelve a ingresar.');
      }
      await txn.insert('auditoria_seguridad', {
        'fecha': DateTime.now().toUtc().toIso8601String(),
        'actorId': actor.id,
        'actor': actor.nombreCompleto,
        'objetivoId': actor.id,
        'objetivo': actor.nombre,
        'accion': 'cambiar_password',
      });
    });
    return _usuario = Usuario.fromMap(
      (await _database.query(
        'usuarios',
        where: 'id = ?',
        whereArgs: [actor.id],
      )).single,
    );
  }

  Future<List<Map<String, Object?>>> listarAuditoria() async {
    await _requerirAdmin();
    return _database.query(
      'auditoria_seguridad',
      orderBy: 'id DESC',
      limit: 200,
    );
  }

  Future<void> crearUsuario(
    String nombre,
    String password, {
    Rol rol = Rol.vendedor,
    String nombres = '',
    String apellidos = '',
  }) async {
    _validarPersona(nombres, apellidos);
    if (rol == Rol.administrador) await _requerirAdmin();
    if (rol == Rol.invitado) {
      throw const StockGoException('El invitado accede sin crear una cuenta.');
    }
    final usuario = nombre.trim().toLowerCase();
    if (!RegExp(r'^[a-z._-]{3,40}$').hasMatch(usuario)) {
      throw const StockGoException(
        'Usa de 3 a 40 letras, puntos o guiones, sin números.',
      );
    }
    if (password.length < 8 || password.length > 128) {
      throw const StockGoException(
        'La contraseña debe tener entre 8 y 128 caracteres.',
      );
    }
    try {
      await _crearUsuario(
        _database,
        usuario,
        password,
        rol,
        nombres: nombres.trim(),
        apellidos: apellidos.trim(),
      );
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw const StockGoException(
          'Ese nombre de usuario ya está registrado.',
        );
      }
      rethrow;
    }
  }

  Future<List<Usuario>> listarUsuarios() async {
    await _requerirAdmin();
    final rows = await _database.query(
      'usuarios',
      columns: ['id', 'nombre', 'rol', 'nombres', 'apellidos', 'codigoInterno'],
      orderBy: 'nombre COLLATE NOCASE',
    );
    return rows.map(Usuario.fromMap).toList();
  }

  void entrarComoInvitado() {
    _usuario = const Usuario(id: 0, nombre: 'Invitado', rol: Rol.invitado);
  }

  void cerrarSesion() {
    _usuario = null;
  }

  Future<void> _requerirSesion({bool permitirCambio = false}) async {
    if (_usuario == null) {
      throw const StockGoException('Inicia sesión primero.');
    }
    if (_usuario!.rol == Rol.invitado) return;
    final rows = await _database.query(
      'usuarios',
      where: 'id = ?',
      whereArgs: [_usuario!.id],
    );
    if (rows.isEmpty ||
        rows.single['versionCredencial'] != _usuario!.versionCredencial) {
      _usuario = null;
      throw const StockGoException(
        'Tu acceso cambió. Cierra sesión y vuelve a ingresar.',
      );
    }
    final row = rows.single;
    if (row['requiereCambioPassword'] == 1) {
      final vence = DateTime.tryParse(row['temporalHasta'] as String? ?? '');
      if (vence == null || !vence.isAfter(DateTime.now().toUtc())) {
        _usuario = null;
        throw const StockGoException(
          'La contraseña temporal venció. Solicita otra al administrador.',
        );
      }
      if (!permitirCambio) {
        throw const StockGoException(
          'Primero debes cambiar tu contraseña temporal.',
        );
      }
    }
  }

  Future<void> _requerirAdmin() async {
    await _requerirSesion();
    if (!_usuario!.puedeAdministrar) {
      throw const StockGoException(
        'Solo el administrador puede modificar productos.',
      );
    }
  }

  Future<List<Producto>> buscarProductos({
    String busqueda = '',
    bool incluirInactivos = false,
  }) async {
    await _requerirSesion();
    final todos = incluirInactivos && _usuario!.puedeAdministrar;
    final texto = busqueda
        .trim()
        .replaceAll('\\', '\\\\')
        .replaceAll('%', '\\%')
        .replaceAll('_', '\\_');
    final rows = await _database.query(
      'productos',
      where:
          '${todos ? '1 = 1' : 'activo = 1'} '
          "AND (nombre LIKE ? ESCAPE '\\' OR codigo LIKE ? ESCAPE '\\' OR marca LIKE ? ESCAPE '\\' OR numeroParte LIKE ? ESCAPE '\\' OR referenciaOEM LIKE ? ESCAPE '\\' OR compatibilidad LIKE ? ESCAPE '\\')",
      whereArgs: List.filled(6, '%$texto%'),
      orderBy: 'activo DESC, nombre COLLATE NOCASE ASC',
    );
    return rows.map(Producto.fromMap).toList();
  }

  Future<Producto?> obtenerProductoPorId(int id) async {
    await _requerirSesion();
    final rows = await _database.query(
      'productos',
      where: 'id = ?${_usuario!.puedeAdministrar ? '' : ' AND activo = 1'}',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Producto.fromMap(rows.first);
  }

  Future<int> guardarProducto(Producto producto) async {
    await _requerirAdmin();
    final nombre = producto.nombre.trim();
    final codigo = producto.codigo.trim().toUpperCase();
    if (nombre.isEmpty ||
        nombre.length > 100 ||
        codigo.isEmpty ||
        codigo.length > 50 ||
        !producto.precio.isFinite ||
        producto.precio < 0 ||
        producto.cantidad < 0 ||
        producto.cantidad > 2147483647 ||
        (producto.imagen?.length ?? 0) > 5 * 1024 * 1024) {
      throw const StockGoException(
        'Revisa el nombre, código, precio y cantidad.',
      );
    }
    if (!categoriasProducto.contains(producto.categoria) ||
        !producto.costo.isFinite ||
        producto.costo < 0 ||
        producto.stockMinimo < 0 ||
        producto.stockMinimo > 2147483647 ||
        producto.ficha.values.any((value) => value.length > 2000)) {
      throw const StockGoException(
        'Revisa la categoría, costo, stock mínimo y ficha técnica.',
      );
    }
    final vencimiento = producto.ficha['vencimiento']?.trim() ?? '';
    final lote = producto.ficha['lote']?.trim() ?? '';
    if (['Lubricante', 'Aditivo'].contains(producto.categoria) &&
        lote.isEmpty) {
      throw const StockGoException(
        'Los lubricantes y aditivos necesitan el lote del fabricante.',
      );
    }
    if (lote.length > 100 || RegExp(r'[\x00-\x1F]').hasMatch(lote)) {
      throw const StockGoException(
        'El lote admite hasta 100 caracteres en una sola línea.',
      );
    }
    if (producto.precio < producto.costo) {
      throw const StockGoException(
        'El precio de venta no puede ser menor al precio de compra.',
      );
    }
    if (producto.precio > 1000000000 ||
        producto.costo > 1000000000 ||
        (producto.precio * 100 - (producto.precio * 100).round()).abs() >
            .00001 ||
        (producto.costo * 100 - (producto.costo * 100).round()).abs() >
            .00001) {
      throw const StockGoException(
        'Los precios admiten hasta dos decimales y un máximo de 1,000,000,000.',
      );
    }
    if (vencimiento.isNotEmpty) {
      final fecha = DateTime.tryParse(vencimiento);
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(vencimiento) ||
          fecha == null ||
          fecha.toIso8601String().substring(0, 10) != vencimiento) {
        throw const StockGoException(
          'El vencimiento debe ser una fecha válida AAAA-MM-DD.',
        );
      }
    }
    try {
      return await _database.transaction((txn) async {
        final duplicates = await txn.query(
          'productos',
          columns: ['id'],
          where: 'codigo = ? AND id != ?',
          whereArgs: [codigo, producto.id ?? 0],
          limit: 1,
        );
        if (duplicates.isNotEmpty) {
          throw const StockGoException(
            'Ese código ya existe, incluso si el producto está desactivado.',
          );
        }
        if (producto.id != null) {
          final anteriores = await txn.query(
            'productos',
            where: 'id = ?',
            whereArgs: [producto.id],
          );
          if (anteriores.isNotEmpty &&
              (anteriores.single['cantidad'] as int) > 0 &&
              (anteriores.single['lote'] as String? ?? '').trim().isNotEmpty &&
              ((anteriores.single['lote'] as String? ?? '').trim() !=
                      (producto.ficha['lote'] ?? '').trim() ||
                  (anteriores.single['vencimiento'] as String? ?? '').trim() !=
                      vencimiento)) {
            throw const StockGoException(
              'No cambies el lote ni su vencimiento mientras tenga existencias. Registra ese lote con un código de inventario separado para no mezclar mercancía.',
            );
          }
        }
        final values = {
          ...producto.toMap()..remove('id'),
          for (final campo in camposProducto)
            if (!camposParaCategoria(producto.categoria)
                .any((visible) => visible.clave == campo.clave))
              campo.clave: '',
          'nombre': nombre,
          'codigo': codigo,
          'precio': producto.precio,
          'cantidad': producto.cantidad,
          'imagen': producto.imagen,
        };
        if (producto.id == null) {
          return txn.insert('productos', {...values, 'activo': 1});
        }
        final count = await txn.update(
          'productos',
          values,
          where: 'id = ? AND activo = 1',
          whereArgs: [producto.id],
        );
        if (count == 0) {
          throw const StockGoException(
            'El producto no existe o está desactivado.',
          );
        }
        return producto.id!;
      });
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw const StockGoException('El código ya está registrado.');
      }
      rethrow;
    }
  }

  Future<void> desactivarProducto(int id) async {
    await _requerirAdmin();
    final count = await _database.update(
      'productos',
      {'activo': 0},
      where: 'id = ? AND activo = 1',
      whereArgs: [id],
    );
    if (count == 0) {
      throw const StockGoException('El producto ya no está activo.');
    }
  }

  Future<void> cerrarBaseDeDatos() async {
    await _db?.close();
    _db = null;
  }
}
