# Contrato de sesión, WebSocket y entorno

`POST /connect` verifica el identificador de negocio. `POST /auth/login` y `/auth/guest` devuelven token y rol; el token dura 8 horas y se almacena hasheado en PostgreSQL. `X-StockGo-Code` identifica el negocio en HTTPS; `Authorization: Bearer` autentica la sesión. Los roles y el negocio se vuelven a validar al ejecutar operaciones.

Después se abre `wss://SERVIDOR/ws` y se envía:

```json
{"type":"auth","codigo":"IDENTIFICADOR_NEGOCIO","token":"TOKEN_DE_SESION"}
```

El servidor responde `{"type":"ready","resync":true}`. Una solicitud del catálogo:

```json
{"type":"request","id":"consulta-1","method":"GET","path":"products?limit=50&cursor=0","body":{},"etag":""}
```

La respuesta contiene `type=response`, el mismo `id`, `status`, `data` y `etag`. Una respuesta 304 reutiliza la copia de esa misma sesión; no se comparte caché de costos entre roles. `POST products`, `PUT products/ID`, `POST sales`, `POST sales/ID/cancel`, perfiles, usuarios y contraseñas pasan por las mismas reglas que HTTP.

Las invalidaciones llevan `type=changed`, `domain` (`products`, `sales`, `users`) y versión. No incluyen filas ni datos de otro negocio. `resync` pide volver a validar al recuperar una conexión. `session_invalidated` cierra sesiones revocadas. Las colas tienen límite y las reconexiones usan espera progresiva, sin sondeo de inventario.

Venta nueva:

```json
{"solicitud":"identificador-unico-de-la-cuenta","cliente":{"nombre":"Nombre del cliente","descripcion":"Descripción libre"},"lineas":[{"productoId":1,"cantidad":2,"precioEsperadoCentavos":5000}]}
```

Anulación: `POST sales/ID/cancel` con `{"motivo":"Cliente cancela la cuenta"}`. Es exclusiva de Administrador. No hay una ruta de borrado físico de ventas.

## Límites

- Solicitudes grandes hasta 8 MB para productos; el procesamiento valida imágenes hasta 5 MB y genera miniaturas para las listas.
- Hasta 200 líneas diferentes por venta. Stock entero y total hasta el límite seguro de enteros del cliente web.
- Intentos de acceso limitados por IP/ruta en PostgreSQL, compatibles con varios procesos. Aprovisionamiento requiere clave privada y tiene un límite inferior.
- Pool predeterminado: 3 conexiones más 2 adicionales por proceso. Cada proceso con clientes en vivo utiliza además un listener PostgreSQL. Una cuenta gratuita no necesita muchos procesos ni Redis adicional.
- No usar un pooler en modo transaccional para el listener: `LISTEN` necesita una conexión directa. La configuración entregada usa la conexión PostgreSQL directa.
- Los WebSockets no son una cola persistente y no eliminan el costo de leer los datos que realmente cambiaron. La API tiene HTTPS como alternativa cuando el canal no está disponible; una escritura con respuesta perdida no se reenvía automáticamente por otra vía.

`/health` es comprobación ligera del proceso, sin consultas al catálogo. `/ready` prueba PostgreSQL. El proveedor debe permitir WebSockets y un tiempo de inactividad compatible con los pings del protocolo.
