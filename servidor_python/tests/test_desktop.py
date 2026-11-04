"""Prueba real del panel Tk: autorización, servidor, código y cierre."""
import json
import tempfile
import tkinter
import unittest
import urllib.request
from unittest.mock import patch

from stockgo.desktop import Desktop
from stockgo.http_server import Server


class DesktopTest(unittest.TestCase):
    def test_admin_starts_server_code_in_ui_and_close_stops_it(self):
        with tempfile.TemporaryDirectory() as root:
            try:
                panel = Desktop(root, lambda path: Server(path, '127.0.0.1', 0))
            except tkinter.TclError as exc:
                self.skipTest(f'El entorno no tiene interfaz gráfica: {exc}')
            try:
                panel.root.withdraw()
                panel.catalog.create('Prueba gráfica', {'usuario': 'propietario', 'password': 'Universidad123!', 'nombres': 'Ana', 'apellidos': 'López'})
                panel.refresh()
                panel.user.insert(0, 'propietario')
                panel.password.insert(0, 'incorrecta')
                with patch('stockgo.desktop.messagebox.showerror') as error:
                    panel.toggle()
                    error.assert_called_once()
                    self.assertIsNone(panel.server)
                panel.password.insert(0, 'Universidad123!')
                panel.toggle()
                self.assertIsNotNone(panel.server)
                self.assertTrue(panel.code.get('1.0', 'end').startswith('SG1-'))
                self.assertEqual('', panel.password.get())
                self.assertEqual('disabled', str(panel.business['state']))
                with urllib.request.urlopen(f'http://127.0.0.1:{panel.server.port}/health', timeout=5) as response:
                    self.assertEqual('Prueba gráfica', json.load(response)['nombreNegocio'])
                panel.toggle()
                self.assertIsNone(panel.server)
                self.assertEqual('', panel.code.get('1.0', 'end').strip())
            finally:
                panel.close()


if __name__ == '__main__':
    unittest.main()
