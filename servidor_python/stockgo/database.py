"""SQLite v10 y copias consistentes. Nunca abre la base original para escribir."""
import base64
from contextlib import closing
import hashlib
import hmac
import json
import os
from pathlib import Path
import re
import secrets
import sqlite3
import unicodedata

FIELDS = ('marca tipo descripcion numeroParte referenciaOEM codigoBarras unidadVenta '
          'presentacion ubicacion proveedor lote vencimiento viscosidadSAE baseAceite '
          'normaAPI normaACEA homologaciones aplicacion calibre dimensiones material '
          'posicion compatibilidad gradoFiltracion valvulaBypass dosificacion '
          'fluidoCompatible voltaje potencia').split()
CATEGORIES = ['Repuesto', 'Lubricante', 'Filtro', 'Aditivo', 'Accesorio']
COMMON = set('marca tipo descripcion codigoBarras unidadVenta presentacion ubicacion proveedor lote vencimiento'.split())
TECHNICAL = {
    'Repuesto': 'numeroParte referenciaOEM calibre dimensiones material posicion compatibilidad',
    'Lubricante': 'viscosidadSAE baseAceite normaAPI normaACEA homologaciones aplicacion',
    'Filtro': 'numeroParte referenciaOEM dimensiones compatibilidad gradoFiltracion valvulaBypass',
    'Aditivo': 'dosificacion fluidoCompatible aplicacion',
    'Accesorio': 'numeroParte dimensiones material compatibilidad voltaje potencia',
}


class Error(Exception):
    def __init__(self, message, status=400):
        super().__init__(message)
        self.status = status


def text(data, key, default=None):
    value = data.get(key, default)
    if not isinstance(value, str):
        raise Error(f'El campo {key} debe ser texto.')
    return value


def integer(value, low=0, high=2147483647):
    if type(value) is not int or not low <= value <= high:
        raise Error('Revisa las cantidades e identificadores enteros.')
    return value


def identity(data):
    username = text(data, 'usuario').strip().lower()
    if not re.fullmatch(r'[a-z._-]{3,40}', username):
        raise Error('El usuario admite de 3 a 40 letras, puntos o guiones, sin números.')
    names = []
    for key in ('nombres', 'apellidos'):
        value = text(data, key).strip()
        if not re.fullmatch(r"[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]+(?:[ '’-][A-Za-zÁÉÍÓÚÜÑáéíóúüñ]+)*", value) or len(value) > 80:
            raise Error('Ingresa nombres y apellidos con letras y espacios, sin números.')
        names.append(value)
    password = text(data, 'password')
    valid_password(password)
    return username, password, *names


def valid_password(password):
    if not isinstance(password, str) or not 8 <= len(password) <= 128 or not password.strip():
        raise Error('La contraseña debe tener entre 8 y 128 caracteres.')


def password_fields(password):
    salt = secrets.token_bytes(16)
    digest = hashlib.pbkdf2_hmac('sha256', password.encode('utf-8'), salt, 120000)
    return base64.b64encode(digest).decode(), base64.b64encode(salt).decode()


def matches(password, row):
    if not isinstance(password, str) or not 1 <= len(password) <= 128:
        return False
    try:
        digest = hashlib.pbkdf2_hmac('sha256', password.encode(), base64.b64decode(row['salt'], validate=True), 120000)
        return hmac.compare_digest(digest, base64.b64decode(row['password_hash'], validate=True))
    except (ValueError, TypeError):
        return False


def person(row):
    return {k: (bool(row[k]) if k == 'requiereCambioPassword' else row[k]) for k in
            ('id', 'nombre', 'rol', 'nombres', 'apellidos', 'codigoInterno', 'requiereCambioPassword', 'versionCredencial')}


def connection(path):
    db = sqlite3.connect(path, timeout=15)
    db.row_factory = sqlite3.Row
    db.execute('PRAGMA foreign_keys=ON')
    return db


