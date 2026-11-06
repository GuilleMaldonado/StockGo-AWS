# Orden de despliegue de StockGo Cloud

## Identificación

- **Nombre del proyecto:** StockGo Cloud.
- **Repositorio actual:** `jhonnatanGranados/StockGo-AWS`.
- **URL Git:** `https://github.com/jhonnatanGranados/StockGo-AWS.git`.
- **Rama de nube:** `codex/aws-postgresql`.
- **Tecnologías:** Android Kotlin, frontend web HTML/CSS/JavaScript, API Python FastAPI, PostgreSQL y WebSocket.

## Orden correcto

1. **Crear PostgreSQL administrada y privada.** No abras el puerto 5432 a Internet. Guarda su URL en el administrador de secretos del proveedor.
2. **Publicar `backend/`.** Construye `backend/Dockerfile` o instala `backend/requirements.txt` en la VM. Define las variables de `backend/.env.example` directamente en el proveedor.
3. **Comprobar la API.** Abre `https://API-DOMINIO/health` y después `https://API-DOMINIO/ready`. Ambas deben responder antes de continuar.
4. **Configurar CORS.** Establece `ALLOWED_ORIGINS` con la URL final del sitio web, por ejemplo `https://app.midominio.com`.
5. **Compilar y publicar el frontend.** Define `STOCKGO_API_URL=https://API-DOMINIO`, ejecuta `python frontend_web/build.py` y publica `frontend_web/dist/` en hosting estático HTTPS.
6. **Crear el primer negocio.** Desde una herramienta interna autorizada, usa `PROVISIONING_KEY` contra la API. Conserva el código SG1 resultante y entrégalo al administrador del negocio.
7. **Crear vendedores y probar.** El administrador crea vendedores; Android y web ingresan con el mismo código SG1 y sus cuentas.
8. **Distribuir los clientes.** Entrega el APK Android y el ejecutable Windows. Ambos necesitan Internet y el código SG1; ninguno debe traer secretos.

## Variables de producción

```text
APP_ENV=production
DATABASE_URL=postgresql+psycopg://...        # secreto, solo backend
API_PUBLIC_URL=https://api.midominio.com
ALLOWED_ORIGINS=https://app.midominio.com
PROVISIONING_KEY=...                         # secreto, solo backend
DB_SSLMODE=verify-full
DB_POOL_SIZE=3
DB_MAX_OVERFLOW=2
PORT=8081
WEB_CONCURRENCY=1
FORWARDED_ALLOW_IPS=*
```

El frontend recibe únicamente:

```text
STOCKGO_API_URL=https://api.midominio.com
```

## PM2 en Amazon EC2 o Google Compute Engine

PM2 sirve para mantener vivo el proceso Python si se usa una VM. No sustituye HTTPS, el firewall, PostgreSQL ni los secretos del proveedor.

```bash
git clone --branch codex/aws-postgresql https://github.com/jhonnatanGranados/StockGo-AWS.git
cd StockGo-AWS/backend
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
npm install
# Define variables de producción en el proveedor o en un .env protegido.
export STOCKGO_PYTHON="$PWD/.venv/bin/python"
npm run start:pm2
npx pm2 save
```

Configura un proxy HTTPS como Nginx, Application Load Balancer o Google Load Balancer delante del puerto interno 8081. Debe permitir WebSockets en `/ws`.

## Comandos de mantenimiento

```bash
npm run logs:pm2
npm run restart:pm2
npx pm2 status
```

Antes de cambiar versiones, realiza respaldo de PostgreSQL, prueba las migraciones y luego despliega backend antes de frontend.
