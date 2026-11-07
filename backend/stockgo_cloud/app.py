import asyncio
from contextlib import asynccontextmanager
import json
import logging
import re
import time

from fastapi import FastAPI, Request, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, Response
from starlette.concurrency import run_in_threadpool

from .db import create_database
from .domain import Error
from .realtime import EventBus
from .service import Service
from .settings import Settings

logger = logging.getLogger('stockgo.api')


def create_app(settings=None, engine=None, factory=None):
    settings = settings or Settings.from_env()
    if engine is None: engine, factory = create_database(settings)
    service, bus = Service(factory, settings), EventBus(engine)

    @asynccontextmanager
    async def lifespan(app):
        bus.start(asyncio.get_running_loop())
        try: yield
        finally:
            await asyncio.to_thread(bus.stop)
            engine.dispose()

    app = FastAPI(title='StockGo AWS', version='3.0.0', lifespan=lifespan,
                  docs_url='/docs' if settings.environment != 'production' else None, redoc_url=None)
    app.state.service, app.state.bus, app.state.factory = service, bus, factory
    # Esta API no sirve la interfaz. El navegador y Android son clientes
    # independientes y solo se comunican con la URL pública de este servicio.
    allowed_origins = set(settings.origins)

    @app.get('/')
    async def api_info():
        return JSONResponse({
            'service': 'StockGo API', 'version': '3.1.0',
            'health': '/health', 'ready': '/ready', 'websocket': '/ws',
        }, headers={'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff'})

    app.add_middleware(CORSMiddleware, allow_origins=list(allowed_origins), allow_methods=['GET', 'POST', 'PUT'],
                       allow_headers=['Content-Type', 'Authorization', 'X-StockGo-Code', 'If-None-Match', 'X-StockGo-Provisioning-Key'],
                       expose_headers=['ETag'])

    @app.websocket('/ws')
    async def websocket(ws: WebSocket):
        if ws.headers.get('origin') and ws.headers['origin'] not in allowed_origins:
            await ws.close(code=1008); return
        if settings.environment == 'production' and ws.scope['scheme'] != 'wss':
            await ws.close(code=1008); return
        await ws.accept()
        queue, tasks = None, []
        write_lock = asyncio.Lock()

        async def send(value):
            async with write_lock:
                await ws.send_json(value)

        try:
            raw = await asyncio.wait_for(ws.receive_text(), 10)
            if len(raw.encode()) > 4096: raise Error('Autenticación inválida.', 401)
            auth = json.loads(raw)
            if not isinstance(auth, dict) or auth.get('type') != 'auth' or not isinstance(auth.get('token'), str) or not isinstance(auth.get('codigo'), str):
                raise Error('Autenticación requerida.', 401)
            ip = ws.client.host if ws.client else 'unknown'
            await run_in_threadpool(service.limit, ip, 'ws/auth')
            identity = await run_in_threadpool(service.websocket_identity, auth['codigo'], auth['token'])
            queue = bus.subscribe(identity)
            if not await asyncio.to_thread(bus.ready.wait, 10):
                raise RuntimeError('El canal de cambios no está disponible.')
            await send({'type': 'ready', 'resync': True})

            async def events():
                while True:
                    remaining = identity['expires_at'] - time.time()
                    if remaining <= 0: break
                    try: value = await asyncio.wait_for(queue.get(), remaining)
                    except asyncio.TimeoutError: break
                    await send(value)
                    if value['type'] == 'session_invalidated': break
                await ws.close(code=4001)

            async def requests():
                while True:
                    raw = await ws.receive_text()
                    if len(raw.encode()) > 8 * 1024 * 1024: raise Error('Solicitud demasiado grande.', 413)
                    frame = json.loads(raw)
                    if not isinstance(frame, dict) or frame.get('type') != 'request' or not isinstance(frame.get('id'), str) or not re.fullmatch(r'[\w-]{1,80}', frame['id']):
                        raise Error('Formato de solicitud inválido.')
                    request_id = frame['id']
                    method, path, body = frame.get('method'), frame.get('path'), frame.get('body', {})
                    if method not in ('GET', 'POST', 'PUT') or not isinstance(path, str) or len(path) > 2048 or not isinstance(body, dict):
                        await send({'type': 'response', 'id': request_id, 'status': 400, 'data': {'error': 'Solicitud inválida.'}}); continue
                    # Aprovisionamiento y login se hacen en HTTPS antes de abrir el canal.
                    if path.split('?')[0].strip('/') in ('businesses', 'auth/login', 'auth/admin-login', 'auth/user-login', 'auth/guest', 'auth/register', 'connect'):
                        await send({'type': 'response', 'id': request_id, 'status': 403, 'data': {'error': 'Ruta no disponible en esta sesión.'}}); continue
                    try:
                        status, data, etag = await run_in_threadpool(service.handle, method, path, body, auth['codigo'], auth['token'], ip, '', frame.get('etag', ''))
                    except Error as exc:
                        status, data, etag = exc.status, {'error': str(exc)}, ''
                    except Exception:
                        logger.exception('Fallo de operación WebSocket sin contenido de la solicitud.')
                        status, data, etag = 500, {'error': 'No se pudo completar la operación.'}, ''
                    await send({'type': 'response', 'id': request_id, 'status': status, 'data': data, 'etag': etag})

            tasks = [asyncio.create_task(events()), asyncio.create_task(requests())]
            done, pending = await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED)
            for task in pending: task.cancel()
            for task in done: task.result()
        except (Error, ValueError, KeyError, TypeError, asyncio.TimeoutError, RuntimeError):
            try: await ws.close(code=4001)
            except RuntimeError: pass
        except WebSocketDisconnect:
            pass
        finally:
            for task in tasks: task.cancel()
            if tasks: await asyncio.gather(*tasks, return_exceptions=True)
            if queue is not None: bus.unsubscribe(queue)

    @app.api_route('/{path:path}', methods=['GET', 'POST', 'PUT'])
    async def api(path: str, request: Request):
        try:
            if settings.environment == 'production' and request.url.scheme != 'https' and path != 'health':
                raise Error('Utiliza HTTPS para conectarte al servicio.', 400)
            size, parts = 0, []
            limit = 8 * 1024 * 1024 if path.startswith('products') else 64 * 1024
            async for chunk in request.stream():
                size += len(chunk)
                if size > limit: raise Error('La solicitud es demasiado grande.', 413)
                parts.append(chunk)
            body = json.loads(b''.join(parts)) if size else {}
            if not isinstance(body, dict): raise Error('Se esperaba un objeto JSON.')
            header = request.headers.get('authorization', '')
            token = header[7:] if header.startswith('Bearer ') else ''
            target = path + ('?' + request.url.query if request.url.query else '')
            status, data, etag = await run_in_threadpool(service.handle, request.method, target, body,
                request.headers.get('x-stockgo-code', ''), token, request.client.host if request.client else 'unknown',
                request.headers.get('x-stockgo-provisioning-key', ''), request.headers.get('if-none-match', ''))
            headers = {'Cache-Control': 'private, max-age=0, must-revalidate' if etag else 'no-store',
                       'X-Content-Type-Options': 'nosniff', 'Vary': 'Authorization,X-StockGo-Code'}
            if etag: headers['ETag'] = etag
            return Response(status_code=304, headers=headers) if status == 304 else JSONResponse(data, status_code=status, headers=headers)
        except Error as exc:
            return JSONResponse({'error': str(exc)}, status_code=exc.status, headers={'Cache-Control': 'no-store'})
        except (ValueError, TypeError, RecursionError):
            return JSONResponse({'error': 'Datos inválidos.'}, status_code=400)
        except Exception:
            logger.exception('Fallo de operación HTTP sin contenido de la solicitud.')
            return JSONResponse({'error': 'No se pudo completar la operación.'}, status_code=500)

    return app
