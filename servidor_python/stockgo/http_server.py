"""Servidor de demostración LAN/VPN. No publicar directamente en Internet."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import ipaddress
import json
import socket
import threading
from urllib.parse import urlsplit

from .database import Error
from .service import Service


def local_origin(origin):
    try:
        uri = urlsplit(origin)
        if uri.scheme not in ('http', 'https') or uri.username or uri.password or uri.path not in ('', '/') or uri.query or uri.fragment:
            return False
        if uri.hostname == 'localhost':
            return True
        ip = ipaddress.ip_address(uri.hostname)
        return ip.is_loopback or (ip.version == 4 and any(ip in ipaddress.ip_network(n) for n in ('10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16')))
    except ValueError:
        return False


def addresses(port):
    found = {'127.0.0.1'}
    try:
        found.update(info[4][0] for info in socket.getaddrinfo(socket.gethostname(), None, socket.AF_INET))
    except OSError:
        pass
    # La selección explícita evita confundir una tarjeta virtual con Wi-Fi.
    return [f'http://{ip}:{port}' for ip in sorted(found, key=lambda s: (s == '127.0.0.1', s))]


class Server:
    def __init__(self, path, host='0.0.0.0', port=8081):
        self.service = Service(path, lambda: addresses(self.port))
        service = self.service

        class Handler(BaseHTTPRequestHandler):
            protocol_version = 'HTTP/1.0'

            def setup(self):
                super().setup()
                self.connection.settimeout(15)

            def log_message(self, *_):
                # No escribir códigos, credenciales o contenido en la terminal.
                pass

            def handle_api(self):
                origin = self.headers.get('Origin')
                status, data = 200, None
                try:
                    if origin and not local_origin(origin):
                        raise Error('Origen no autorizado.', 403)
                    if self.command == 'OPTIONS':
                        status = 204
                    else:
                        if self.headers.get('Transfer-Encoding'):
                            raise Error('Transferencia no admitida.', 400)
                        raw_length = self.headers.get('Content-Length', '0')
                        if not raw_length.isdecimal():
                            raise Error('Longitud inválida.')
                        size = int(raw_length)
                        limit = 8 * 1024 * 1024 if self.path.startswith('/products') else 64 * 1024
                        if size > limit:
                            raise Error('La solicitud es demasiado grande.', 413)
                        payload = self.rfile.read(size)
                        if len(payload) != size:
                            raise Error('Solicitud incompleta.')
                        body = json.loads(payload) if payload else {}
                        if not isinstance(body, dict):
                            raise Error('Se esperaba un objeto JSON.')
                        data = service.request(self.command, self.path, body, self.headers, self.client_address[0])
                except Error as exc:
                    status, data = exc.status, {'error': str(exc)}
                except (ValueError, UnicodeError, RecursionError):
                    status, data = 400, {'error': 'Datos JSON inválidos.'}
                except Exception:
                    status, data = 500, {'error': 'No se pudo completar la operación en el servidor.'}
                encoded = json.dumps(data, ensure_ascii=False, allow_nan=False).encode('utf-8') if data is not None else b''
                try:
                    self.send_response(status)
                    self.send_header('Content-Type', 'application/json; charset=utf-8')
                    self.send_header('Cache-Control', 'no-store')
                    self.send_header('X-Content-Type-Options', 'nosniff')
                    self.send_header('Content-Length', str(len(encoded)))
                    if origin and local_origin(origin):
                        self.send_header('Access-Control-Allow-Origin', origin)
                        self.send_header('Vary', 'Origin')
                        self.send_header('Access-Control-Allow-Methods', 'GET,POST,PUT,OPTIONS')
                        self.send_header('Access-Control-Allow-Headers', 'Content-Type,Authorization,X-StockGo-Code')
                        self.send_header('Access-Control-Allow-Private-Network', 'true')
                    self.end_headers()
                    self.wfile.write(encoded)
                except (OSError, ConnectionError):
                    pass

            do_GET = handle_api
            do_POST = handle_api
            do_PUT = handle_api
            do_OPTIONS = handle_api

        class LocalHTTPServer(ThreadingHTTPServer):
            daemon_threads = True
            allow_reuse_address = True
            request_queue_size = 16
            # Acota hilos incluso si hay clientes que no completan las cabeceras.
            slots = threading.BoundedSemaphore(32)

            def process_request(self, request, client_address):
                if not self.slots.acquire(blocking=False):
                    request.close()
                    return
                try:
                    super().process_request(request, client_address)
                except Exception:
                    self.slots.release()
                    raise

            def process_request_thread(self, request, client_address):
                try:
                    super().process_request_thread(request, client_address)
                finally:
                    self.slots.release()

        self.http = LocalHTTPServer((host, port), Handler)
        self.port = self.http.server_address[1]
        self.thread = None

    def start(self):
        self.thread = threading.Thread(target=self.http.serve_forever, daemon=True, name='StockGo-Python')
        self.thread.start()

    def stop(self):
        if self.thread:
            self.http.shutdown()
            self.thread.join(timeout=20)
        self.http.server_close()
        with self.service.lock:
            self.service.sessions.clear()
