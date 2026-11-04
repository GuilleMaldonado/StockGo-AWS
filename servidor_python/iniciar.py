"""Ejecutar con Python 3.11+ con Tk. También sirve como entrada de PyInstaller."""
from stockgo.desktop import main
import sys

if __name__ == '__main__':
    if len(sys.argv) == 3 and sys.argv[1] == '--verificar-paquete':
        from stockgo.verify_package import verify
        verify(sys.argv[2])
    else:
        main()
