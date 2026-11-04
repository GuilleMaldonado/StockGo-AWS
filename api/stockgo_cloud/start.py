"""Migrar antes de servir. La clave advisory evita migraciones concurrentes."""
import os
from pathlib import Path
import subprocess
import sys

from dotenv import load_dotenv
from sqlalchemy import text
import uvicorn

from .db import create_database
from .settings import Settings


def main():
    load_dotenv()
    root = Path(__file__).resolve().parents[1]
    engine, _ = create_database(Settings.from_env())
    try:
        with engine.connect() as db:
            db.execute(text('SELECT pg_advisory_lock(734020261104)'))
            try:
                subprocess.run([sys.executable, '-m', 'alembic', '-c', str(root / 'alembic.ini'), 'upgrade', 'head'], check=True)
            finally: db.execute(text('SELECT pg_advisory_unlock(734020261104)'))
    finally: engine.dispose()
    uvicorn.run('stockgo_cloud.app:create_app', factory=True, host='0.0.0.0', port=int(os.getenv('PORT', '8081')),
                workers=int(os.getenv('WEB_CONCURRENCY', '1')), proxy_headers=True,
                forwarded_allow_ips=os.getenv('FORWARDED_ALLOW_IPS', '127.0.0.1'),
                ws_ping_interval=30, ws_ping_timeout=20, ws_max_size=8 * 1024 * 1024,
                access_log=False)


if __name__ == '__main__': main()
