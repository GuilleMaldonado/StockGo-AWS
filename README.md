# StockGo Cloud · Android Kotlin + Python

StockGo quedó separado para despliegue web centralizado:

```text
Android Kotlin ─┐
Navegador web ─┼─ HTTPS / WSS ─> API Python (backend/) ─> PostgreSQL privada
Escritorio web ─┘
```

Los teléfonos, navegadores y PC son clientes. **No alojan el servidor ni se conectan a PostgreSQL.** La única API que consumen es la URL HTTPS incluida en el código SG1 del negocio.

## Carpetas

| Carpeta | Responsabilidad |
|---|---|
| `backend/` | API FastAPI, WebSocket, reglas, migraciones y PostgreSQL. Se despliega en la nube. |
| `frontend_web/` | Sitio estático HTML/CSS/JS. Solo contiene una URL pública de API. |
| `android_kotlin/` | Cliente Android nativo, sin credenciales de servidor. |
| `desktop/` | Lanzador que abre el sitio web HTTPS, no un servidor. |
| `scripts/` | Utilidades de desarrollo, pruebas y compilación. |

## Variables de entorno

- Copia [backend/.env.example](backend/.env.example) para el backend. `DATABASE_URL` y `PROVISIONING_KEY` son secretos: van solamente en la nube.
- Copia [frontend_web/.env.example](frontend_web/.env.example) para compilar el sitio. `STOCKGO_API_URL` es pública y puede terminar dentro de `config.js`; no coloques secretos allí.
- [`.env.example`](.env.example) es únicamente para Docker Compose local.

Lee [arquitectura central](docs/arquitectura-central.md), [catálogo de archivos](docs/catalogo-archivos.md), [orden de despliegue](docs/orden-despliegue.md) y [despliegue gratuito](docs/despliegue-gratuito.md) antes de crear recursos externos.

## Desarrollo local (solo desarrolladores)

El servidor local existe únicamente para pruebas del equipo de desarrollo, no para usuarios finales:

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r backend/requirements-test.txt
$env:PYTHONPATH = "$PWD/backend"
# Configura DATABASE_URL local antes de iniciar:
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\iniciar_local.ps1

# En otra terminal: genera y sirve el cliente web de prueba
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\compilar_web.ps1 -ApiUrl http://127.0.0.1:8081
python -m http.server 8082 --directory frontend_web/dist
```

Pruebas y APK:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verificar.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\compilar_apk.ps1 -Verificar
```

El APK generado queda en `dist/StockGo-Cloud-Android.apk` y soporta Android 7/API 24 o superior. La rama no contiene Flutter.
