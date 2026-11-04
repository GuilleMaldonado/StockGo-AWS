"""Proceso efímero exclusivo para pruebas Kotlin/Flutter. Nunca usa datos reales."""
import argparse
import json
from pathlib import Path
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from stockgo.database import Catalog, sg1
from stockgo.http_server import Server


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--import-source')
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='stockgo_contract_') as root:
        catalog = Catalog(root)
        if args.import_source:
            business = catalog.import_database(args.import_source)
        else:
            business = catalog.create('Negocio de prueba', {
                'usuario': 'propietario', 'password': 'Universidad123!', 'nombres': 'Ana', 'apellidos': 'López'})
        server = Server(business['ruta'], '127.0.0.1', 0)
        server.start()
        url = f'http://127.0.0.1:{server.port}'
        print(json.dumps({'url': url, 'codigo': server.service.code, 'sg1': sg1(url, server.service.code)}), flush=True)
        try:
            sys.stdin.read()
        finally:
            server.stop()


if __name__ == '__main__':
    main()
