# Catálogo de archivos, variables e instaladores

Esta guía describe los archivos que debes modificar y los que debes conservar al desplegar StockGo. Los directorios de caché, `build/`, APK, EXE, `.venv/`, `.env` real y dependencias descargadas no forman parte del código fuente.

## Raíz del repositorio

| Archivo | Función |
|---|---|
| `README.md` | Inicio rápido y arquitectura resumida. |
| `render.yaml` | Blueprint de referencia: API, web estática y PostgreSQL separados. |
| `compose.yaml` | Prueba local con Docker: PostgreSQL, API y web. |
| `.env.example` | Variables de Docker local, sin secretos reales. |
| `.gitignore` | Evita subir secretos, APK, EXE, bases y resultados de compilación. |
| `StockGo-Cloud.code-workspace` | Configuración de apertura para VS Code. |

## Backend Python: `backend/`

| Archivo o carpeta | Función |
|---|---|
| `Dockerfile` | Crea el contenedor de la API para Amazon, Google Cloud o Render. |
| `.env.example` | Contrato de variables privadas del servidor. |
| `requirements.txt` | Dependencias de producción Python. |
| `requirements-test.txt` y `requirements-dev.lock.txt` | Dependencias de pruebas reproducibles. |
| `package.json` | Comandos npm para administrar el proceso Python con PM2. |
| `ecosystem.config.cjs` | Reinicio, registros y configuración de PM2; no ejecuta Node como backend. |
| `alembic.ini` | Configuración de migraciones PostgreSQL. |
| `migrations/env.py` | Ejecuta el entorno Alembic. |
| `migrations/versions/0001_cloud.py` | Estructura inicial de tablas de PostgreSQL. |
| `stockgo_cloud/start.py` | Lee entorno, aplica migraciones y arranca Uvicorn. |
| `stockgo_cloud/app.py` | Endpoints HTTP, CORS, WebSocket y límites de solicitud. |
| `stockgo_cloud/service.py` | Reglas de ventas, inventario, roles, sesiones y auditoría. |
| `stockgo_cloud/models.py` | Modelos SQLAlchemy de negocios, usuarios, productos y ventas. |
| `stockgo_cloud/db.py` | Motor, pool y conexión TLS de PostgreSQL. |
| `stockgo_cloud/realtime.py` | `LISTEN/NOTIFY` y difusión de cambios WebSocket. |
| `stockgo_cloud/domain.py` | Validaciones y errores de dominio. |
| `stockgo_cloud/import_sqlite.py` | Migración desde datos SQLite antiguos. |
| `stockgo_cloud/cli.py` | Utilidades de línea de comandos para importación. |
| `tests/` | Pruebas de API, WebSocket, ventas y migración. |

## Frontend web: `frontend_web/`

| Archivo o carpeta | Función |
|---|---|
| `src/index.html` | Estructura HTML de la SPA. |
| `src/style.css` | Paleta, responsive, tarjetas, modales y animaciones. |
| `src/app.js` | Login, catálogo, ventas, permisos, WebSocket y llamadas a la API. |
| `build.py` | Copia `src/` a `dist/` y escribe la URL de API pública en `config.js`. |
| `.env.example` | Solo `STOCKGO_API_URL`; es pública. |
| `dist/` | Resultado generado para alojar en hosting estático; no se versiona. |

## Android y escritorio

| Ubicación | Función |
|---|---|
| `android_kotlin/app/src/main/.../MainActivity.kt` | Pantallas, permisos, productos y ventas Android. |
| `android_kotlin/app/src/main/.../Api.kt` | Cliente HTTPS, token, SG1, caché y seguridad de URL. |
| `android_kotlin/app/src/main/.../Realtime.kt` | Cliente WebSocket Android. |
| `android_kotlin/app/src/main/.../ProductFields.kt` | Fichas técnicas por categoría. |
| `android_kotlin/app/build.gradle.kts` | SDK, nombre de paquete y firma APK. |
| `desktop/iniciar.py` | Lanzador Windows que abre el sitio web HTTPS; no aloja datos. |

## Scripts

| Archivo | Función |
|---|---|
| `scripts/iniciar_prueba_web.ps1` | Inicia API local en 8081, web en 8082 y abre navegador. |
| `scripts/detener_prueba_web.ps1` | Detiene solo los procesos iniciados por la prueba. |
| `scripts/compilar_web.ps1` | Genera `frontend_web/dist/` para una URL de API. |
| `scripts/iniciar_local.ps1` | Inicia únicamente el backend para desarrollo. |
| `scripts/verificar.ps1` | Ejecuta pruebas Python y Android. |
| `scripts/compilar_apk.ps1` | Genera el APK firmado. |
| `scripts/crear_instalador_windows.ps1` | Genera `dist/StockGo-Web.exe`. |

## Variables de entorno

| Variable | Dónde | Secreta | Uso |
|---|---|---:|---|
| `DATABASE_URL` | Backend | Sí | Cadena de conexión privada PostgreSQL. |
| `API_PUBLIC_URL` | Backend | No | URL HTTPS de la API que se inserta en SG1. |
| `ALLOWED_ORIGINS` | Backend | No | Dominios web permitidos por CORS. |
| `PROVISIONING_KEY` | Backend | Sí | Autoriza crear negocios iniciales. |
| `DB_SSLMODE` | Backend | No | TLS de PostgreSQL (`require` o `verify-full`). |
| `DB_SSLROOTCERT` | Backend | Puede ser sensible | CA para validar PostgreSQL administrada. |
| `DB_POOL_SIZE` | Backend | No | Conexiones persistentes por proceso. |
| `DB_MAX_OVERFLOW` | Backend | No | Conexiones extra máximas por proceso. |
| `PORT` | Backend | No | Puerto interno de Uvicorn. |
| `WEB_CONCURRENCY` | Backend | No | Procesos API; usa 1 inicialmente con WebSocket. |
| `FORWARDED_ALLOW_IPS` | Backend | No | Proxy confiable delante de HTTPS. |
| `STOCKGO_API_URL` | Frontend | No | URL que el navegador consulta. |
| `STOCKGO_PYTHON` | PM2 | No | Ruta a Python/venv que PM2 debe ejecutar. |

## PM2 con npm

PM2 es opcional. Docker, systemd, ECS/App Runner o Cloud Run son alternativas válidas. Si usas PM2 en una VM Linux:

```bash
cd backend
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
cp .env.example .env
# Edita .env con secretos solo en el servidor.
npm install
export STOCKGO_PYTHON="$PWD/.venv/bin/python"
npm run start:pm2
npx pm2 save
```

PM2 reinicia `stockgo_cloud/start.py`; PostgreSQL permanece en un servicio gestionado y privado. Para ver registros: `npm run logs:pm2`.

## Archivos para descargar/probar

- Android: `dist/StockGo-Cloud-Android.apk`.
- Windows: `dist/StockGo-Web.exe`, generado con `scripts/crear_instalador_windows.ps1`.
- Documentación: este archivo, `docs/guia-tecnica-aplicacion.md` y `docs/despliegue-gratuito.md`.

Un APK firmado fuera de Google Play puede mostrar advertencias de Play Protect hasta que el desarrollador lo distribuya y gane reputación o se publique mediante Play Console. No se elimina esa advertencia cambiando código localmente.
