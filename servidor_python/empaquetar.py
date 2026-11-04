"""Empaquetado reproducible con herramientas aisladas dentro de build/."""
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / 'build' / 'tools' / 'python-packaging'))
import PyInstaller.__main__

PyInstaller.__main__.run([
    '--noconfirm', '--onefile', '--windowed', '--noupx',
    '--name', 'StockGo-Servidor-Python',
    '--paths', str(root / 'servidor_python'),
    '--distpath', str(root / 'dist'),
    '--workpath', str(root / 'build' / 'servidor_python'),
    '--specpath', str(root / 'build' / 'servidor_python'),
    '--icon', str(root / 'windows' / 'runner' / 'resources' / 'app_icon.ico'),
    str(root / 'servidor_python' / 'iniciar.py'),
])