def initialize(path):
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    db = connection(path)
    try:
        version = db.execute('PRAGMA user_version').fetchone()[0]
        if version not in (0, 10):
            raise Error('Importa una base StockGo actualizada al esquema 10 desde Flutter.')
        if version == 0:
            # Una base desconocida no debe confundirse con una instalación nueva.
            if db.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchone():
                raise Error('La base existente no tiene un esquema StockGo compatible.')
            extra = ','.join(f'"{key}" TEXT NOT NULL DEFAULT \'\'' for key in FIELDS)
            db.executescript(f"""
                CREATE TABLE usuarios(id INTEGER PRIMARY KEY AUTOINCREMENT,
                    nombre TEXT NOT NULL COLLATE NOCASE UNIQUE, password_hash TEXT NOT NULL,
                    salt TEXT NOT NULL, rol TEXT NOT NULL CHECK(rol IN ('administrador','vendedor','invitado')),
                    nombres TEXT NOT NULL DEFAULT '', apellidos TEXT NOT NULL DEFAULT '',
                    codigoInterno TEXT NOT NULL DEFAULT '', versionCredencial INTEGER NOT NULL DEFAULT 0,
                    requiereCambioPassword INTEGER NOT NULL DEFAULT 0, temporalHasta TEXT NOT NULL DEFAULT '');
                CREATE UNIQUE INDEX idx_usuario_codigo ON usuarios(codigoInterno) WHERE codigoInterno != '';
                CREATE TABLE productos(id INTEGER PRIMARY KEY AUTOINCREMENT, nombre TEXT NOT NULL,
                    codigo TEXT NOT NULL COLLATE NOCASE UNIQUE, precio REAL NOT NULL CHECK(precio>=0),
                    cantidad INTEGER NOT NULL CHECK(cantidad>=0), activo INTEGER NOT NULL DEFAULT 1 CHECK(activo IN (0,1)),
                    imagen BLOB, categoria TEXT NOT NULL DEFAULT 'Repuesto', costo REAL NOT NULL DEFAULT 0 CHECK(costo>=0),
                    stockMinimo INTEGER NOT NULL DEFAULT 0 CHECK(stockMinimo>=0), {extra});
                CREATE INDEX idx_productos_categoria_activo ON productos(categoria,activo);
                CREATE TABLE configuracion(clave TEXT PRIMARY KEY, valor TEXT NOT NULL);
                CREATE TABLE negocios(id INTEGER PRIMARY KEY AUTOINCREMENT, nombre TEXT NOT NULL,
                    nombreNormalizado TEXT NOT NULL UNIQUE, ruta TEXT NOT NULL);
                CREATE TABLE ventas(id INTEGER PRIMARY KEY AUTOINCREMENT, solicitud TEXT NOT NULL UNIQUE,
                    usuarioId INTEGER NOT NULL REFERENCES usuarios(id), vendedor TEXT NOT NULL, fecha TEXT NOT NULL,
                    totalCentavos INTEGER NOT NULL CHECK(totalCentavos>0), codigoVendedor TEXT NOT NULL DEFAULT '');
                CREATE TABLE venta_detalles(id INTEGER PRIMARY KEY AUTOINCREMENT,
                    ventaId INTEGER NOT NULL REFERENCES ventas(id), productoId INTEGER NOT NULL REFERENCES productos(id),
                    nombre TEXT NOT NULL, codigo TEXT NOT NULL, lote TEXT NOT NULL, vencimiento TEXT NOT NULL,
                    unidad TEXT NOT NULL, cantidad INTEGER NOT NULL CHECK(cantidad>0),
                    precioCentavos INTEGER NOT NULL CHECK(precioCentavos>0), costoCentavos INTEGER NOT NULL CHECK(costoCentavos>=0));
                CREATE INDEX idx_venta_detalles_venta ON venta_detalles(ventaId);
                CREATE INDEX idx_ventas_usuario_fecha ON ventas(usuarioId,id);
                CREATE INDEX idx_ventas_fecha ON ventas(fecha);
                CREATE TABLE auditoria_seguridad(id INTEGER PRIMARY KEY AUTOINCREMENT, fecha TEXT NOT NULL,
                    actorId INTEGER NOT NULL, actor TEXT NOT NULL, objetivoId INTEGER NOT NULL,
                    objetivo TEXT NOT NULL, accion TEXT NOT NULL);
                PRAGMA user_version=10;
            """)
        expected = {
            'usuarios': {'id', 'nombre', 'password_hash', 'salt', 'rol', 'nombres', 'apellidos', 'codigoInterno',
                         'versionCredencial', 'requiereCambioPassword', 'temporalHasta'},
            'productos': {'id', 'nombre', 'codigo', 'precio', 'costo', 'cantidad', 'activo', 'imagen', 'categoria', 'stockMinimo', *FIELDS},
            'ventas': {'id', 'solicitud', 'usuarioId', 'vendedor', 'fecha', 'totalCentavos', 'codigoVendedor'},
            'venta_detalles': {'id', 'ventaId', 'productoId', 'nombre', 'codigo', 'lote', 'vencimiento', 'unidad', 'cantidad', 'precioCentavos', 'costoCentavos'},
            'configuracion': {'clave', 'valor'},
            'auditoria_seguridad': {'id', 'fecha', 'actorId', 'actor', 'objetivoId', 'objetivo', 'accion'},
        }
        for table, columns in expected.items():
            actual = {r['name'] for r in db.execute(f'PRAGMA table_info({table})')}
            if not columns <= actual:
                raise Error('La base no contiene todas las tablas y columnas de StockGo 1.2.')
        if db.execute('PRAGMA quick_check').fetchone()[0] != 'ok' or db.execute('PRAGMA foreign_key_check').fetchone():
            raise Error('La base tiene errores de integridad.')
        with db:
            db.execute("INSERT OR IGNORE INTO configuracion VALUES('codigoNegocio',?)", (secrets.token_hex(16).upper(),))
    finally:
        db.close()


