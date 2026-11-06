"""Genera el sitio estático con una URL pública de API no secreta."""
from pathlib import Path
import os
import shutil
from urllib.parse import urlsplit

root = Path(__file__).resolve().parent
source, target = root / 'src', root / 'dist'
api_url = os.getenv('STOCKGO_API_URL', 'http://127.0.0.1:8081').rstrip('/')
parsed = urlsplit(api_url)
if parsed.scheme not in ('https', 'http') or not parsed.netloc or parsed.path not in ('', '/'):
    raise SystemExit('STOCKGO_API_URL debe ser una URL base, por ejemplo https://api.stockgo.example')
if parsed.scheme == 'http' and parsed.hostname not in ('localhost', '127.0.0.1'):
    raise SystemExit('En publicación usa HTTPS para STOCKGO_API_URL.')
if target.exists():
    shutil.rmtree(target)
shutil.copytree(source, target)
(target / 'config.js').write_text(
    "// Esta URL es pública; nunca agregues contraseñas ni claves aquí.\n"
    f"window.STOCKGO_CONFIG = Object.freeze({{apiBaseUrl: {api_url!r}}});\n", encoding='utf-8')
print(f'Sitio generado en {target}; API: {api_url}')
