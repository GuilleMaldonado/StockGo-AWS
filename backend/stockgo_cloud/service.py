"""Una sola capa de reglas para HTTP y WebSocket; PostgreSQL es la autoridad."""
import base64
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal, InvalidOperation
import hashlib
import json
import io
import logging
import re
import secrets
import smtplib
import ssl
from email.message import EmailMessage
from urllib.parse import parse_qs, urlsplit

from sqlalchemy import delete, func, or_, select, text as sql_text, update
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.exc import IntegrityError

from .domain import CATEGORIES, COMMON, FIELDS, TECHNICAL, Error, identity, integer, matches, password_fields, sg1, text, valid_password
from .models import Audit, AuthSession, Business, BusinessRequest, Product, RateLimit, Sale, SaleDetail, User, VendorRequest, utcnow

logger = logging.getLogger('stockgo.recovery')


def person(user):
    if user is None:
        return {'id': 0, 'nombre': 'Invitado', 'rol': 'invitado', 'nombres': '', 'apellidos': '',
                'codigoInterno': '', 'versionCredencial': 0, 'requiereCambioPassword': False}
    return {k: getattr(user, k) for k in ('id', 'nombre', 'rol', 'nombres', 'apellidos', 'codigoInterno', 'versionCredencial', 'requiereCambioPassword')}


def row_password(user):
    return {'salt': user.salt, 'password_hash': user.password_hash}


def cents(value):
    if type(value) not in (int, float, Decimal):
        raise Error('El precio debe ser numérico.')
    try:
        number = Decimal(str(value))
        if not number.is_finite() or not 0 <= number <= 1000000000 or number * 100 != (number * 100).to_integral_value():
            raise Error('Los precios admiten hasta dos decimales, máximo 1,000,000,000.')
        return int(number * 100)
    except InvalidOperation as exc:
        raise Error('Precio inválido.') from exc


def client_snapshot(data):
    if not isinstance(data, dict):
        raise Error('Ingresa la descripción y los datos del cliente de esta venta.')
    limits = {'nombre': 150, 'descripcion': 1000}
    result = {k: text(data, k, '').strip() for k in limits}
    if not 2 <= len(result['nombre']) <= 150:
        raise Error('Ingresa el nombre o descripción del cliente (2 a 150 caracteres).')
    if any(len(result[k]) > limit for k, limit in limits.items()):
        raise Error('Revisa la longitud de los datos del cliente.')
    if any(re.search(r'[\x00-\x08\x0b\x0c\x0e-\x1f]', value) for value in result.values()):
        raise Error('Los datos del cliente contienen caracteres inválidos.')
    return result


def make_thumbnail(image):
    if image is None: return None
    from PIL import Image, ImageOps
    try:
        with Image.open(io.BytesIO(image)) as original:
            if original.width * original.height > 12_000_000:
                raise Error('La imagen tiene demasiados píxeles; redúcela antes de subirla.')
            small = ImageOps.exif_transpose(original)
            small.thumbnail((320, 240))
            small = small.convert('RGB')
            output = io.BytesIO(); small.save(output, 'JPEG', quality=75, optimize=True)
            return output.getvalue()
    except (OSError, ValueError) as exc:
        raise Error('No se pudo decodificar la imagen.') from exc


