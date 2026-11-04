from alembic import context
from stockgo_cloud.db import create_database
from stockgo_cloud.models import Base
from stockgo_cloud.settings import Settings

engine, _ = create_database(Settings.from_env())
with engine.connect() as connection:
    context.configure(connection=connection, target_metadata=Base.metadata, compare_type=True)
    with context.begin_transaction():
        context.run_migrations()
engine.dispose()
