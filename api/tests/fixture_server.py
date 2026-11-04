"""Proceso de integración Kotlin. PostgreSQL en un esquema efímero exclusivo."""
import json
import os
from pathlib import Path
import socket
import sys
import threading
import time
import uuid

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from sqlalchemy import create_engine, text
from sqlalchemy.engine import make_url
import uvicorn

from stockgo_cloud.app import create_app
from stockgo_cloud.db import create_database
from stockgo_cloud.models import Base
from stockgo_cloud.service import Service
from stockgo_cloud.settings import Settings


def main():
    root_url = os.getenv('STOCKGO_TEST_DATABASE_URL', 'postgresql+psycopg://stockgo_test@127.0.0.1:55439/stockgo_test')
    schema = 'stockgo_kotlin_' + uuid.uuid4().hex
    admin = create_engine(root_url)
    with admin.begin() as db: db.execute(text(f'CREATE SCHEMA {schema}'))
    url = make_url(root_url).update_query_dict({'options': f'-csearch_path={schema}'})
    engine, factory = create_database(Settings(database_url=url.render_as_string(hide_password=False)))
    Base.metadata.create_all(engine)
    sock = socket.socket(); sock.bind(('127.0.0.1', 0)); port = sock.getsockname()[1]
    settings = Settings(public_url=f'http://127.0.0.1:{port}', provisioning_key='SoloPruebaIntegracionNoProduccion' * 2)
    service = Service(factory, settings)
    _, info, _ = service.handle('POST', 'businesses', {'negocio': 'Negocio de prueba', 'usuario': 'propietario',
        'password': 'Universidad123!', 'nombres': 'Ana', 'apellidos': 'López'}, provisioning_key=settings.provisioning_key)
    server = uvicorn.Server(uvicorn.Config(create_app(settings, engine, factory), access_log=False, log_level='error'))
    thread = threading.Thread(target=server.run, kwargs={'sockets': [sock]}, daemon=True)
    thread.start()
    while not server.started:
        if not thread.is_alive(): raise RuntimeError('El servidor no inició.')
        time.sleep(.05)
    print(json.dumps({'url': settings.public_url, 'codigo': info['codigo']}), flush=True)
    try: sys.stdin.read()
    finally:
        server.should_exit = True; thread.join(15)
        engine.dispose()
        with admin.begin() as db: db.execute(text(f'DROP SCHEMA {schema} CASCADE'))
        admin.dispose()


if __name__ == '__main__': main()
