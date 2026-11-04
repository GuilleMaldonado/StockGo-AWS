# StockGo Cloud · Kotlin y Python

StockGo usa una API central Python, PostgreSQL y WebSockets. Android es Kotlin nativo. La interfaz de PC y navegador la sirve Python mediante HTML/CSS/JavaScript. No hay motor Flutter, archivos Dart ni dependencias Flutter en esta rama.

[Descargar APK de prueba 3.0.0](https://github.com/jhonnatanGranados/StockGo-AWS/releases/tag/v3.0.0-demo).

**Repositorio nuevo:** StockGo-AWS. **Rama de trabajo:** `codex/aws-postgresql`. La aplicación local anterior sigue en el repositorio StockGo. Esta variante puede probarse en Render gratis antes de migrar a Amazon.

## Qué incluye

- Negocios independientes, nombres únicos, Administrador, Vendedor e Invitado.
- Inventario con fotografía, fichas diferentes para lubricantes/repuestos/filtros/aditivos/accesorios y selección de especificaciones.
- Cuenta con varios productos; cliente con **solo nombre y descripción**, guardado dentro de la venta.
- Anulación por Administrador con motivo y confirmación: devuelve stock exactamente una vez, conserva historial y separa lotes históricos si el código original cambió de lote.
- Ventas del vendedor identificado por nombres, apellidos y código interno; métricas excluyen anulaciones.
- Contraseñas con hash y salt, temporales, revocación de sesiones y auditoría.
- Solicitudes de sesión por WebSocket y avisos de cambios, caché de 45 segundos e invalidación al recibir eventos. HTTPS sirve para el acceso y como alternativa al canal no disponible. No hay un temporizador consultando inventario cada cinco segundos.
- Catálogo paginado de 50 productos, miniaturas y conexiones PostgreSQL acotadas. Un listener por proceso, cerrado cuando no hay clientes activos. Los mensajes no transportan credenciales de PostgreSQL.

## Probar gratis y configurar `.env`

Consulta [despliegue gratuito y variables de entorno](docs/despliegue-gratuito.md). `render.yaml` define un servicio y PostgreSQL en plan **free**, sin activar planes de pago. Es para presentación: la base gratuita de Render caduca a los 30 días; su servicio puede tardar aproximadamente un minuto en arrancar tras inactividad.

El backend y el frontend web se despliegan juntos; el APK se instala y se conecta con el SG1 generado por el servidor. Ningún cliente se conecta directamente a PostgreSQL. No se ha desplegado en una cuenta externa ni creado recursos AWS.

`PUBLIC_API_URL` es la URL pública HTTPS. `DATABASE_URL` es privada y se configura solo en el backend. `.env.example` es la plantilla pública; `.env` y `.env.render` están excluidos de Git. No subas secretos a este repositorio público.

## Desarrollo

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r api/requirements-test.txt
# Configura PostgreSQL y copia .env.example como .env con valores locales.
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\iniciar_local.ps1
```

Abre `http://127.0.0.1:8081`, pulsa Crear un negocio y usa la clave de aprovisionamiento definida en tu `.env`. Elige usuario/contraseña del administrador. El código queda dentro de la aplicación y se copia desde Invitar al negocio.

Con Docker instalado puedes usar `docker compose up --build`; configura `POSTGRES_PASSWORD` y `PROVISIONING_KEY` en `.env`. El puerto PostgreSQL queda interno. El enlace de Compose está restringido a esta PC; para probar un teléfono físico ajusta explícitamente la exposición a tu red de prueba y el URL público.

## Importar datos anteriores

Las migraciones Alembic crean el esquema PostgreSQL al iniciar. [Guía de datos](docs/migracion-datos.md) explica la importación SQLite v10, su simulación y la conservación de hashes, inventario, lotes y ventas. SQLite no es la base del servidor; solo se lee como origen para trasladar datos anteriores.

```powershell
$env:PYTHONPATH = "$PWD/api"
# Carga primero DATABASE_URL y las demás variables en el entorno, o usa python-dotenv.
.\.venv\Scripts\python.exe -m stockgo_cloud.cli import-sqlite RUTA_NEGOCIO.db --dry-run
```

## Android y pruebas

Abre `android_kotlin/` en Android Studio. Para generar el APK con la firma StockGo de esta PC:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\compilar_apk.ps1 -Verificar
```

Salida: `dist/StockGo-Cloud-Android.apk`. Identidad `com.stockgo.cloudapp`, Android 7/API 24 o posterior. Puede coexistir con los APK anteriores. Se conecta al URL de su código SG1; no contiene secretos de base de datos.

Las pruebas requieren PostgreSQL real. `STOCKGO_TEST_DATABASE_URL` debe apuntar a una base exclusiva de pruebas; cada caso crea y elimina solo su propio esquema temporal.

Verificación realizada: 10 pruebas Python/PostgreSQL y 4 Kotlin superadas; migración Alembic aplicada en una base nueva y comprobada contra los modelos. En navegador se probó alta de producto, venta con cliente y anulación con retorno de existencias. El APK release está firmado y alineado. No se ha desplegado en una cuenta Render ni construido el contenedor con Docker en esta PC; la prueba del APK en un teléfono físico queda pendiente.

```powershell
$env:PYTHONPATH = "$PWD/api"
$env:STOCKGO_TEST_DATABASE_URL = 'postgresql+psycopg://USUARIO:CLAVE@127.0.0.1:5432/stockgo_test'
.\.venv\Scripts\python.exe -m pytest api/tests -q
```

El lanzador de escritorio es `desktop/iniciar.py`; abre la interfaz web del servidor. No almacena otro inventario en la PC. La versión web funciona en navegadores móviles, incluido iOS; no se ha creado una app nativa iOS.

## Estructura

| Carpeta | Uso |
|---|---|
| `api/stockgo_cloud` | Modelos PostgreSQL, reglas, API y WebSocket |
| `api/stockgo_cloud/web` | Interfaz web, sin herramientas de compilación Node obligatorias |
| `api/migrations` | Versiones Alembic de la base |
| `api/tests` | Pruebas HTTP/WebSocket/PostgreSQL e importación |
| `android_kotlin` | APK Android Kotlin |
| `desktop` | Lanzador Python |
| `scripts` | Desarrollo, pruebas y compilación |
| `docs` | Variables, despliegue, datos y protocolo |

Para Amazon se conserva la misma imagen Docker. Utiliza RDS PostgreSQL privado y una entrada HTTPS/WebSocket; configura su certificado CA mediante `DB_SSLROOTCERT` y `DB_SSLMODE=verify-full`. No se incluyen acciones que contraten servicios AWS.
