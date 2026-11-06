"""Validaciones de identidad, fichas y hashes compartidas por la API."""
import base64
import hashlib
import hmac
import json
import re
import secrets
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


def normalize(name):
    clean = ' '.join(name.split())
    if not 2 <= len(clean) <= 100:
        raise Error('Nombre de negocio de 2 a 100 caracteres.')
    normalized = ''.join(c for c in unicodedata.normalize('NFD', clean.casefold()) if not unicodedata.combining(c))
    return clean, normalized


def sg1(url, code):
    return 'SG1-' + base64.urlsafe_b64encode(json.dumps({'url': url, 'negocio': code}, separators=(',', ':')).encode()).decode().rstrip('=')
