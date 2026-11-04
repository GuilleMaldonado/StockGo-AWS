"""Autocomprobación del EXE con un negocio temporal, sin tocar datos de instalación."""
import json
from pathlib import Path
import tempfile
import urllib.request

from .desktop import Desktop
from .http_server import Server


def verify(output):
    result = {'ok': False}
    try:
        with tempfile.TemporaryDirectory(prefix='stockgo_exe_test_') as root:
            panel = Desktop(root, lambda path: Server(path, '127.0.0.1', 0))
            try:
                panel.root.withdraw()
                panel.catalog.create('Prueba de paquete', {'usuario': 'propietario', 'password': 'Universidad123!',
                                                         'nombres': 'Ana', 'apellidos': 'López'})
                panel.refresh()
                panel.user.insert(0, 'propietario')
                panel.password.insert(0, 'Universidad123!')
                panel.toggle()
                if panel.server is None:
                    raise RuntimeError('El servidor no inició.')
                with urllib.request.urlopen(f'http://127.0.0.1:{panel.server.port}/health', timeout=5) as response:
                    if json.load(response)['nombreNegocio'] != 'Prueba de paquete':
                        raise RuntimeError('Respuesta incorrecta.')
                result = {'ok': True, 'tkinter': True, 'sqlite': True, 'http': True,
                          'codigo_en_pantalla': panel.code.get('1.0', 'end').startswith('SG1-')}
            finally:
                panel.close()
    except Exception as exc:
        result['error'] = str(exc)
    Path(output).write_text(json.dumps(result), encoding='utf-8')
    if not result['ok']:
        raise SystemExit(1)
