# Guía técnica de StockGo Cloud

## 1. Propósito

StockGo administra inventario, productos, ventas y vendedores para una aceitera y venta de repuestos. Soporta varios negocios independientes. Cada negocio tiene sus propios usuarios, productos, lotes, ventas, permisos e historial.

La versión actual usa una arquitectura web centralizada: un backend en la nube conserva la información y los clientes Android, navegador y PC se conectan a él. Ningún teléfono actúa como servidor.

## 2. Funcionamiento para un usuario

1. El responsable de la plataforma crea un negocio en la API con una clave de aprovisionamiento privada.
2. La API genera un código `SG1` con la URL HTTPS de la API y el identificador público del negocio.
3. El administrador inicia sesión con ese código y crea cuentas de vendedores desde **Vendedores y equipo**.
4. El administrador registra productos, fotos, lotes y su ficha técnica según categoría.
5. El vendedor ingresa con su cuenta, agrega varios productos a una cuenta de venta e indica solamente nombre y descripción del cliente.
6. La API valida el precio, existencia, lote, rol y sesión; guarda la venta y descuenta stock en una misma transacción.
7. Los demás clientes reciben un evento WebSocket y actualizan inventario, ventas y métricas sin consultar constantemente.
8. Un administrador puede anular una venta. Se conserva el comprobante, se registra el motivo y el stock se devuelve una sola vez.

## 3. Componentes y segmentación

| Componente | Ubicación | Qué contiene | Qué no contiene |
|---|---|---|---|
| Backend | `backend/` | FastAPI, WebSocket, reglas de roles, SQLAlchemy, Alembic, validaciones y conexión PostgreSQL | HTML de la aplicación, APK, claves en código |
| Frontend web | `frontend_web/` | HTML, CSS, JavaScript y `build.py` | Base de datos, secretos, servidor Python |
| Android | `android_kotlin/` | Aplicación Kotlin, cliente HTTP/WebSocket, validación de SG1, pantallas y permisos | `DATABASE_URL`, claves de PostgreSQL, servicio embebido |
| Lanzador de PC | `desktop/iniciar.py` | Ventana que abre la web HTTPS | Backend o base de datos local |
| Automatización | `scripts/` | Compilar web, pruebas, APK y desarrollo local | Configuración real de nube |
| Documentación | `docs/` | Arquitectura, despliegue y migración | Secretos de producción |

## 4. API y tiempo real

La API FastAPI se inicia desde `backend/stockgo_cloud/start.py`. El archivo `backend/stockgo_cloud/app.py` define HTTP, CORS y el endpoint WebSocket `/ws`.

Las rutas principales son:

| Ruta | Uso |
|---|---|
| `POST /connect` | Comprueba que el código pertenece a un negocio y prepara la conexión. |
| `POST /auth/login` | Inicia una sesión de administrador o vendedor. |
| `POST /auth/guest` | Acceso limitado de invitado. |
| `GET/POST/PUT /products...` | Consulta, alta, edición y desactivación lógica de productos. |
| `GET/POST /sales...` | Historial y registro de ventas con varios productos. |
| `POST /sales/{id}/cancel` | Anula la venta y retorna las existencias. |
| `GET/POST /users...` | Administración de integrantes, códigos internos y claves temporales. |
| `GET /security/audit` | Auditoría disponible para administrador. |
| `GET /health` y `GET /ready` | Verificación operativa del servicio. |
| `WS /ws` | Eventos de cambio y operaciones autenticadas en tiempo real. |

`backend/stockgo_cloud/service.py` concentra reglas del negocio. No se confía en la interfaz: el backend vuelve a verificar rol, negocio, token, precio de venta mayor o igual al costo, existencia, lote e idempotencia de cada venta.

## 5. Base de datos

La base definitiva es **PostgreSQL**, no SQLite. La estructura está en `backend/migrations/versions/0001_cloud.py` y los modelos SQLAlchemy están en `backend/stockgo_cloud/models.py`.

Tablas principales:

- `businesses`: negocios con nombre único e identificador SG1.
- `users` y `sessions`: cuentas, roles, hashes de contraseña, códigos internos y sesiones revocables.
- `products`: inventario, costos, precios, lote, imagen y ficha técnica JSON por categoría.
- `sales` y `sale_details`: comprobantes y líneas de productos vendidas.
- `audit_events`: trazabilidad de acciones de seguridad y ventas.

Las migraciones Alembic se ejecutan antes de servir la API. PostgreSQL se mantiene privada: solo el backend posee `DATABASE_URL`.

## 6. Variables de entorno y secretos

### Backend: `backend/.env.example`

- `DATABASE_URL`: conexión privada a PostgreSQL. Es secreta.
- `API_PUBLIC_URL`: URL HTTPS pública del backend; se escribe en los códigos SG1.
- `ALLOWED_ORIGINS`: URL exacta del sitio web permitido para CORS.
- `PROVISIONING_KEY`: clave privada para crear un negocio nuevo.
- `DB_SSLMODE`, `DB_SSLROOTCERT`, `DB_POOL_SIZE`, `DB_MAX_OVERFLOW`: seguridad y límite de conexiones.

### Frontend: `frontend_web/.env.example`

- `STOCKGO_API_URL`: URL pública HTTPS de la API. Se convierte en `frontend_web/dist/config.js`; es visible y por eso no debe contener secretos.

Nunca se suben `.env` reales, certificados, llaves de firma, bases de datos ni contraseñas a GitHub. `.gitignore` los excluye.

## 7. Despliegue

`render.yaml` describe tres recursos separados: API Docker, PostgreSQL y web estática. En AWS se mantiene la misma división: contenedor/API Python, RDS PostgreSQL privada y hosting/CDN para `frontend_web/dist`.

El frontend se compila con:

```powershell
$env:STOCKGO_API_URL = 'https://api.tu-dominio.example'
python .\frontend_web\build.py
```

La API se construye con `backend/Dockerfile`. Para desarrollo local se puede usar `compose.yaml`, pero no es el modo final de los usuarios.

## 8. Seguridad incluida

- HTTPS/WSS obligatorio en producción.
- CORS limitado a los dominios del frontend.
- Contraseñas con hash y salt; no se almacenan en texto plano.
- Tokens de sesión revocables y cierre de sesiones al cambiar credenciales.
- Roles Administrador, Vendedor e Invitado comprobados en la API.
- Límites de tamaño y frecuencia en solicitudes sensibles.
- Validación del SG1 y rechazo de direcciones inseguras en Android.
- PostgreSQL no se expone a clientes; el navegador nunca recibe sus credenciales.
- Auditoría, ventas idempotentes y anulación con retorno de stock una única vez.

## 9. Verificación y mantenimiento

- Pruebas Python: `backend/tests/` comprueba roles, ventas, anulación, WebSocket, imágenes e importación.
- Pruebas Kotlin: `android_kotlin/app/src/test/` comprueba comunicación real con un backend temporal y validación de direcciones.
- Comando completo: `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verificar.ps1`.
- APK: `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\compilar_apk.ps1 -Verificar`.

Antes de actualizar producción: realiza respaldo de PostgreSQL, aplica migraciones en una copia de prueba, verifica `/ready`, publica backend primero y después el frontend configurado con la URL pública correcta.
