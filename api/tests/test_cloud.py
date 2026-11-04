import base64
from concurrent.futures import ThreadPoolExecutor
import io
import json
import uuid

from PIL import Image
import pytest
from sqlalchemy import select

from stockgo_cloud.domain import Error
from stockgo_cloud.models import Product, Sale

OWNER = {'usuario': 'propietario', 'password': 'Universidad123!', 'nombres': 'Ana', 'apellidos': 'López'}
SELLER = {'usuario': 'juan.perez', 'password': 'Vendedor123!', 'nombres': 'Juan', 'apellidos': 'Pérez'}
CLIENT = {'nombre': 'Carlos Pérez', 'descripcion': 'Cliente de mostrador, recoge aceite para su automóvil.'}


def provision(system, name='Aceitera Central'):
    client, factory, settings, app = system
    response = client.post('/businesses', json={**OWNER, 'negocio': name}, headers={'X-StockGo-Provisioning-Key': settings.provisioning_key})
    assert response.status_code == 201, response.text
    code = response.json()['codigo']
    login = client.post('/auth/login', json=OWNER, headers={'X-StockGo-Code': code})
    assert login.status_code == 200, login.text
    return code, {'X-StockGo-Code': code, 'Authorization': 'Bearer ' + login.json()['token']}


def product(client, headers, **changes):
    data = {'nombre': 'Aceite Motor', 'codigo': 'ACE-001', 'precio': 100.5, 'costo': 80, 'cantidad': 10,
            'categoria': 'Lubricante', 'lote': 'L-2026', 'viscosidadSAE': '5W-30', 'proveedor': 'Privado', **changes}
    response = client.post('/products', json=data, headers=headers)
    assert response.status_code == 200, response.text
    return response.json()['id']


def seller(client, headers):
    assert client.post('/users', json={**SELLER, 'rol': 'vendedor'}, headers=headers).status_code == 200
    result = client.post('/auth/login', json=SELLER, headers=headers)
    return {'X-StockGo-Code': headers['X-StockGo-Code'], 'Authorization': 'Bearer ' + result.json()['token']}


def sale_body(product_id, qty=2):
    return {'solicitud': uuid.uuid4().hex, 'lineas': [{'productoId': product_id, 'cantidad': qty, 'precioEsperadoCentavos': 10050}], 'cliente': CLIENT}


def test_postgresql_isolation_roles_and_pagination(system):
    client, factory, _, _ = system
    code, admin = provision(system)
    vendor = seller(client, admin)
    ids = [product(client, admin, codigo=f'A-{i}') for i in range(3)]
    page = client.get('/products?limit=2', headers=vendor).json()
    assert len(page['productos']) == 2 and page['nextCursor'] == ids[1]
    assert 'costo' not in page['productos'][0] and 'proveedor' not in page['productos'][0]
    assert len(client.get(f"/products?limit=2&cursor={page['nextCursor']}", headers=vendor).json()['productos']) == 1
    assert client.post('/products', json={}, headers=vendor).status_code == 403
    assert client.get('/users', headers=vendor).status_code == 403
    other, other_admin = provision(system, 'Otro negocio')
    assert code != other
    assert client.get('/products', headers=other_admin).json()['productos'] == []
    assert client.get('/products', headers={**vendor, 'X-StockGo-Code': other}).status_code == 401
    assert client.get(f'/products/{ids[0]}', headers=other_admin).json()['producto'] is None


def test_etag_validates_revision_without_returning_catalogue(system):
    client = system[0]; _, admin = provision(system)
    pid = product(client, admin)
    first = client.get('/products?limit=50', headers=admin)
    etag = first.headers['etag']
    cached = client.get('/products?limit=50', headers={**admin, 'If-None-Match': etag})
    assert cached.status_code == 304 and not cached.content
    client.post(f'/products/{pid}/deactivate', json={}, headers=admin)
    changed = client.get('/products?limit=50', headers={**admin, 'If-None-Match': etag})
    assert changed.status_code == 200 and changed.headers['etag'] != etag


def test_customer_only_name_description_sale_cancel_restores_exactly_once(system):
    client = system[0]; _, admin = provision(system); vendor = seller(client, admin)
    pid = product(client, admin)
    body = sale_body(pid)
    result = client.post('/sales', json=body, headers=vendor)
    assert result.status_code == 200, result.text
    ticket = result.json()['venta']
    assert ticket['cliente'] == CLIENT and ticket['vendedor'] == 'Juan Pérez'
    assert 'costoCentavos' not in ticket['detalles'][0]
    retry = client.post('/sales', json=body, headers=vendor).json()['venta']
    assert retry['id'] == ticket['id']
    assert client.get(f'/products/{pid}', headers=admin).json()['producto']['cantidad'] == 8
    assert client.post(f"/sales/{ticket['id']}/cancel", json={'motivo': 'Cliente cancela'}, headers=vendor).status_code == 403
    for _ in range(2):
        cancel = client.post(f"/sales/{ticket['id']}/cancel", json={'motivo': 'Cliente cancela la cuenta'}, headers=admin)
        assert cancel.status_code == 200, cancel.text
        assert cancel.json()['venta']['estado'] == 'anulada'
    assert client.get(f'/products/{pid}', headers=admin).json()['producto']['cantidad'] == 10
    assert len(client.get('/sales', headers=admin).json()['ventas']) == 1
    assert client.post('/sales', json={**sale_body(pid), 'cliente': {}}, headers=vendor).status_code == 400
    changed_client = {**body, 'cliente': {'nombre': 'Otro cliente', 'descripcion': ''}}
    assert client.post('/sales', json=changed_client, headers=vendor).status_code == 409


