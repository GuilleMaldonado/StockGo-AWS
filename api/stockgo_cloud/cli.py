import argparse
import json
from sqlalchemy import delete
from .db import create_database
from .models import AuthSession, RateLimit, utcnow
from .settings import Settings


def main():
    from dotenv import load_dotenv
    load_dotenv()
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest='command', required=True)
    p = sub.add_parser('import-sqlite'); p.add_argument('path'); p.add_argument('--dry-run', action='store_true')
    sub.add_parser('cleanup')
    args = parser.parse_args()
    engine, factory = create_database(Settings.from_env())
    try:
        if args.command == 'import-sqlite':
            from .import_sqlite import import_database
            print(json.dumps(import_database(factory, args.path, args.dry_run), ensure_ascii=False))
        else:
            with factory.begin() as db:
                db.execute(delete(AuthSession).where(AuthSession.expires_at < utcnow()))
                db.execute(delete(RateLimit).where(RateLimit.expires_at < utcnow()))
    finally: engine.dispose()


if __name__ == '__main__': main()
