"""Solo origen SQLite v10 de lectura. El destino siempre es PostgreSQL."""
from datetime import datetime
from decimal import Decimal
from pathlib import Path
import sqlite3

from sqlalchemy import select

from .domain import Error, FIELDS, normalize
from .models import Audit, Business, Product, Sale, SaleDetail, User
from .service import make_thumbnail


def parse_date(value):
    return datetime.fromisoformat(value.replace('Z', '+00:00')) if value else None


def import_database(factory, source, dry_run=False):
    path = Path(source).resolve(strict=True)
    original = sqlite3.connect(path.as_uri() + '?mode=ro', uri=True)
    original.row_factory = sqlite3.Row
    try:
        if original.execute('PRAGMA user_version').fetchone()[0] != 10:
            raise Error('Actualiza la base de origen al esquema SQLite 10 antes de importar.')
        if original.execute('PRAGMA quick_check').fetchone()[0] != 'ok' or original.execute('PRAGMA foreign_key_check').fetchone():
            raise Error('La base de origen tiene errores de integridad.')
        original.execute('BEGIN')
        config = dict(original.execute('SELECT clave,valor FROM configuracion'))
        if not config.get('propietario') or not config.get('codigoNegocio') or not config.get('nombreEmpresa'):
            raise Error('Selecciona la base del negocio, no el catálogo general.')
        name, norm = normalize(config['nombreEmpresa'])
        code = config['codigoNegocio']
        with factory() as db:
            transaction = db.begin()
            try:
                if db.get(Business, code) or db.scalar(select(Business).where(Business.normalized_name == norm)):
                    raise Error('Ese identificador o nombre de negocio ya existe.')
                db.add(Business(id=code, name=name, normalized_name=norm)); db.flush()
                users, products, sales = {}, {}, {}
                for row in original.execute('SELECT * FROM usuarios ORDER BY id'):
                    if row['rol'] == 'invitado': continue
                    user = User(business_id=code, nombre=row['nombre'].lower(), password_hash=row['password_hash'], salt=row['salt'],
                                rol=row['rol'], nombres=row['nombres'], apellidos=row['apellidos'], codigoInterno=row['codigoInterno'] or f"US-{row['id']:08}",
                                versionCredencial=row['versionCredencial'], requiereCambioPassword=bool(row['requiereCambioPassword']),
                                temporalHasta=parse_date(row['temporalHasta']))
                    db.add(user); db.flush(); users[row['id']] = user.id
                for row in original.execute('SELECT * FROM productos ORDER BY id'):
                    p = Product(business_id=code, nombre=row['nombre'], codigo=row['codigo'].upper(), precio=Decimal(str(row['precio'])),
                                costo=Decimal(str(row['costo'])), cantidad=row['cantidad'], stockMinimo=row['stockMinimo'],
                                activo=bool(row['activo']), categoria=row['categoria'], imagen=row['imagen'], thumbnail=make_thumbnail(row['imagen']), ficha={k: row[k] for k in FIELDS})
                    db.add(p); db.flush(); products[row['id']] = p
                for row in original.execute('SELECT * FROM ventas ORDER BY id'):
                    sale = Sale(business_id=code, solicitud=row['solicitud'], usuarioId=users[row['usuarioId']], vendedor=row['vendedor'],
                                codigoVendedor=row['codigoVendedor'], fecha=parse_date(row['fecha']), totalCentavos=row['totalCentavos'],
                                cliente={'nombre': 'No registrado en versión anterior', 'descripcion': 'Comprobante histórico importado sin datos de cliente.'}, estado='confirmada')
                    db.add(sale); db.flush(); sales[row['id']] = sale.id
                for row in original.execute('SELECT * FROM venta_detalles ORDER BY id'):
                    p = products[row['productoId']]
                    db.add(SaleDetail(business_id=code, ventaId=sales[row['ventaId']], productoId=p.id, nombre=row['nombre'], codigo=row['codigo'],
                                      lote=row['lote'], vencimiento=row['vencimiento'], unidad=row['unidad'], cantidad=row['cantidad'],
                                      precioCentavos=row['precioCentavos'], costoCentavos=row['costoCentavos'], product_snapshot={**p.ficha, 'categoria': p.categoria}))
                for row in original.execute('SELECT * FROM auditoria_seguridad ORDER BY id'):
                    db.add(Audit(business_id=code, fecha=parse_date(row['fecha']), actorId=users.get(row['actorId'], row['actorId']),
                                 actor=row['actor'], objetivoId=users.get(row['objetivoId'], row['objetivoId']), objetivo=row['objetivo'], accion=row['accion']))
                db.flush()
                result = {'negocio': code, 'usuarios': len(users), 'productos': len(products), 'ventas': len(sales), 'simulacion': dry_run}
                transaction.rollback() if dry_run else transaction.commit()
                return result
            except Exception:
                transaction.rollback(); raise
    finally:
        original.close()
