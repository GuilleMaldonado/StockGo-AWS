# StockGo Cloud · Android Kotlin + Python

StockGo está separado para un despliegue centralizado en la nube:

```text
Android Kotlin ─┐
Escritorio Python ─┼─ HTTPS / WSS ─> API Python (backend/) ─> PostgreSQL privada
                    └─ Render
```

Los teléfonos y PC son clientes. **No alojan el servidor ni se conectan a PostgreSQL.** La única API que consumen es la URL HTTPS incluida en el código SG1 del negocio.

## Flujo de uso

1. Cualquier persona abre StockGo y pulsa **¿Nuevo por aquí? Crear cuenta**.
2. Completa el nombre único del negocio y los datos del administrador. StockGo Cloud crea el negocio inmediatamente y muestra su código **SG1**.
3. El administrador guarda el SG1 e inicia sesión. Dentro de la aplicación puede abrir **Invitar al negocio** para volver a ver y copiar el mismo código.
4. El vendedor abre **Crear cuenta**, selecciona **Soy vendedor**, pega el SG1, registra sus datos y luego inicia sesión con su propia cuenta.

El SG1 identifica el negocio en la nube; no es una contraseña y no concede permisos de administrador.

## Carpetas

| Carpeta | Responsabilidad |
|---|---|
| `backend/` | API FastAPI, WebSocket, reglas, migraciones y PostgreSQL. Se despliega en la nube. |
| `android_kotlin/` | Cliente Android nativo, sin credenciales de servidor. |
| `desktop/` | Aplicación nativa Python para Windows; nunca inicia un servidor local. |
| `scripts/` | Utilidades de desarrollo, pruebas y compilación. |

## Variables de entorno

- Copia [backend/.env.example](backend/.env.example) para el backend. `DATABASE_URL` y las claves de autenticación son secretos: van solamente en la nube.
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