def config(db, key):
    row = db.execute('SELECT valor FROM configuracion WHERE clave=?', (key,)).fetchone()
    return row[0] if row else None


def add_user(db, data, role='vendedor'):
    username, password, first, last = identity(data)
    if role not in ('administrador', 'vendedor'):
        raise Error('El invitado entra sin cuenta. Selecciona Administrador o Vendedor.')
    digest, salt = password_fields(password)
    internal = ('AD-' if role == 'administrador' else 'VD-') + secrets.token_hex(5).upper()
    try:
        return db.execute('INSERT INTO usuarios(nombre,password_hash,salt,rol,nombres,apellidos,codigoInterno) VALUES(?,?,?,?,?,?,?)',
                          (username, digest, salt, role, first, last, internal)).lastrowid
    except sqlite3.IntegrityError as exc:
        raise Error('Ese nombre de usuario ya está registrado.') from exc


def create_owner(db, data):
    if config(db, 'propietario'):
        raise Error('El negocio ya tiene administrador.', 409)
    if text(data, 'usuario').strip().lower() in ('admin', 'vendedor'):
        raise Error('Elige un usuario propio distinto de admin y vendedor.')
    user_id = add_user(db, data, 'administrador')
    db.execute("INSERT INTO configuracion VALUES('propietario',?)", (str(user_id),))
    return user_id


def normalize(name):
    if not isinstance(name, str):
        raise Error('Ingresa el nombre del negocio.')
    clean = ' '.join(name.split())
    if not 2 <= len(clean) <= 100:
        raise Error('El nombre del negocio debe tener entre 2 y 100 caracteres.')
    normalized = ''.join(c for c in unicodedata.normalize('NFD', clean.casefold()) if not unicodedata.combining(c))
    return clean, normalized


class Catalog:
    """Catálogo independiente: no modifica las rutas de la instalación Flutter."""
    def __init__(self, root=None):
        self.root = Path(root) if root else Path(os.environ.get('LOCALAPPDATA', str(Path.home()))) / 'StockGoPython'
        self.root.mkdir(parents=True, exist_ok=True)
        self.path = self.root / 'catalogo.db'
        with closing(connection(self.path)) as db, db:
            db.execute('CREATE TABLE IF NOT EXISTS negocios(id TEXT PRIMARY KEY,nombre TEXT NOT NULL,normalizado TEXT NOT NULL UNIQUE,ruta TEXT NOT NULL)')

    def list(self):
        db = connection(self.path)
        try:
            return [dict(r) for r in db.execute('SELECT * FROM negocios ORDER BY nombre COLLATE NOCASE')]
        finally:
            db.close()

    def create(self, name, owner):
        clean, norm = normalize(name)
        identity(owner)  # Validar antes de crear el archivo.
        return self._add(clean, norm, owner=owner)

    def import_database(self, source):
        source = Path(source).resolve(strict=True)
        # backup incluye transacciones confirmadas del WAL; origen en modo solo lectura.
        return self._add(None, None, source=source)

    def _add(self, clean, norm, owner=None, source=None):
        key = secrets.token_hex(16)
        destination = self.root / f'negocio_{key}.db'
        catalog = connection(self.path)
        try:
            if source:
                original = sqlite3.connect(source.as_uri() + '?mode=ro', uri=True, timeout=10)
                copied = sqlite3.connect(destination)
                try:
                    original.backup(copied)
                finally:
                    copied.close()
                    original.close()
            initialize(destination)
            db = connection(destination)
            try:
                with db:
                    if source:
                        clean, norm = normalize(config(db, 'nombreEmpresa'))
                        if not config(db, 'propietario'):
                            raise Error('Importa la base de un negocio configurado, no el catálogo general.')
                    else:
                        db.execute("INSERT INTO configuracion VALUES('nombreEmpresa',?)", (clean,))
                        create_owner(db, owner)
                business_code = config(db, 'codigoNegocio')
            finally:
                db.close()
            with catalog:
                catalog.execute('BEGIN IMMEDIATE')
                # No se puede importar dos veces el mismo negocio con otro nombre.
                for existing in self.list():
                    other = connection(existing['ruta'])
                    try:
                        if config(other, 'codigoNegocio') == business_code:
                            raise Error('Este negocio ya fue importado.')
                    finally:
                        other.close()
                catalog.execute('INSERT INTO negocios VALUES(?,?,?,?)', (key, clean, norm, str(destination)))
            return {'id': key, 'nombre': clean, 'ruta': str(destination)}
        except sqlite3.IntegrityError as exc:
            destination.unlink(missing_ok=True)
            raise Error('Ya existe un negocio con ese nombre en esta PC.') from exc
        except Exception:
            destination.unlink(missing_ok=True)
            raise
        finally:
            catalog.close()


def sg1(url, code, vpn=False):
    data = {'url': url, 'negocio': code}
    if vpn:
        data['vpn'] = True
    return 'SG1-' + base64.urlsafe_b64encode(json.dumps(data, separators=(',', ':')).encode()).decode().rstrip('=')
