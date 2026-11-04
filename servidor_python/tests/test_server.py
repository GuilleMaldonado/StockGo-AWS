import base64
from concurrent.futures import ThreadPoolExecutor
from contextlib import closing
from datetime import timedelta
import hashlib
import json
from pathlib import Path
import sqlite3
import tempfile
import unittest
import urllib.error
import urllib.request

from stockgo.database import Catalog, Error, config, connection, initialize, matches, password_fields, sg1
from stockgo.http_server import Server
from stockgo.service import now


OWNER = {'usuario': 'propietario', 'password': 'Universidad123!', 'nombres': 'Ana María', 'apellidos': 'López García'}
SELLER = {'usuario': 'juan.perez', 'password': 'Vendedor123!', 'nombres': 'Juan', 'apellidos': 'Pérez'}


class ServerTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.catalog = Catalog(self.temp.name)
        self.business = self.catalog.create('Aceitera Central', OWNER)
        self.server = Server(self.business['ruta'], '127.0.0.1', 0)
        self.server.start()
        self.url = f'http://127.0.0.1:{self.server.port}'
        self.code = self.server.service.code
        self.admin = self.call('POST', 'auth/login', OWNER)['token']

    def tearDown(self):
        self.server.stop()
        self.temp.cleanup()

    def call(self, method, path, data=None, token=None, code=None, expected=200, origin=None):
        headers = {'Content-Type': 'application/json', 'X-StockGo-Code': self.code if code is None else code}
        if token:
            headers['Authorization'] = 'Bearer ' + token
        if origin:
            headers['Origin'] = origin
        request = urllib.request.Request(self.url + '/' + path, json.dumps(data).encode() if data is not None else None, headers, method=method)
        try:
            response = urllib.request.urlopen(request, timeout=10)
        except urllib.error.HTTPError as exc:
            response = exc
        with response:
            self.assertEqual(expected, response.status, f'{path}: {response.read() if response.status != expected else ""}')
            body = response.read()
            return json.loads(body) if body else {}

    def seller(self):
        self.call('POST', 'users', {**SELLER, 'rol': 'vendedor'}, self.admin)
        return self.call('POST', 'auth/login', SELLER)['token']

    def product(self, expected=200, **changes):
        data = {'nombre': 'Aceite Motor', 'codigo': 'ACE-001', 'categoria': 'Lubricante', 'costo': 80.0,
                'precio': 100.5, 'cantidad': 10, 'stockMinimo': 2, 'marca': 'Ejemplo', 'tipo': 'Aceite de motor',
                'lote': 'LOTE-2026', 'unidadVenta': 'Botella', 'viscosidadSAE': '5W-30', 'proveedor': 'Distribuidor privado', **changes}
        result = self.call('POST', 'products', data, self.admin, expected=expected)
        return result.get('id')

    def test_roles_images_search_and_soft_delete(self):
        seller = self.seller()
        guest = self.call('POST', 'auth/guest', {})['token']
        # PNG 1x1 válido; mismo formato Base64 utilizado por Flutter.
        image = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII='
        product_id = self.product(imagen=image)
        self.call('POST', 'products', {}, seller, expected=403)
        self.call('GET', 'users', token=guest, expected=403)
        result = self.call('GET', 'products?q=ACE-001', token=seller)['productos'][0]
        self.assertNotIn('costo', result)
        self.assertNotIn('proveedor', result)
        self.assertEqual(image, result['imagen'])
        self.assertEqual(True, result['activo'])
        self.assertEqual(1, len(self.call('GET', 'products?q=Ejemplo', token=guest)['productos']))
        self.call('POST', f'products/{product_id}/deactivate', {}, guest, expected=403)
        self.call('POST', f'products/{product_id}/deactivate', {}, self.admin)
        self.assertEqual([], self.call('GET', 'products?inactivos=true', token=seller)['productos'])
        self.assertEqual(1, len(self.call('GET', 'products?inactivos=true', token=self.admin)['productos']))
        self.assertIsNone(self.call('GET', f'products/{product_id}', token=guest)['producto'])

    def test_sale_transaction_idempotence_snapshot_and_permissions(self):
        seller = self.seller()
        product_id = self.product()
        sale = {'solicitud': 'venta_universidad_0001', 'lineas': [{'productoId': product_id, 'cantidad': 3, 'precioEsperadoCentavos': 10050}]}
        first = self.call('POST', 'sales', sale, seller)['venta']
        repeated = self.call('POST', 'sales', sale, seller)['venta']
        self.assertEqual(first['id'], repeated['id'])
        self.assertEqual(30150, first['totalCentavos'])
        self.assertNotIn('costoCentavos', first['detalles'][0])
        self.assertEqual('Juan Pérez', first['vendedor'])
        self.assertTrue(first['codigoVendedor'].startswith('VD-'))
        self.assertEqual(7, self.call('GET', f'products/{product_id}', token=self.admin)['producto']['cantidad'])
        self.call('POST', 'sales', sale, self.admin, expected=400)
        bad = {'solicitud': 'venta_universidad_0002', 'lineas': [{'productoId': product_id, 'cantidad': 2}, {'productoId': 999, 'cantidad': 1}]}
        self.call('POST', 'sales', bad, seller, expected=400)
        self.assertEqual(7, self.call('GET', f'products/{product_id}', token=self.admin)['producto']['cantidad'])
        self.assertEqual(8000, self.call('GET', 'sales', token=self.admin)['ventas'][0]['detalles'][0]['costoCentavos'])
        self.assertEqual(1, len(self.call('GET', 'sales', token=seller)['ventas']))
        self.assertEqual('LOTE-2026', first['detalles'][0]['lote'])

    def test_concurrent_sales_do_not_oversell(self):
        seller = self.seller()
        product_id = self.product(cantidad=1)
        def sell(index):
            try:
                return self.server.service.request('POST', '/sales', {'solicitud': f'concurrente_venta_{index:04}', 'lineas': [{'productoId': product_id, 'cantidad': 1}]},
                                                   {'X-StockGo-Code': self.code, 'Authorization': 'Bearer ' + seller})
            except Error as exc:
                return str(exc)
        with ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(sell, [1, 2]))
        self.assertEqual(1, sum(isinstance(r, dict) for r in results))
        self.assertEqual(0, self.call('GET', f'products/{product_id}', token=self.admin)['producto']['cantidad'])

    def test_validation_and_lot_immutability(self):
        for changes in [{'precio': 70}, {'precio': 100.123}, {'cantidad': 1.5}, {'lote': ''}, {'vencimiento': '2026-02-30'}, {'imagen': 'no-es-base64'}]:
            self.product(expected=400, **changes)
        product_id = self.product()
        data = self.call('GET', f'products/{product_id}', token=self.admin)['producto']
        data['lote'] = 'OTRO'
        self.call('PUT', f'products/{product_id}', data, self.admin, expected=400)
        self.call('POST', 'users', {**SELLER, 'nombres': 'Juan123'}, self.admin, expected=400)
        self.call('POST', 'users', {**SELLER, 'usuario': 'juan123'}, self.admin, expected=400)
        self.call('POST', 'sales', {'solicitud': 'precio_cambio_000000', 'lineas': [{'productoId': product_id, 'cantidad': 1, 'precioEsperadoCentavos': 999}]}, self.admin, expected=400)
        self.product(codigo='VENCIDO', vencimiento='2020-01-01')
        expired = self.call('GET', 'products?q=VENCIDO', token=self.admin)['productos'][0]
        self.call('POST', 'sales', {'solicitud': 'vencido_venta_000000', 'lineas': [{'productoId': expired['id'], 'cantidad': 1}]}, self.admin, expected=400)

    def test_reset_force_change_revoke_expiry_and_audit(self):
        seller = self.seller()
        user = next(u for u in self.call('GET', 'users', token=self.admin)['usuarios'] if u['nombre'] == SELLER['usuario'])
        body = {'usuarioId': user['id'], 'passwordAdmin': 'incorrecta'}
        self.call('POST', 'users/reset-password', body, self.admin, expected=400)
        body['passwordAdmin'] = OWNER['password']
        temporary = self.call('POST', 'users/reset-password', body, self.admin)['temporal']
        self.call('GET', 'products', token=seller, expected=401)
        session = self.call('POST', 'auth/login', {**SELLER, 'password': temporary})
        self.assertTrue(session['usuario']['requiereCambioPassword'])
        self.call('GET', 'products', token=session['token'], expected=403)
        updated = self.call('POST', 'auth/password', {'actual': temporary, 'nueva': 'PersonalNueva123!'}, session['token'])
        self.assertFalse(updated['usuario']['requiereCambioPassword'])
        self.call('GET', 'products', token=session['token'])
        audit = self.call('GET', 'security/audit', token=self.admin)
        self.assertEqual(2, len(audit['eventos']))
        self.assertNotIn(temporary, json.dumps(audit))
        self.call('POST', 'auth/login', {**SELLER, 'password': temporary}, expected=401)
        temporary = self.call('POST', 'users/reset-password', body, self.admin)['temporal']
        with closing(connection(self.business['ruta'])) as db, db:
            db.execute('UPDATE usuarios SET temporalHasta=? WHERE id=?', ((now() - timedelta(minutes=1)).isoformat(), user['id']))
        self.call('POST', 'auth/login', {**SELLER, 'password': temporary}, expected=401)

    def test_business_isolation_import_and_sg1(self):
        product_id = self.product()
        other = self.catalog.create('Otro negocio', OWNER)
        with closing(connection(other['ruta'])) as db:
            self.assertNotEqual(self.code, config(db, 'codigoNegocio'))
            self.assertEqual(0, db.execute('SELECT COUNT(*) FROM productos').fetchone()[0])
        self.call('POST', 'connect', {'codigo': 'otro'}, expected=403)
        self.call('POST', 'connect', {'codigo': 'código incorrecto'}, expected=403)
        self.call('GET', 'products', token=self.admin, code='otro', expected=403)
        with self.assertRaises(Error):
            self.catalog.create('  ACEITERA  CENTRAL ', OWNER)
        target = Catalog(Path(self.temp.name) / 'importacion')
        before = hashlib.sha256(Path(self.business['ruta']).read_bytes()).hexdigest()
        imported = target.import_database(self.business['ruta'])
        self.assertEqual(before, hashlib.sha256(Path(self.business['ruta']).read_bytes()).hexdigest())
        with closing(connection(imported['ruta'])) as db:
            row = db.execute('SELECT * FROM usuarios WHERE nombre=?', (OWNER['usuario'],)).fetchone()
            self.assertTrue(matches(OWNER['password'], row))
            self.assertEqual(self.code, config(db, 'codigoNegocio'))
            self.assertEqual(product_id, db.execute('SELECT id FROM productos').fetchone()[0])
        with self.assertRaises(Error):
            target.import_database(self.business['ruta'])
        code = sg1(self.url, self.code)
        payload = code[4:] + '=' * (-len(code[4:]) % 4)
        self.assertEqual({'url': self.url, 'negocio': self.code}, json.loads(base64.urlsafe_b64decode(payload)))

    def test_throttle_cors_logout_and_guest_cannot_sell(self):
        self.call('GET', 'health', origin='https://evil.example', expected=403)
        self.call('GET', 'health', origin='http://localhost:8080')
        guest = self.call('POST', 'auth/guest', {})['token']
        self.call('POST', 'sales', {}, guest, expected=403)
        self.call('POST', 'auth/logout', {}, guest)
        self.call('GET', 'products', token=guest, expected=401)
        for _ in range(10):
            self.call('POST', 'connect', {'codigo': self.code})
        self.call('POST', 'connect', {'codigo': self.code}, expected=429)


if __name__ == '__main__':
    unittest.main()
