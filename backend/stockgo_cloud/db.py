import os
from sqlalchemy import create_engine
from sqlalchemy.engine import URL, make_url
from sqlalchemy.orm import sessionmaker


def create_database(settings):
    url = make_url(settings.database_url) if settings.database_url else URL.create(
        'postgresql+psycopg', username=os.environ['DB_USER'], password=os.environ['DB_PASSWORD'],
        host=os.environ['DB_HOST'], port=int(os.getenv('DB_PORT', '5432')), database=os.getenv('DB_NAME', 'stockgo'))
    if url.get_backend_name() != 'postgresql':
        raise ValueError('La variante AWS requiere PostgreSQL; SQLite solo se admite como origen de importación.')
    url = url.set(drivername='postgresql+psycopg')
    if settings.environment == 'production':
        # Un parámetro de URL no debe rebajar la verificación configurada.
        url = url.difference_update_query(['sslmode', 'sslrootcert'])
    args = {'connect_timeout': 10, 'application_name': 'StockGoAWS'}
    if settings.environment == 'production':
        args.update(sslmode=settings.sslmode)
        if settings.sslmode == 'verify-full': args['sslrootcert'] = settings.sslrootcert
    engine = create_engine(url, pool_size=settings.pool_size, max_overflow=settings.max_overflow,
                           pool_pre_ping=True, pool_recycle=1800, pool_timeout=10, connect_args=args, echo=False, hide_parameters=True)
    engine._stockgo_connect_args = args
    return engine, sessionmaker(engine, expire_on_commit=False)