def test_cancellation_does_not_mix_manufacturer_lots(system):
    client = system[0]; _, admin = provision(system)
    pid = product(client, admin, cantidad=2)
    ticket = client.post('/sales', json=sale_body(pid), headers=admin).json()['venta']
    p = client.get(f'/products/{pid}', headers=admin).json()['producto']
    p.update(lote='LOTE-NUEVO', cantidad=5)
    assert client.put(f'/products/{pid}', json=p, headers=admin).status_code == 200
    assert client.post(f"/sales/{ticket['id']}/cancel", json={'motivo': 'Cliente cancela cuenta anterior'}, headers=admin).status_code == 200
    products = client.get('/products', headers=admin).json()['productos']
    assert sum(p['cantidad'] for p in products) == 7
    assert {p['lote']: p['cantidad'] for p in products} == {'L-2026': 2, 'LOTE-NUEVO': 5}


def test_concurrency_stock_atomic_rollback_and_idempotence(system):
    client, _, _, app = system; code, admin = provision(system)
    pid = product(client, admin, cantidad=1)
    token = admin['Authorization'][7:]
    def submit(body):
        try: return app.state.service.handle('POST', 'sales', body, code, token)[0]
        except Error as exc: return exc.status
    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(submit, [sale_body(pid, 1), sale_body(pid, 1)]))
    assert sorted(results) == [200, 400]
    assert client.get(f'/products/{pid}', headers=admin).json()['producto']['cantidad'] == 0
    pid2 = product(client, admin, codigo='OTHER', cantidad=3)
    body = sale_body(pid2, 1); body['lineas'].append({'productoId': 999999, 'cantidad': 1})
    assert client.post('/sales', json=body, headers=admin).status_code == 400
    assert client.get(f'/products/{pid2}', headers=admin).json()['producto']['cantidad'] == 3
    identical = sale_body(pid2, 1)
    with ThreadPoolExecutor(max_workers=2) as pool:
        assert list(pool.map(submit, [identical, identical])) == [200, 200]
    assert client.get(f'/products/{pid2}', headers=admin).json()['producto']['cantidad'] == 2


def test_password_reset_forced_change_revocation_and_audit(system):
    client = system[0]; _, admin = provision(system); vendor = seller(client, admin)
    target = next(u for u in client.get('/users', headers=admin).json()['usuarios'] if u['rol'] == 'vendedor')
    body = {'usuarioId': target['id'], 'passwordAdmin': OWNER['password']}
    temporary = client.post('/users/reset-password', json=body, headers=admin).json()['temporal']
    assert client.get('/products', headers=vendor).status_code == 401
    login = client.post('/auth/login', json={**SELLER, 'password': temporary}, headers=admin).json()
    new = {**admin, 'Authorization': 'Bearer ' + login['token']}
    assert login['usuario']['requiereCambioPassword']
    assert client.get('/products', headers=new).status_code == 403
    change = client.post('/auth/password', json={'actual': temporary, 'nueva': 'NuevaPersonal123!'}, headers=new)
    assert change.status_code == 200 and not change.json()['usuario']['requiereCambioPassword']
    assert client.get('/products', headers=new).status_code == 200
    audit = client.get('/security/audit', headers=admin).json()
    assert len(audit['eventos']) == 2 and temporary not in json.dumps(audit)


def test_websocket_auth_rpc_push_and_revoked_session(system):
    client, factory, settings, app = system
    code, admin = provision(system); vendor = seller(client, admin)
    with client.websocket_connect('/ws') as ws:
        ws.send_json({'type': 'auth', 'codigo': code, 'token': vendor['Authorization'][7:]})
        assert ws.receive_json()['type'] == 'ready'
        ws.send_json({'type': 'request', 'id': 'catalogue_1', 'method': 'GET', 'path': 'products?limit=50'})
        while True:
            frame = ws.receive_json()
            if frame.get('id') == 'catalogue_1': break
        assert frame['status'] == 200 and frame['data']['productos'] == []
        product(client, admin)
        while True:
            event = ws.receive_json()
            if event.get('domain') == 'products': break
        assert event['type'] == 'changed' and 'productos' not in event
        target = next(u for u in client.get('/users', headers=admin).json()['usuarios'] if u['rol'] == 'vendedor')
        client.post('/users/reset-password', json={'usuarioId': target['id'], 'passwordAdmin': OWNER['password']}, headers=admin)
        assert ws.receive_json()['type'] == 'session_invalidated'


def test_images_thumbnail_validation_and_throttle(system):
    client = system[0]; _, admin = provision(system)
    image = io.BytesIO(); Image.new('RGB', (1000, 800), 'blue').save(image, 'PNG')
    original = base64.b64encode(image.getvalue()).decode()
    pid = product(client, admin, imagen=original)
    thumbnail = client.get('/products', headers=admin).json()['productos'][0]['imagen']
    assert len(thumbnail) < len(original)
    assert client.get(f'/products/{pid}', headers=admin).json()['producto']['imagen'] == original
    for _ in range(10): client.post('/connect', json={'codigo': 'incorrecto'})
    assert client.post('/connect', json={'codigo': 'incorrecto'}).status_code == 429
    invalid = client.post('/products', json={'nombre': 'X', 'codigo': 'X', 'precio': 2, 'costo': 3, 'cantidad': 1}, headers=admin)
    assert invalid.status_code == 400
