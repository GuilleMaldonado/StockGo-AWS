import os
import uuid
import pytest
from sqlalchemy import create_engine, text
from sqlalchemy.engine import make_url
from fastapi.testclient import TestClient

from stockgo_cloud.app import create_app
from stockgo_cloud.db import create_database
from stockgo_cloud.models import Base
from stockgo_cloud.settings import Settings

TEST_URL = os.getenv('STOCKGO_TEST_DATABASE_URL', 'postgresql+psycopg://stockgo_test@127.0.0.1:55439/stockgo_test')


@pytest.fixture
def system():
    schema = 'stockgo_test_' + uuid.uuid4().hex
    admin = create_engine(TEST_URL)
    with admin.begin() as db: db.execute(text(f'CREATE SCHEMA {schema}'))
    url = make_url(TEST_URL).update_query_dict({'options': f'-csearch_path={schema}'})
    settings = Settings(database_url=url.render_as_string(hide_password=False), provisioning_key='ClaveSoloParaPruebasNoProduccion' * 2)
    engine, factory = create_database(settings)
    Base.metadata.create_all(engine)
    app = create_app(settings, engine, factory)
    try:
        with TestClient(app) as client:
            yield client, factory, settings, app
    finally:
        engine.dispose()
        with admin.begin() as db: db.execute(text(f'DROP SCHEMA {schema} CASCADE'))
        admin.dispose()
