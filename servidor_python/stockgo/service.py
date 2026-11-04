"""Reglas de negocio y contrato HTTP compartido con StockGo Flutter."""
import base64
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal, InvalidOperation
import re
import secrets
import sqlite3
import threading
import time
from urllib.parse import parse_qs, urlsplit

from .database import (CATEGORIES, COMMON, FIELDS, TECHNICAL, Error, add_user,
                       config, connection, create_owner, integer, matches,
                       password_fields, person, text, valid_password)


def now():
    return datetime.now(timezone.utc)


def future(value):
    try:
        return datetime.fromisoformat(value.replace('Z', '+00:00')) > now()
    except (ValueError, TypeError):
        return False


def cents(value):
    if type(value) not in (int, float):
        raise Error('El precio debe ser numérico.')
    try:
        number = Decimal(str(value))
        if not number.is_finite() or not 0 <= number <= 1000000000 or number * 100 != (number * 100).to_integral_value():
            raise Error('Los precios admiten hasta dos decimales y un máximo de 1,000,000,000.')
        return int(number * 100)
    except InvalidOperation as exc:
        raise Error('Precio inválido.') from exc


class Service:
    def __init__(self, path, addresses=None):
        self.path = path
        self.addresses = addresses or (lambda: [])
        self.sessions = {}
        self.attempts = {}
        # Un bloqueo engloba autorización y transacción: un reset no se intercala
        # con una escritura de una sesión que acaba de revocar.
        self.lock = threading.RLock()
        db = connection(path)
        try:
            self.code = config(db, 'codigoNegocio')
        finally:
            db.close()

    def limit(self, ip, route):
        instant = time.monotonic()
        self.attempts = {k: v for k, v in self.attempts.items() if instant - v[0] < 60}
        key = (ip, route)
        start, count = self.attempts.get(key, (instant, 0))
        if count >= 10 or (key not in self.attempts and len(self.attempts) >= 1000):
            raise Error('Demasiados intentos. Espera un minuto.', 429)
        self.attempts[key] = (start, count + 1)

    def authenticate(self, db, headers, allow_change=False):
        header = headers.get('Authorization', '')
        token = header[7:] if header.startswith('Bearer ') else ''
        session = self.sessions.get(token)
        if session is None or session['expires'] <= time.monotonic():
            self.sessions.pop(token, None)
            raise Error('La sesión expiró. Vuelve a ingresar.', 401)
        if session['user']['id'] == 0:
            return token, session['user']
        row = db.execute('SELECT * FROM usuarios WHERE id=?', (session['user']['id'],)).fetchone()
        if not row or row['versionCredencial'] != session['user']['versionCredencial']:
            self.sessions.pop(token, None)
            raise Error('Tu acceso cambió. Vuelve a ingresar.', 401)
        if row['requiereCambioPassword']:
            if not future(row['temporalHasta']):
                raise Error('La contraseña temporal venció.', 401)
            if not allow_change:
                raise Error('Primero debes cambiar tu contraseña temporal.', 403)
        return token, person(row)

    @staticmethod
    def require(user, *roles):
        if user['rol'] not in roles:
            raise Error('Tu rol no tiene permiso para esta operación.', 403)

    def issue(self, user):
        instant = time.monotonic()
        self.sessions = {k: v for k, v in self.sessions.items() if v['expires'] > instant}
        if len(self.sessions) >= 200:
            raise Error('Demasiadas sesiones. Intenta más tarde.', 503)
        token = secrets.token_urlsafe(32)
        self.sessions[token] = {'user': user, 'expires': instant + 8 * 3600}
        return {'token': token, 'usuario': user}

    def request(self, method, target, body, headers, ip='127.0.0.1'):
        with self.lock:
            db = connection(self.path)
            try:
                with db:
                    return self._request(db, method, target, body, headers, ip)
            except sqlite3.IntegrityError as exc:
                raise Error('Hay un código duplicado o datos que incumplen las reglas del negocio.') from exc
            finally:
                db.close()

    def _request(self, db, method, target, body, headers, ip):
        uri = urlsplit(target)
        route = uri.path.strip('/')
        query = parse_qs(uri.query)
        if method == 'POST' and route in {'connect', 'auth/login', 'auth/guest', 'auth/register', 'setup', 'auth/password', 'users/reset-password'}:
            self.limit(ip, route)
        if route not in ('health', 'connect') and not secrets.compare_digest(headers.get('X-StockGo-Code', '').encode('utf-8'), self.code.encode('utf-8')):
            raise Error('Código de negocio incorrecto.', 403)
        if route == 'health' and method == 'GET':
            return {'nombre': 'StockGo', 'configurado': bool(config(db, 'propietario')), 'nombreNegocio': config(db, 'nombreEmpresa')}
        if route == 'connect' and method == 'POST':
            if not secrets.compare_digest(text(body, 'codigo').encode('utf-8'), self.code.encode('utf-8')):
                raise Error('Código de negocio incorrecto.', 403)
            return {'ok': True, 'nombreNegocio': config(db, 'nombreEmpresa')}
        if route == 'setup' and method == 'POST':
            if text(body, 'codigo') != self.code:
                raise Error('Código de negocio incorrecto.', 403)
            create_owner(db, body)
            return {'ok': True}
        if route in ('auth/register', 'auth/login', 'auth/guest') and method == 'POST':
            if not config(db, 'propietario'):
                raise Error('Primero crea el negocio en el servidor de PC.', 409)
            if route == 'auth/register':
                # Compatibilidad con el registro de vendedor de Flutter.
                add_user(db, body)
                return {'ok': True}
            if route == 'auth/guest':
                return self.issue({'id': 0, 'nombre': 'Invitado', 'rol': 'invitado', 'nombres': '', 'apellidos': '',
                                   'codigoInterno': '', 'requiereCambioPassword': False, 'versionCredencial': 0})
            row = db.execute('SELECT * FROM usuarios WHERE nombre=?', (text(body, 'usuario').strip().lower(),)).fetchone()
            if not row or not matches(text(body, 'password'), row):
                raise Error('Usuario o contraseña incorrectos.', 401)
            if row['requiereCambioPassword'] and not future(row['temporalHasta']):
                raise Error('La contraseña temporal venció.', 401)
            return self.issue(person(row))

        token, user = self.authenticate(db, headers, route in ('auth/password', 'auth/logout'))
        admin = user['rol'] == 'administrador'
        if route == 'auth/logout' and method == 'POST':
            self.sessions.pop(token, None)
            return {'ok': True}
        if route == 'auth/password' and method == 'POST':
            self.require(user, 'administrador', 'vendedor')
            actual, new = text(body, 'actual'), text(body, 'nueva')
            valid_password(new)
            if actual == new:
                raise Error('Elige una contraseña diferente.')
            row = db.execute('SELECT * FROM usuarios WHERE id=?', (user['id'],)).fetchone()
            if not matches(actual, row):
                raise Error('La contraseña actual es incorrecta.')
            digest, salt = password_fields(new)
            db.execute("UPDATE usuarios SET password_hash=?,salt=?,versionCredencial=versionCredencial+1,requiereCambioPassword=0,temporalHasta='' WHERE id=?", (digest, salt, user['id']))
            self.audit(db, user, user, 'cambiar_password')
            updated = person(db.execute('SELECT * FROM usuarios WHERE id=?', (user['id'],)).fetchone())
            self.revoke(user['id'], keep=token)
            self.sessions[token]['user'] = updated
            return {'usuario': updated}
        if route == 'auth/profile' and method == 'PUT':
            self.require(user, 'administrador', 'vendedor')
            # Reusar las mismas reglas de identidad, sin cambiar credenciales.
            from .database import identity
            _, _, first, last = identity({'usuario': user['nombre'], 'password': 'ValidacionTemporal',
                                          'nombres': text(body, 'nombres'), 'apellidos': text(body, 'apellidos')})
            db.execute('UPDATE usuarios SET nombres=?,apellidos=? WHERE id=?', (first, last, user['id']))
            return {'usuario': person(db.execute('SELECT * FROM usuarios WHERE id=?', (user['id'],)).fetchone())}
        if route in ('users', 'users/reset-password', 'security/audit', 'server/info'):
            self.require(user, 'administrador')
            if route == 'users' and method == 'GET':
                return {'usuarios': [person(r) for r in db.execute('SELECT * FROM usuarios ORDER BY nombre COLLATE NOCASE')], 'nombreNegocio': config(db, 'nombreEmpresa')}
            if route == 'users' and method == 'POST':
                add_user(db, body, text(body, 'rol', 'vendedor'))
                return {'ok': True}
            if route == 'users/reset-password' and method == 'POST':
                target = integer(body.get('usuarioId'), 1)
                if target == user['id']:
                    raise Error('Para tu cuenta utiliza Cambiar mi contraseña.')
                actor = db.execute('SELECT * FROM usuarios WHERE id=?', (user['id'],)).fetchone()
                if not matches(text(body, 'passwordAdmin'), actor):
                    raise Error('La contraseña del administrador es incorrecta.')
                row = db.execute('SELECT * FROM usuarios WHERE id=?', (target,)).fetchone()
                if not row:
                    raise Error('La cuenta no pertenece a este negocio.', 404)
                temporary = 'SG-' + secrets.token_urlsafe(18)
                digest, salt = password_fields(temporary)
                db.execute('UPDATE usuarios SET password_hash=?,salt=?,versionCredencial=versionCredencial+1,requiereCambioPassword=1,temporalHasta=? WHERE id=?',
                           (digest, salt, (now() + timedelta(minutes=30)).isoformat(), target))
                self.audit(db, user, person(row), 'restablecer_password')
                self.revoke(target)
                return {'temporal': temporary, 'validezMinutos': 30}
            if route == 'security/audit' and method == 'GET':
                return {'eventos': [dict(r) for r in db.execute('SELECT * FROM auditoria_seguridad ORDER BY id DESC LIMIT 200')]}
            if route == 'server/info' and method == 'GET':
                return {'codigo': self.code, 'direcciones': self.addresses()}
        if route == 'sales':
            self.require(user, 'administrador', 'vendedor')
            if method == 'GET':
                rows = db.execute('SELECT * FROM ventas' + ('' if admin else ' WHERE usuarioId=?') + ' ORDER BY id DESC', () if admin else (user['id'],))
                return {'ventas': [self.sale(db, r, admin) for r in rows]}
            if method == 'POST':
                return {'venta': self.sell(db, user, body)}
        if route == 'products' and method == 'GET':
            inactive = admin and query.get('inactivos', ['false'])[0] == 'true'
            search = query.get('q', [''])[0].strip().replace('\\', '\\\\').replace('%', '\\%').replace('_', '\\_')
            condition = ' OR '.join(f"{key} LIKE ? ESCAPE '\\'" for key in ('nombre', 'codigo', 'marca', 'numeroParte', 'referenciaOEM', 'compatibilidad'))
            rows = db.execute(f"SELECT * FROM productos WHERE {'1=1' if inactive else 'activo=1'} AND ({condition}) ORDER BY activo DESC,nombre COLLATE NOCASE", ['%' + search + '%'] * 6)
            return {'productos': [self.product(r, admin) for r in rows]}
        match = re.fullmatch(r'products(?:/(\d+))?(?:/(deactivate))?', route)
        if match:
            product_id = int(match[1]) if match[1] else None
            if product_id and method == 'GET' and not match[2]:
                row = db.execute('SELECT * FROM productos WHERE id=?' + ('' if admin else ' AND activo=1'), (product_id,)).fetchone()
                return {'producto': self.product(row, admin) if row else None}
            self.require(user, 'administrador')
            if product_id and match[2] and method == 'POST':
                if db.execute('UPDATE productos SET activo=0 WHERE id=? AND activo=1', (product_id,)).rowcount != 1:
                    raise Error('El producto ya no está activo.')
                return {'ok': True}
            if (method == 'POST' and product_id is None and not match[2]) or (method == 'PUT' and product_id and not match[2]):
                return {'id': self.save_product(db, product_id, body)}
        raise Error('Ruta no encontrada.', 404)

    def revoke(self, user_id, keep=None):
        self.sessions = {t: s for t, s in self.sessions.items() if s['user']['id'] != user_id or t == keep}

    @staticmethod
    def audit(db, actor, target, action):
        db.execute('INSERT INTO auditoria_seguridad(fecha,actorId,actor,objetivoId,objetivo,accion) VALUES(?,?,?,?,?,?)',
                   (now().isoformat(), actor['id'], (actor['nombres'] + ' ' + actor['apellidos']).strip() or actor['nombre'], target['id'], target['nombre'], action))

    @staticmethod
    def product(row, admin):
        data = dict(row)
        data['activo'] = bool(data['activo'])
        data['imagen'] = base64.b64encode(data['imagen']).decode() if data['imagen'] else None
        if not admin:
            data.pop('costo', None)
            data.pop('proveedor', None)
        return data

    @staticmethod
    def save_product(db, product_id, body):
        name, code = text(body, 'nombre').strip(), text(body, 'codigo').strip().upper()
        if not 1 <= len(name) <= 100 or not 1 <= len(code) <= 50:
            raise Error('Nombre máximo 100 caracteres; código máximo 50.')
        price, cost = cents(body.get('precio')), cents(body.get('costo', 0))
        if price < cost:
            raise Error('El precio de venta no puede ser menor al precio de compra.')
        category = text(body, 'categoria', 'Repuesto')
        if category not in CATEGORIES:
            raise Error('Categoría inválida.')
        values = {'nombre': name, 'codigo': code, 'precio': price / 100, 'costo': cost / 100,
                  'cantidad': integer(body.get('cantidad')), 'stockMinimo': integer(body.get('stockMinimo', 0)), 'categoria': category}
        visible = COMMON | set(TECHNICAL[category].split())
        for key in FIELDS:
            value = text(body, key, '').strip()
            if len(value) > 2000:
                raise Error('Cada campo técnico admite hasta 2000 caracteres.')
            values[key] = value if key in visible else ''
        lot, expiry = values['lote'], values['vencimiento']
        if category in ('Lubricante', 'Aditivo') and not lot:
            raise Error('Los lubricantes y aditivos necesitan lote del fabricante.')
        if len(lot) > 100 or re.search(r'[\x00-\x1f]', lot):
            raise Error('El lote admite hasta 100 caracteres en una sola línea.')
        if expiry:
            try:
                if not re.fullmatch(r'\d{4}-\d{2}-\d{2}', expiry):
                    raise ValueError()
                date.fromisoformat(expiry)
            except ValueError as exc:
                raise Error('El vencimiento debe ser una fecha válida AAAA-MM-DD.') from exc
        image = body.get('imagen')
        if image is not None:
            if not isinstance(image, str):
                raise Error('La imagen debe estar en Base64.')
            try:
                image = base64.b64decode(image, validate=True)
            except ValueError as exc:
                raise Error('Imagen Base64 inválida.') from exc
            if len(image) > 5 * 1024 * 1024 or not (image.startswith(b'\x89PNG\r\n\x1a\n') or image.startswith(b'\xff\xd8\xff') or (image.startswith(b'RIFF') and image[8:12] == b'WEBP')):
                raise Error('Usa una imagen PNG, JPEG o WebP de hasta 5 MB.')
        values['imagen'] = image
        if product_id:
            old = db.execute('SELECT * FROM productos WHERE id=? AND activo=1', (product_id,)).fetchone()
            if not old:
                raise Error('El producto no existe o está desactivado.', 404)
            if old['cantidad'] > 0 and old['lote'].strip() and (old['lote'].strip() != lot or old['vencimiento'].strip() != expiry):
                raise Error('No cambies lote ni vencimiento mientras existan unidades. Crea otro código para el lote nuevo.')
            assignments = ','.join(f'"{k}"=?' for k in values)
            db.execute(f'UPDATE productos SET {assignments} WHERE id=?', [*values.values(), product_id])
            return product_id
        columns = ','.join(f'"{k}"' for k in values)
        return db.execute(f"INSERT INTO productos({columns}) VALUES({','.join('?' for _ in values)})", list(values.values())).lastrowid

    @staticmethod
    def sale(db, row, admin):
        result = dict(row)
        # Mantener respuesta del contrato sin solicitud/usuarioId internos.
        result = {k: result[k] for k in ('id', 'fecha', 'vendedor', 'codigoVendedor', 'totalCentavos')}
        details = [dict(r) for r in db.execute('SELECT * FROM venta_detalles WHERE ventaId=? ORDER BY id', (row['id'],))]
        if not admin:
            for detail in details:
                detail.pop('costoCentavos', None)
        result['detalles'] = details
        return result

    def sell(self, db, user, body):
        if not user['nombres'] or not user['apellidos']:
            raise Error('Completa nombres y apellidos antes de vender.')
        request_id = text(body, 'solicitud')
        lines = body.get('lineas')
        if not re.fullmatch(r'[a-zA-Z0-9_-]{16,80}', request_id) or not isinstance(lines, list) or not 1 <= len(lines) <= 200:
            raise Error('Revisa la solicitud y los productos de la venta.')
        ids = set()
        for line in lines:
            if not isinstance(line, dict):
                raise Error('Línea de venta inválida.')
            product_id = integer(line.get('productoId'), 1)
            integer(line.get('cantidad'), 1)
            if product_id in ids:
                raise Error('No repitas un producto en la misma venta.')
            ids.add(product_id)
        admin = user['rol'] == 'administrador'
        # BEGIN IMMEDIATE serializa también frente a otros procesos SQLite.
        db.execute('BEGIN IMMEDIATE')
        previous = db.execute('SELECT * FROM ventas WHERE solicitud=?', (request_id,)).fetchone()
        if previous:
            if previous['usuarioId'] != user['id']:
                raise Error('Esa solicitud pertenece a otra cuenta.')
            details = list(db.execute('SELECT productoId,cantidad FROM venta_detalles WHERE ventaId=?', (previous['id'],)))
            if sorted((r['productoId'], r['cantidad']) for r in details) != sorted((r['productoId'], r['cantidad']) for r in lines):
                raise Error('Esa venta ya fue registrada con otros productos.')
            return self.sale(db, previous, admin)
        details, total = [], 0
        for line in lines:
            row = db.execute('SELECT * FROM productos WHERE id=? AND activo=1', (line['productoId'],)).fetchone()
            if not row:
                raise Error('Un producto ya no está disponible.')
            if row['cantidad'] < line['cantidad']:
                raise Error(f"Stock insuficiente de {row['nombre']}. Disponible: {row['cantidad']}.")
            if row['precio'] < row['costo']:
                raise Error('El precio de venta es inferior al costo.')
            if row['categoria'] in ('Lubricante', 'Aditivo') and not row['lote'].strip():
                raise Error('Falta el lote del fabricante.')
            if row['vencimiento'] and row['vencimiento'] < date.today().isoformat():
                raise Error(f"{row['nombre']} está vencido.")
            price = cents(row['precio'])
            if price <= 0:
                raise Error('El precio de venta debe ser mayor que cero.')
            expected = line.get('precioEsperadoCentavos')
            if expected is not None and integer(expected, 0, 100000000000) != price:
                raise Error('El precio cambió. Actualiza el inventario antes de confirmar.')
            total += price * line['cantidad']
            if total > 9007199254740991:
                raise Error('El total supera el límite permitido.')
            if db.execute('UPDATE productos SET cantidad=cantidad-? WHERE id=? AND activo=1 AND cantidad>=?',
                          (line['cantidad'], row['id'], line['cantidad'])).rowcount != 1:
                raise Error('Las existencias cambiaron. Revisa la venta.')
            details.append((row['id'], row['nombre'], row['codigo'], row['lote'], row['vencimiento'],
                            row['unidadVenta'], line['cantidad'], price, cents(row['costo'])))
        sale_id = db.execute('INSERT INTO ventas(solicitud,usuarioId,vendedor,fecha,totalCentavos,codigoVendedor) VALUES(?,?,?,?,?,?)',
                             (request_id, user['id'], (user['nombres'] + ' ' + user['apellidos']).strip(), now().isoformat(), total, user['codigoInterno'])).lastrowid
        db.executemany('INSERT INTO venta_detalles(ventaId,productoId,nombre,codigo,lote,vencimiento,unidad,cantidad,precioCentavos,costoCentavos) VALUES(?,?,?,?,?,?,?,?,?,?)',
                       [(sale_id, *detail) for detail in details])
        return self.sale(db, db.execute('SELECT * FROM ventas WHERE id=?', (sale_id,)).fetchone(), admin)
