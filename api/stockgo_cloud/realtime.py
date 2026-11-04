"""Un LISTEN PostgreSQL por proceso. Nunca se sondea la tabla de inventario."""
import asyncio
import json
import logging
import random
import threading

import psycopg

logger = logging.getLogger('stockgo.realtime')


class EventBus:
    def __init__(self, engine):
        self.engine = engine
        self.clients = {}
        self.stop_event = threading.Event()
        self.ready = threading.Event()
        self.thread = None
        self.loop = None
        self.active = threading.Event()

    def start(self, loop):
        self.loop = loop
        self.thread = threading.Thread(target=self._listen, daemon=True, name='stockgo-pg-listen')
        self.thread.start()

    def subscribe(self, identity):
        if len(self.clients) >= 1000:
            raise RuntimeError('Límite de conexiones alcanzado.')
        queue = asyncio.Queue(maxsize=32)
        self.clients[id(queue)] = (identity, queue)
        self.active.set()
        return queue

    def unsubscribe(self, queue):
        self.clients.pop(id(queue), None)
        if not self.clients: self.active.clear()

    def _resync_all(self):
        for business in {v[0]['business'] for v in self.clients.values()}:
            self._deliver({'business': business, 'domain': 'resync'})

    def _deliver(self, event):
        for identity, queue in list(self.clients.values()):
            if event['business'] != identity['business']:
                continue
            if event['domain'] == 'credentials':
                if event.get('user_id') != identity['user_id'] or event.get('except_hash') == identity['session_hash']:
                    continue
                value = {'type': 'session_invalidated'}
            else:
                value = {'type': 'changed', 'domain': event['domain'], 'version': event.get('version')}
            if queue.full():
                # Los avisos son invalidaciones, no un registro de ventas: basta resincronizar.
                while not queue.empty(): queue.get_nowait()
                value = {'type': 'resync'}
            queue.put_nowait(value)

    def _listen(self):
        delay = 1
        while not self.stop_event.is_set():
            if not self.active.wait(timeout=1): continue
            try:
                args, kwargs = self.engine.dialect.create_connect_args(self.engine.url)
                kwargs.update(self.engine._stockgo_connect_args)
                with psycopg.connect(*args, **kwargs, autocommit=True) as conn:
                    conn.execute('LISTEN stockgo_changes')
                    self.ready.set()
                    delay = 1
                    # Al recuperar el listener puede haberse perdido una notificación.
                    self.loop.call_soon_threadsafe(self._resync_all)
                    while not self.stop_event.is_set() and self.active.is_set():
                        for notification in conn.notifies(timeout=1, stop_after=1):
                            self.loop.call_soon_threadsafe(self._deliver, json.loads(notification.payload))
                    self.ready.clear()
            except Exception:
                self.ready.clear()
                logger.warning('Listener PostgreSQL desconectado; reconectando sin consultar inventario.')
                self.stop_event.wait(delay + random.random())
                delay = min(delay * 2, 30)

    def stop(self):
        self.stop_event.set()
        if self.thread: self.thread.join(timeout=5)
