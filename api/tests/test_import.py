import base64
import hashlib
from pathlib import Path
import sqlite3

from sqlalchemy import select
from stockgo_cloud.domain import FIELDS, password_fields
from stockgo_cloud.import_sqlite import import_database
from stockgo_cloud.models import Business, Product, Sale, User


def legacy(path):
    db = sqlite3.connect(path)
    fields = ','.join(f'"{k}" TEXT NOT NULL DEFAULT \'\'' for k in FIELDS)
    db.executescript(f"""
        CREATE TABLE usuarios(id INTEGER PRIMARY KEY,nombre TEXT,password_hash TEXT,salt TEXT,rol TEXT,nombres TEXT,apellidos TEXT,codigoInterno TEXT,versionCredencial INTEGER,requiereCambioPassword INTEGER,temporalHasta TEXT);
        CREATE TABLE configuracion(clave TEXT PRIMARY KEY,valor TEXT);
        CREATE TABLE productos(id INTEGER PRIMARY KEY,nombre TEXT,codigo TEXT,precio REAL,costo REAL,cantidad INTEGER,stockMinimo INTEGER,activo INTEGER,categoria TEXT,imagen BLOB,{fields});
        CREATE TABLE ventas(id INTEGER PRIMARY KEY,solicitud TEXT,usuarioId INTEGER,vendedor TEXT,codigoVendedor TEXT,fecha TEXT,totalCentavos INTEGER);
        CREATE TABLE venta_detalles(id INTEGER PRIMARY KEY,ventaId INTEGER,productoId INTEGER,nombre TEXT,codigo TEXT,lote TEXT,vencimiento TEXT,unidad TEXT,cantidad INTEGER,precioCentavos INTEGER,costoCentavos INTEGER);
        CREATE TABLE auditoria_seguridad(id INTEGER PRIMARY KEY,fecha TEXT,actorId INTEGER,actor TEXT,objetivoId INTEGER,objetivo TEXT,accion TEXT);
        PRAGMA user_version=10;
    """)
    digest, salt = password_fields('Historica123!')
    db.execute('INSERT INTO usuarios VALUES(?,?,?,?,?,?,?,?,?,?,?)', (78, 'historico', digest, salt, 'administrador', 'Ana', 'López', 'AD-OLD', 0, 0, ''))
    db.executemany('INSERT INTO configuracion VALUES(?,?)', [('propietario','78'),('nombreEmpresa','Aceitera histórica'),('codigoNegocio','A'*32)])
    db.execute("INSERT INTO productos(id,nombre,codigo,precio,costo,cantidad,stockMinimo,activo,categoria,lote,unidadVenta) VALUES(31,'Filtro','F-OLD',50,30,3,1,1,'Filtro','L-OLD','Unidad')")
    db.execute('INSERT INTO ventas VALUES(?,?,?,?,?,?,?)', (19,'historia_venta_0001',78,'Ana López','AD-OLD','2026-10-01T12:00:00.000Z',5000))
    db.execute('INSERT INTO venta_detalles VALUES(?,?,?,?,?,?,?,?,?,?,?)', (1,19,31,'Filtro','F-OLD','L-OLD','','Unidad',1,5000,3000))
    db.commit(); db.close()


def test_sqlite_to_postgresql_simulation_preserves_hashes_history_and_source(system, tmp_path):
    client, factory, _, _ = system
    source = tmp_path / 'legacy.db'; legacy(source)
    before = hashlib.sha256(source.read_bytes()).hexdigest()
    simulated = import_database(factory, source, dry_run=True)
    assert simulated['simulacion']
    with factory() as db: assert db.get(Business, 'A'*32) is None
    imported = import_database(factory, source)
    assert imported['ventas'] == 1 and imported['productos'] == 1
    assert before == hashlib.sha256(source.read_bytes()).hexdigest()
    login = client.post('/auth/login', json={'usuario':'historico','password':'Historica123!'}, headers={'X-StockGo-Code':'A'*32})
    assert login.status_code == 200
    headers={'X-StockGo-Code':'A'*32,'Authorization':'Bearer '+login.json()['token']}
    sales=client.get('/sales',headers=headers).json()['ventas']
    assert sales[0]['totalCentavos']==5000 and sales[0]['detalles'][0]['lote']=='L-OLD'
    assert sales[0]['cliente']['nombre']=='No registrado en versión anterior'
    assert client.get('/products',headers=headers).json()['productos'][0]['cantidad']==3