class Service:
    def __init__(self, factory, settings):
        self.factory = factory
        self.settings = settings

    def send_recovery_email(self, subject, body):
        """Entrega avisos a soporte sin registrar contraseñas ni secretos en logs."""
        cfg = self.settings
        if not all((cfg.recovery_email, cfg.smtp_host, cfg.smtp_username, cfg.smtp_password)):
            logger.warning('Recuperación por correo no configurada; se conservó la solicitud en auditoría.')
            return False
        message = EmailMessage()
        message['Subject'] = subject
        message['From'] = cfg.smtp_from or cfg.smtp_username
        message['To'] = cfg.recovery_email
        message.set_content(body)
        try:
            with smtplib.SMTP(cfg.smtp_host, cfg.smtp_port, timeout=12) as smtp:
                smtp.starttls(context=ssl.create_default_context())
                smtp.login(cfg.smtp_username, cfg.smtp_password)
                smtp.send_message(message)
            return True
        except (OSError, smtplib.SMTPException):
            logger.exception('No fue posible entregar el correo de recuperación.')
            return False

    def recovery_message(self, business, target, temporary=None):
        lines = [
            f'Negocio: {business.name}',
            f'Usuario: {target.nombre}',
            f'Código SG1: {sg1(self.settings.api_public_url, business.id)}',
        ]
        if temporary:
            lines += [
                '', f'Contraseña temporal: {temporary}',
                'Vence en 30 minutos y obliga al usuario a crear una contraseña nueva.',
            ]
        else:
            lines += ['', 'Se solicitó recuperación. Confirma la identidad y restablece la contraseña desde Equipo.']
        return '\n'.join(lines)

    def make_temporary_password(self, db, business, target):
        temporary = 'SG-' + secrets.token_urlsafe(18)
        target.password_hash, target.salt = password_fields(temporary)
        target.versionCredencial += 1
        target.requiereCambioPassword = True
        target.temporalHasta = utcnow() + timedelta(minutes=30)
        db.execute(delete(AuthSession).where(AuthSession.business_id == business.id, AuthSession.user_id == target.id))
        self.notify(db, business.id, 'credentials', target.id)
        return temporary

    def limit(self, ip, route):
        sensitive = {'connect', 'auth/login', 'auth/admin-login', 'auth/user-login', 'auth/guest', 'auth/register', 'auth/password', 'auth/recovery-request', 'auth/admin-recovery-request', 'users/reset-password', 'ws/auth', 'businesses', 'business-requests', 'vendor-requests'}
        if route not in sensitive:
            return
        instant = utcnow()
        # La creación de negocios tiene una ventana más amplia que el inicio
        # de sesión para dificultar abusos sin bloquear el uso normal.
        minutes = 60 if route == 'businesses' else 1
        bucket = int(instant.timestamp()) // (60 * minutes)
        key = hashlib.sha256(f'{ip}|{route}|{bucket}'.encode()).hexdigest()
        with self.factory.begin() as db:
            statement = insert(RateLimit).values(key=key, hits=1, expires_at=instant + timedelta(minutes=minutes * 2))
            hits = db.scalar(statement.on_conflict_do_update(index_elements=[RateLimit.key], set_={'hits': RateLimit.hits + 1}).returning(RateLimit.hits))
            if hits > (3 if route in ('businesses', 'auth/admin-recovery-request') else 10):
                raise Error('Demasiados intentos. Espera antes de volver a intentar.', 429)

    def authenticate(self, db, code, token, allow_change=False):
        business = db.get(Business, code)
        digest = hashlib.sha256(token.encode()).hexdigest()
        session = db.get(AuthSession, digest)
        if business is None or session is None or session.business_id != code or session.expires_at <= utcnow():
            raise Error('La sesión expiró o no pertenece a este negocio. Vuelve a ingresar.', 401)
        user = db.get(User, session.user_id) if session.user_id else None
        if session.user_id and (not user or user.business_id != code or user.versionCredencial != session.credential_version):
            raise Error('Tu acceso cambió. Vuelve a ingresar.', 401)
        if user and user.requiereCambioPassword:
            if not user.temporalHasta or user.temporalHasta <= utcnow():
                raise Error('La contraseña temporal venció.', 401)
            if not allow_change:
                raise Error('Primero debes cambiar tu contraseña temporal.', 403)
        return business, session, user

    def websocket_identity(self, code, token):
        with self.factory() as db:
            business, session, user = self.authenticate(db, code, token, True)
            return {'business': business.id, 'user_id': user.id if user else 0, 'session_hash': session.token_hash,
                    'expires_at': session.expires_at.timestamp()}

    @staticmethod
    def require(user, *roles):
        if user is None or user.rol not in roles:
            raise Error('Tu rol no tiene permiso para esta operación.', 403)

    @staticmethod
    def notify(db, business_id, domain, user_id=None, except_hash=None):
        version = None
        if domain in ('products', 'sales', 'users'):
            column = getattr(Business, domain + '_version')
            version = db.scalar(update(Business).where(Business.id == business_id).values({column: column + 1}).returning(column))
        payload = json.dumps({'business': business_id, 'domain': domain, 'version': version,
                              'user_id': user_id, 'except_hash': except_hash}, separators=(',', ':'))
        db.execute(select(func.pg_notify('stockgo_changes', payload)))

    def issue(self, db, business, user):
        db.execute(delete(AuthSession).where(AuthSession.expires_at < utcnow()))
        token = secrets.token_urlsafe(32)
        db.add(AuthSession(token_hash=hashlib.sha256(token.encode()).hexdigest(), business_id=business.id,
                           user_id=user.id if user else None, credential_version=user.versionCredencial if user else 0,
                           expires_at=utcnow() + timedelta(hours=8)))
        return {'token': token, 'usuario': person(user)}

    def create_user(self, db, code, data, role='vendedor'):
        username, password, first, last = identity(data)
        if role not in ('administrador', 'vendedor'):
            raise Error('Selecciona Administrador o Vendedor. El invitado entra sin cuenta.')
        # El nombre de usuario es global: permite que un vendedor inicie sesión
        # desde Android sin volver a pegar el código SG1 de su negocio.
        if db.scalar(select(User).where(User.nombre == username)):
            raise Error('Ese usuario ya existe. Elige otro usuario.', 409)
        digest, salt = password_fields(password)
        user = User(business_id=code, nombre=username, password_hash=digest, salt=salt, rol=role,
                    nombres=first, apellidos=last, codigoInterno=('AD-' if role == 'administrador' else 'VD-') + secrets.token_hex(5).upper())
        db.add(user)
        db.flush()
        return user

    def provision(self, db, body, key):
        from .domain import normalize
        name, normalized = normalize(text(body, 'negocio'))
        # Se valida antes de crear el administrador: el nombre identifica de forma
        # única el negocio y el cliente puede mostrar un aviso comprensible.
        if db.scalar(select(Business).where(Business.normalized_name == normalized)):
            raise Error('Ya existe un negocio con ese nombre. Usa otro nombre o inicia sesión como administrador.', 409)
        business = Business(id=secrets.token_hex(16).upper(), name=name, normalized_name=normalized)
        db.add(business); db.flush()
        self.create_user(db, business.id, body, 'administrador')
        from .domain import sg1
        return {'ok': True, 'nombreNegocio': name, 'codigo': business.id, 'sg1': sg1(self.settings.api_public_url, business.id)}

    def require_platform_key(self, key):
        if not self.settings.provisioning_key or not secrets.compare_digest(key.encode(), self.settings.provisioning_key.encode()):
            raise Error('La operación de plataforma requiere la clave maestra.', 403)

    @staticmethod
    def request_json(request):
        return {'id': request.id, 'negocio': request.name, 'usuario': request.usuario,
                'nombres': request.nombres, 'apellidos': request.apellidos,
                'estado': request.estado, 'creado': request.creado.isoformat()}

    def request_business(self, db, body):
        from .domain import normalize
        name, normalized = normalize(text(body, 'negocio'))
        username, password, first, last = identity(body)
        digest, salt = password_fields(password)
        request = BusinessRequest(name=name, normalized_name=normalized, usuario=username,
                                  nombres=first, apellidos=last, password_hash=digest, salt=salt)
        db.add(request); db.flush()
        return {'ok': True, 'solicitudId': request.id,
                'mensaje': 'Solicitud enviada. El responsable de StockGo debe aprobar el negocio.'}

    def approve_business(self, db, request_id):
        request = db.get(BusinessRequest, request_id)
        if not request or request.estado != 'pendiente':
            raise Error('La solicitud ya no está disponible.', 404)
        business = Business(id=secrets.token_hex(16).upper(), name=request.name, normalized_name=request.normalized_name)
        db.add(business); db.flush()
        user = User(business_id=business.id, nombre=request.usuario, password_hash=request.password_hash, salt=request.salt,
                    rol='administrador', nombres=request.nombres, apellidos=request.apellidos,
                    codigoInterno='AD-' + secrets.token_hex(5).upper())
        db.add(user); request.estado, request.resuelto = 'aprobada', utcnow()
        from .domain import sg1
        return {'ok': True, 'solicitudId': request.id, 'nombreNegocio': business.name,
                'sg1': sg1(self.settings.api_public_url, business.id)}

    def request_vendor(self, db, code, body):
        if not db.get(Business, code):
            raise Error('Código de negocio incorrecto.', 403)
        username, password, first, last = identity(body)
        digest, salt = password_fields(password)
        request = VendorRequest(business_id=code, usuario=username, nombres=first, apellidos=last,
                                password_hash=digest, salt=salt)
        db.add(request); db.flush()
        return {'ok': True, 'solicitudId': request.id,
                'mensaje': 'Solicitud enviada. El administrador del negocio debe aprobarla.'}

    def approve_vendor(self, db, code, request_id):
        request = db.scalar(select(VendorRequest).where(VendorRequest.business_id == code, VendorRequest.id == request_id).with_for_update())
        if not request or request.estado != 'pendiente':
            raise Error('La solicitud ya no está disponible.', 404)
        user = User(business_id=code, nombre=request.usuario, password_hash=request.password_hash, salt=request.salt,
                    rol='vendedor', nombres=request.nombres, apellidos=request.apellidos,
                    codigoInterno='VD-' + secrets.token_hex(5).upper())
        db.add(user); db.flush(); request.estado, request.resuelto = 'aprobada', utcnow()
        return {'ok': True, 'usuario': person(user)}

    def handle(self, method, target, body, code='', token='', ip='unknown', provisioning_key='', if_none_match=''):
        uri = urlsplit(target)
        route = uri.path.strip('/')
        if method in ('POST', 'PUT'):
            self.limit(ip, route)
        try:
            with self.factory.begin() as db:
                return self._handle(db, method, route, parse_qs(uri.query), body, code, token, provisioning_key, if_none_match, target)
        except IntegrityError as exc:
            raise Error('Ese nombre, código o solicitud ya existe, o los datos incumplen las reglas del negocio.', 409) from exc

    def _handle(self, db, method, route, query, body, code, token, provision_key, if_none_match, target):
        if route == 'business-requests' and method == 'POST':
            return 202, self.request_business(db, body), ''
        platform = re.fullmatch(r'platform/business-requests(?:/(\d+)/(approve|reject))?', route)
        if platform:
            self.require_platform_key(provision_key)
            if method == 'GET' and not platform[1]:
                requests = db.scalars(select(BusinessRequest).where(BusinessRequest.estado == 'pendiente').order_by(BusinessRequest.id))
                return 200, {'solicitudes': [self.request_json(item) for item in requests]}, ''
            if method == 'POST' and platform[1] and platform[2] == 'approve':
                return 200, self.approve_business(db, int(platform[1])), ''
            if method == 'POST' and platform[1] and platform[2] == 'reject':
                request = db.get(BusinessRequest, int(platform[1]))
                if not request or request.estado != 'pendiente': raise Error('La solicitud ya no está disponible.', 404)
                request.estado, request.resuelto = 'rechazada', utcnow()
                return 200, {'ok': True}, ''
            raise Error('Ruta no encontrada.', 404)
        if route == 'vendor-requests' and method == 'POST':
            return 202, self.request_vendor(db, code, body), ''
        if route == 'businesses' and method == 'POST':
            return 201, self.provision(db, body, provision_key), ''
        if route == 'health' and method == 'GET':
            business = db.get(Business, code) if code else None
            return 200, {'nombre': 'StockGo AWS', 'configurado': True, 'nombreNegocio': business.name if business else None,
                         'apiVersion': 2, 'websocket': '/ws', 'database': 'postgresql'}, ''
        if route == 'ready' and method == 'GET':
            db.execute(sql_text('SELECT 1'))
            return 200, {'ok': True, 'database': 'postgresql'}, ''
        if route == 'connect' and method == 'POST':
            business = db.get(Business, text(body, 'codigo'))
            if not business:
                raise Error('Código de negocio incorrecto.', 403)
            return 200, {'ok': True, 'nombreNegocio': business.name, 'websocket': '/ws', 'apiVersion': 2}, ''
        # El administrador identifica su negocio por su nombre único. No necesita
        # pegar SG1 en cada dispositivo; la respuesta entrega el vínculo SG1 que
        # el cliente conserva para las operaciones posteriores.
        if route == 'auth/admin-login' and method == 'POST':
            from .domain import normalize, sg1
            _, normalized = normalize(text(body, 'negocio'))
            business = db.scalar(select(Business).where(Business.normalized_name == normalized))
            username = text(body, 'usuario').strip().lower()
            user = db.scalar(select(User).where(User.business_id == business.id, User.nombre == username, User.rol == 'administrador')) if business else None
            if not user or not matches(text(body, 'password'), row_password(user)):
                raise Error('Negocio, usuario o contraseña incorrectos.', 401)
            if user.requiereCambioPassword and (not user.temporalHasta or user.temporalHasta <= utcnow()):
                raise Error('La contraseña temporal venció.', 401)
            result = self.issue(db, business, user)
            result.update({'nombreNegocio': business.name, 'sg1': sg1(self.settings.api_public_url, business.id)})
            return 200, result, ''
        if route == 'auth/user-login' and method == 'POST':
            from .domain import sg1
            username = text(body, 'usuario').strip().lower()
            users = list(db.scalars(select(User).where(User.nombre == username).limit(2)))
            user = users[0] if len(users) == 1 and users[0].rol == 'vendedor' else None
            business = db.get(Business, user.business_id) if user else None
            if not user or not business or not matches(text(body, 'password'), row_password(user)):
                raise Error('Usuario o contraseña incorrectos.', 401)
            if user.requiereCambioPassword and (not user.temporalHasta or user.temporalHasta <= utcnow()):
                raise Error('La contraseña temporal venció.', 401)
            result = self.issue(db, business, user)
            result.update({'nombreNegocio': business.name, 'sg1': sg1(self.settings.api_public_url, business.id)})
            return 200, result, ''
        # El administrador no necesita recordar SG1 para recuperar su propia
        # cuenta. La respuesta sigue siendo neutra para no enumerar usuarios.
        if route == 'auth/admin-recovery-request' and method == 'POST':
            from .domain import normalize
            _, normalized = normalize(text(body, 'negocio'))
            username = text(body, 'usuario').strip().lower()
            business = db.scalar(select(Business).where(Business.normalized_name == normalized))
            target = db.scalar(select(User).where(User.business_id == business.id, User.nombre == username,
                                                    User.rol == 'administrador')) if business else None
            if target:
                temporary = self.make_temporary_password(db, business, target)
                db.add(Audit(business_id=business.id, actorId=0, actor='Recuperación por correo',
                             objetivoId=target.id, objetivo=target.nombre, accion='restablecer_admin_correo'))
                self.send_recovery_email(
                    'StockGo: contraseña temporal de administrador',
                    self.recovery_message(business, target, temporary),
                )
            return 202, {'ok': True, 'mensaje': 'Si la cuenta existe, se enviará una clave temporal al correo de recuperación.'}, ''
        business = db.get(Business, code)
        if not business:
            raise Error('Código de negocio incorrecto.', 403)
        if method == 'POST' and route == 'auth/recovery-request':
            # Respuesta neutra: no revela si un nombre de usuario existe.
            username = text(body, 'usuario').strip().lower()
            target = db.scalar(select(User).where(User.business_id == code, User.nombre == username))
            db.add(Audit(business_id=code, actorId=0, actor='Solicitud de recuperación',
                         objetivoId=target.id if target else 0, objetivo=username[:80], accion='solicitar_recuperacion'))
            if target:
                self.send_recovery_email(
                    'StockGo: solicitud de recuperación', self.recovery_message(business, target)
                )
            self.notify(db, code, 'users')
            return 202, {'ok': True, 'mensaje': 'Si la cuenta existe, el administrador del negocio podrá generar una clave temporal.'}, ''
        if method == 'POST' and route in ('auth/register', 'auth/login', 'auth/guest'):
            if route == 'auth/register':
                self.create_user(db, code, body)
                self.notify(db, code, 'users')
                return 200, {'ok': True}, ''
            user = None
            if route == 'auth/login':
                user = db.scalar(select(User).where(User.business_id == code, User.nombre == text(body, 'usuario').strip().lower()))
                if not user or not matches(text(body, 'password'), row_password(user)):
                    raise Error('Usuario o contraseña incorrectos.', 401)
                if user.requiereCambioPassword and (not user.temporalHasta or user.temporalHasta <= utcnow()):
                    raise Error('La contraseña temporal venció.', 401)
            return 200, self.issue(db, business, user), ''
        business, session, user = self.authenticate(db, code, token, route in ('auth/password', 'auth/logout'))
        admin = bool(user and user.rol == 'administrador')
        vendor_request = re.fullmatch(r'vendor-requests(?:/(\d+)/(approve|reject))?', route)
        if vendor_request:
            self.require(user, 'administrador')
            if method == 'GET' and not vendor_request[1]:
                requests = db.scalars(select(VendorRequest).where(VendorRequest.business_id == code, VendorRequest.estado == 'pendiente').order_by(VendorRequest.id))
                return 200, {'solicitudes': [{'id': item.id, 'usuario': item.usuario, 'nombres': item.nombres,
                                                'apellidos': item.apellidos, 'creado': item.creado.isoformat()} for item in requests]}, ''
            if method == 'POST' and vendor_request[1] and vendor_request[2] == 'approve':
                result = self.approve_vendor(db, code, int(vendor_request[1]))
                self.notify(db, code, 'users')
                return 200, result, ''
            if method == 'POST' and vendor_request[1] and vendor_request[2] == 'reject':
                request = db.scalar(select(VendorRequest).where(VendorRequest.business_id == code, VendorRequest.id == int(vendor_request[1])).with_for_update())
                if not request or request.estado != 'pendiente': raise Error('La solicitud ya no está disponible.', 404)
                request.estado, request.resuelto = 'rechazada', utcnow()
                return 200, {'ok': True}, ''
            raise Error('Ruta no encontrada.', 404)
        if route == 'auth/logout' and method == 'POST':
            db.delete(session)
            return 200, {'ok': True}, ''
        if route == 'auth/profile' and method == 'PUT':
            self.require(user, 'administrador', 'vendedor')
            _, _, first, last = identity({'usuario': user.nombre, 'password': 'ValidacionPerfil',
                                          'nombres': text(body, 'nombres'), 'apellidos': text(body, 'apellidos')})
            user.nombres, user.apellidos = first, last
            self.notify(db, code, 'users')
            return 200, {'usuario': person(user)}, ''
        if route == 'auth/password' and method == 'POST':
            self.require(user, 'administrador', 'vendedor')
            actual, new = text(body, 'actual'), text(body, 'nueva')
            valid_password(new)
            if new == actual or not matches(actual, row_password(user)):
                raise Error('Revisa tu contraseña actual y elige una diferente.')
            db.refresh(user, with_for_update=True)
            if user.versionCredencial != session.credential_version:
                raise Error('Tu acceso cambió. Vuelve a ingresar.', 401)
            user.password_hash, user.salt = password_fields(new)
            user.versionCredencial += 1; user.requiereCambioPassword = False; user.temporalHasta = None
            session.credential_version = user.versionCredencial
            db.execute(delete(AuthSession).where(AuthSession.business_id == code, AuthSession.user_id == user.id, AuthSession.token_hash != session.token_hash))
            self.audit(db, code, user, user.id, user.nombre, 'cambiar_password')
            self.notify(db, code, 'credentials', user.id, session.token_hash)
            return 200, {'usuario': person(user)}, ''
        if route in ('users', 'users/reset-password', 'server/info', 'security/audit'):
            self.require(user, 'administrador')
            if route == 'server/info' and method == 'GET':
                return 200, {'codigo': code, 'direcciones': [self.settings.api_public_url]}, ''
            if route == 'users' and method == 'GET':
                return 200, {'usuarios': [person(u) for u in db.scalars(select(User).where(User.business_id == code).order_by(User.nombre))], 'nombreNegocio': business.name}, ''
            if route == 'users' and method == 'POST':
                self.create_user(db, code, body, text(body, 'rol', 'vendedor'))
                self.notify(db, code, 'users')
                return 200, {'ok': True}, ''
            if route == 'users/reset-password' and method == 'POST':
                target_id = integer(body.get('usuarioId'), 1)
                if target_id == user.id or not matches(text(body, 'passwordAdmin'), row_password(user)):
                    raise Error('Confirma tu contraseña Administrador; para tu cuenta usa Cambiar contraseña.')
                # Orden estable para no cruzar bloqueos entre administradores.
                locked = list(db.scalars(select(User).where(User.business_id == code, User.id.in_(sorted([user.id, target_id]))).order_by(User.id).with_for_update().execution_options(populate_existing=True)))
                target = next((u for u in locked if u.id == target_id), None)
                if not target:
                    raise Error('La cuenta no pertenece a este negocio.', 404)
                if user.versionCredencial != session.credential_version:
                    raise Error('Tu acceso cambió.', 401)
                temporary = self.make_temporary_password(db, business, target)
                self.audit(db, code, user, target.id, target.nombre, 'restablecer_password')
                mailed = self.send_recovery_email(
                    'StockGo: contraseña temporal', self.recovery_message(business, target, temporary)
                )
                return 200, {'temporal': temporary, 'validezMinutos': 30, 'correoEnviado': mailed}, ''
            if route == 'security/audit' and method == 'GET':
                events = db.scalars(select(Audit).where(Audit.business_id == code).order_by(Audit.id.desc()).limit(200))
                return 200, {'eventos': [{k: (getattr(e, k).isoformat() if k == 'fecha' else getattr(e, k)) for k in ('id', 'fecha', 'actorId', 'actor', 'objetivoId', 'objetivo', 'accion')} for e in events]}, ''
        if method == 'GET' and route in ('products', 'sales'):
            if route == 'sales': self.require(user, 'administrador', 'vendedor')
            revision = business.products_version if route == 'products' else business.sales_version
            etag = '"' + hashlib.sha256(f'{code}|{session.user_id}|{session.credential_version}|{revision}|{target}'.encode()).hexdigest() + '"'
            if if_none_match == etag:
                return 304, None, etag
            return 200, self.list_products(db, code, admin, query) if route == 'products' else self.list_sales(db, code, user, query), etag
        if route == 'sales' and method == 'POST':
            self.require(user, 'administrador', 'vendedor')
            return 200, self.sell(db, code, user, body), ''
        cancel = re.fullmatch(r'sales/(\d+)/cancel', route)
        if cancel and method == 'POST':
            self.require(user, 'administrador')
            sale = self.cancel_sale(db, code, user, int(cancel[1]), text(body, 'motivo'))
            return 200, {'venta': self.sale_json(db, sale, True)}, ''
        match = re.fullmatch(r'products(?:/(\d+))?(?:/(deactivate))?', route)
        if match:
            product_id = int(match[1]) if match[1] else None
            product = db.scalar(select(Product).where(Product.business_id == code, Product.id == product_id)) if product_id else None
            if product_id and method == 'GET' and not match[2]:
                return 200, {'producto': self.product_json(product, admin) if product and (admin or product.activo) else None}, ''
            self.require(user, 'administrador')
            if method == 'POST' and match[2] and product_id:
                if not product or not product.activo: raise Error('El producto ya no está activo.', 404)
                product.activo = False
                self.notify(db, code, 'products')
                return 200, {'ok': True}, ''
            if (method == 'POST' and product_id is None) or (method == 'PUT' and product_id and not match[2]):
                if product_id:
                    product = db.scalar(select(Product).where(Product.business_id == code, Product.id == product_id).with_for_update())
                    if not product or not product.activo: raise Error('El producto no existe o está desactivado.', 404)
                product = self.save_product(db, code, product, body)
                self.notify(db, code, 'products')
                return 200, {'id': product.id}, ''
        raise Error('Ruta no encontrada.', 404)

    @staticmethod
    def audit(db, code, actor, target_id, target, action):
        db.add(Audit(business_id=code, actorId=actor.id, actor=(actor.nombres + ' ' + actor.apellidos).strip(),
                     objetivoId=target_id, objetivo=target, accion=action))

    @staticmethod
    def product_json(product, admin, thumbnail=False):
        result = {k: getattr(product, k) for k in ('id', 'nombre', 'codigo', 'cantidad', 'stockMinimo', 'activo', 'categoria')}
        result['precio'] = float(product.precio)
        result.update({k: product.ficha.get(k, '') for k in FIELDS})
        image = product.thumbnail if thumbnail else product.imagen
        result['imagen'] = base64.b64encode(image).decode() if image else None
        if admin: result['costo'] = float(product.costo)
        else: result.pop('proveedor', None)
        return result

    def list_products(self, db, code, admin, query):
        search = query.get('q', [''])[0].strip()[:200]
        cursor = self.query_number(query, 'cursor', 0, 0, 2147483647)
        limit = self.query_number(query, 'limit', 50, 1, 100)
        statement = select(Product).where(Product.business_id == code, Product.id > cursor)
        if not (admin and query.get('inactivos', ['false'])[0] == 'true'):
            statement = statement.where(Product.activo.is_(True))
        if search:
            escaped = '%' + search.replace('\\', '\\\\').replace('%', '\\%').replace('_', '\\_') + '%'
            statement = statement.where(or_(*(column.ilike(escaped, escape='\\') for column in
                                              (Product.nombre, Product.codigo, Product.ficha['marca'].astext, Product.ficha['numeroParte'].astext,
                                               Product.ficha['referenciaOEM'].astext, Product.ficha['compatibilidad'].astext))))
        products = list(db.scalars(statement.order_by(Product.id).limit(limit + 1)))
        return {'productos': [self.product_json(p, admin, thumbnail=True) for p in products[:limit]],
                'nextCursor': products[limit - 1].id if len(products) > limit else None}

    @staticmethod
    def query_number(query, key, default, low, high):
        try:
            value = int(query.get(key, [str(default)])[0])
            if not low <= value <= high: raise ValueError()
            return value
        except (ValueError, TypeError) as exc:
            raise Error('Revisa el tamaño o cursor de la página.') from exc

    @staticmethod
    def save_product(db, code, product, body):
        name, sku = text(body, 'nombre').strip(), text(body, 'codigo').strip().upper()
        if not 1 <= len(name) <= 100 or not 1 <= len(sku) <= 50: raise Error('Revisa nombre (100) y código (50 caracteres).')
        price, cost = cents(body.get('precio')), cents(body.get('costo', 0))
        if price < cost: raise Error('Venta no puede ser menor que compra.')
        category = text(body, 'categoria', 'Repuesto')
        if category not in CATEGORIES: raise Error('Categoría inválida.')
        visible = COMMON | set(TECHNICAL[category].split())
        ficha = {key: text(body, key, '').strip() if key in visible else '' for key in FIELDS}
        if any(len(v) > 2000 for v in ficha.values()): raise Error('Máximo 2000 caracteres por campo técnico.')
        lot, expiry = ficha['lote'], ficha['vencimiento']
        if category in ('Lubricante', 'Aditivo') and not lot: raise Error('Registra el lote del fabricante.')
        if len(lot) > 100 or re.search(r'[\x00-\x1f]', lot): raise Error('Lote inválido; máximo 100 caracteres.')
        if expiry:
            try:
                if not re.fullmatch(r'\d{4}-\d{2}-\d{2}', expiry): raise ValueError()
                date.fromisoformat(expiry)
            except ValueError as exc: raise Error('Vencimiento inválido. Usa AAAA-MM-DD.') from exc
        if product and product.cantidad > 0 and product.ficha.get('lote') and (product.ficha.get('lote') != lot or product.ficha.get('vencimiento') != expiry):
            raise Error('No cambies lote ni vencimiento mientras tenga existencias; crea otro código.')
        # Una edición sin el campo imagen conserva la foto existente. `null` la quita.
        image = body.get('imagen', product.imagen if product else None)
        if image is not None:
            if not isinstance(image, str): raise Error('Imagen inválida.')
            try: image = base64.b64decode(image, validate=True)
            except ValueError as exc: raise Error('Imagen inválida.') from exc
            if len(image) > 5 * 1024 * 1024 or not (image.startswith(b'\x89PNG\r\n\x1a\n') or image.startswith(b'\xff\xd8\xff') or (image.startswith(b'RIFF') and image[8:12] == b'WEBP')):
                raise Error('Usa PNG, JPEG o WebP de hasta 5 MB.')
        product = product or Product(business_id=code, activo=True)
        product.nombre, product.codigo, product.categoria = name, sku, category
        product.precio, product.costo = Decimal(price) / 100, Decimal(cost) / 100
        product.cantidad = integer(body.get('cantidad'))
        product.stockMinimo = integer(body.get('stockMinimo', 0))
        product.ficha, product.imagen = ficha, image
        product.thumbnail = make_thumbnail(image)
        db.add(product); db.flush()
        return product


    def sell(self, db, code, user, body):
        if not user.nombres or not user.apellidos: raise Error('Completa nombres y apellidos antes de vender.')
        request_id, lines = text(body, 'solicitud'), body.get('lineas')
        client = client_snapshot(body.get('cliente'))
        if not re.fullmatch(r'[a-zA-Z0-9_-]{16,80}', request_id) or not isinstance(lines, list) or not 1 <= len(lines) <= 200:
            raise Error('Revisa los productos y la solicitud de venta.')
        seen = set()
        for line in lines:
            if not isinstance(line, dict): raise Error('Línea inválida.')
            pid = integer(line.get('productoId'), 1); integer(line.get('cantidad'), 1)
            if pid in seen: raise Error('No repitas el mismo producto en una venta.')
            seen.add(pid)
        # Serializa el mismo identificador aun cuando llegan reintentos simultáneos a otros workers.
        key = int.from_bytes(hashlib.sha256((code + request_id).encode()).digest()[:8], 'big', signed=True)
        db.execute(select(func.pg_advisory_xact_lock(key)))
        previous = db.scalar(select(Sale).where(Sale.business_id == code, Sale.solicitud == request_id))
        if previous:
            details = list(db.scalars(select(SaleDetail).where(SaleDetail.business_id == code, SaleDetail.ventaId == previous.id)))
            if previous.usuarioId != user.id or previous.cliente != client or sorted((d.productoId, d.cantidad) for d in details) != sorted((l['productoId'], l['cantidad']) for l in lines):
                raise Error('La solicitud ya corresponde a otra venta o cliente.', 409)
            return {'venta': self.sale_json(db, previous, user.rol == 'administrador')}
        products = {p.id: p for p in db.scalars(select(Product).where(Product.business_id == code, Product.id.in_(sorted(seen))).order_by(Product.id).with_for_update())}
        total, details = 0, []
        for line in lines:
            p, qty = products.get(line['productoId']), line['cantidad']
            if not p or not p.activo or p.cantidad < qty: raise Error('Producto no disponible o stock insuficiente.')
            expiry, lot = p.ficha.get('vencimiento', ''), p.ficha.get('lote', '')
            if p.categoria in ('Lubricante', 'Aditivo') and not lot: raise Error('Falta el lote del fabricante.')
            if expiry and expiry < date.today().isoformat(): raise Error(f'{p.nombre} está vencido.')
            price, cost = cents(p.precio), cents(p.costo)
            if price <= 0 or price < cost: raise Error('Revisa el precio y costo del producto.')
            if line.get('precioEsperadoCentavos') is not None and integer(line['precioEsperadoCentavos'], 0, 100000000000) != price:
                raise Error('El precio cambió. Actualiza el inventario antes de confirmar.')
            total += price * qty
            if total > 9007199254740991: raise Error('El total supera el límite.')
            p.cantidad -= qty
            snapshot = self.product_json(p, True); snapshot.pop('imagen', None)
            details.append(SaleDetail(business_id=code, productoId=p.id, nombre=p.nombre, codigo=p.codigo, lote=lot,
                                      vencimiento=expiry, unidad=p.ficha.get('unidadVenta', ''), cantidad=qty,
                                      precioCentavos=price, costoCentavos=cost, product_snapshot=snapshot))
        sale = Sale(business_id=code, solicitud=request_id, usuarioId=user.id, vendedor=(user.nombres + ' ' + user.apellidos).strip(),
                    codigoVendedor=user.codigoInterno, totalCentavos=total, cliente=client, estado='confirmada')
        db.add(sale); db.flush()
        for detail in details: detail.ventaId = sale.id
        db.add_all(details); db.flush()
        self.notify(db, code, 'products'); self.notify(db, code, 'sales')
        return {'venta': self.sale_json(db, sale, user.rol == 'administrador')}

    def list_sales(self, db, code, user, query):
        # Informes completos por rango. El cliente los solicita solo al abrir o recibir evento.
        statement = select(Sale).where(Sale.business_id == code)
        if user.rol != 'administrador': statement = statement.where(Sale.usuarioId == user.id)
        sales = list(db.scalars(statement.order_by(Sale.id.desc())))
        detail_query = select(SaleDetail).join(Sale, Sale.id == SaleDetail.ventaId).where(Sale.business_id == code, SaleDetail.business_id == code)
        if user.rol != 'administrador': detail_query = detail_query.where(Sale.usuarioId == user.id)
        grouped = {}
        for detail in db.scalars(detail_query.order_by(SaleDetail.id)):
            grouped.setdefault(detail.ventaId, []).append(detail)
        return {'ventas': [self.sale_json(db, sale, user.rol == 'administrador', grouped.get(sale.id, [])) for sale in sales]}

    @staticmethod
    def sale_json(db, sale, admin, details=None):
        result = {k: getattr(sale, k) for k in ('id', 'vendedor', 'codigoVendedor', 'totalCentavos', 'cliente', 'estado', 'anuladaPor', 'motivoAnulacion')}
        result['fecha'] = sale.fecha.isoformat()
        result['anuladaFecha'] = sale.anuladaFecha.isoformat() if sale.anuladaFecha else None
        if details is None:
            details = db.scalars(select(SaleDetail).where(SaleDetail.business_id == sale.business_id, SaleDetail.ventaId == sale.id).order_by(SaleDetail.id))
        keys = ('productoId', 'nombre', 'codigo', 'lote', 'vencimiento', 'unidad', 'cantidad', 'precioCentavos') + (('costoCentavos',) if admin else ())
        result['detalles'] = [{k: getattr(d, k) for k in keys} for d in details]
        return result

    def cancel_sale(self, db, code, user, sale_id, reason):
        reason = reason.strip()
        if not 3 <= len(reason) <= 500: raise Error('Indica el motivo de anulación (3–500 caracteres).')
        sale = db.scalar(select(Sale).where(Sale.business_id == code, Sale.id == sale_id).with_for_update())
        if not sale: raise Error('La venta no pertenece a este negocio.', 404)
        if sale.estado == 'anulada': return sale
        details = list(db.scalars(select(SaleDetail).where(SaleDetail.business_id == code, SaleDetail.ventaId == sale.id).order_by(SaleDetail.productoId)))
        products = {p.id: p for p in db.scalars(select(Product).where(Product.business_id == code, Product.id.in_([d.productoId for d in details])).order_by(Product.id).with_for_update())}
        for detail in details:
            product = products[detail.productoId]
            if product.ficha.get('lote', '') != detail.lote or product.ficha.get('vencimiento', '') != detail.vencimiento:
                # Un código pudo reutilizarse para otro lote cuando el anterior quedó en cero.
                # La devolución no mezcla mercancía: crea un SKU separado del lote histórico.
                snapshot = detail.product_snapshot
                suffix = f'-RET-{sale.id}-{detail.productoId}'
                sku = detail.codigo[:50 - len(suffix)] + suffix
                product = db.scalar(select(Product).where(Product.business_id == code, Product.codigo == sku).with_for_update())
                if product is None:
                    ficha = {k: snapshot.get(k, '') for k in FIELDS}
                    ficha.update(lote=detail.lote, vencimiento=detail.vencimiento, unidadVenta=detail.unidad)
                    product = Product(business_id=code, nombre=detail.nombre, codigo=sku,
                                      precio=Decimal(detail.precioCentavos) / 100, costo=Decimal(detail.costoCentavos) / 100,
                                      cantidad=0, stockMinimo=0, activo=True, categoria=snapshot.get('categoria', 'Repuesto'), ficha=ficha)
                    db.add(product)
            if product.cantidad + detail.cantidad > 2147483647: raise Error('La devolución superaría el máximo de existencias.')
            product.cantidad += detail.cantidad
        sale.estado = 'anulada'; sale.anuladaPor = (user.nombres + ' ' + user.apellidos).strip()
        sale.anuladaFecha = utcnow(); sale.motivoAnulacion = reason
        self.audit(db, code, user, sale.id, f'Venta #{sale.id}', 'anular_venta')
        self.notify(db, code, 'products'); self.notify(db, code, 'sales')
        return sale
