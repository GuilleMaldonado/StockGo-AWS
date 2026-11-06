# Despliegue web separado y variables de entorno

Este repositorio tiene un Blueprint `render.yaml` con tres recursos separados: API Python, PostgreSQL y sitio estático. No crea recursos por sí solo; debes revisar y confirmar el despliegue en tu propia cuenta.

## Render para una demostración

1. En Render selecciona **New → Blueprint**, conecta `jhonnatanGranados/StockGo-AWS` y elige la rama `codex/aws-postgresql`.
2. El Blueprint crea `stockgo-api-demo`, `stockgo-web-demo` y `stockgo-demo-db`. Revisa el plan mostrado antes de confirmar.
3. Render conecta `DATABASE_URL` solo con PostgreSQL y genera `PROVISIONING_KEY` en el servicio API. El navegador y APK nunca reciben esos valores.
4. El sitio estático recibe solo `STOCKGO_API_URL`, tomado de la URL externa del servicio API durante la compilación. La API recibe `ALLOWED_ORIGINS` con la URL externa del sitio web para CORS.
5. Cuando ambos despliegues terminen, abre la URL de `stockgo-web-demo`. La raíz de `stockgo-api-demo` responde información JSON de la API, no una interfaz de administración.
6. Aprovisiona el primer negocio desde una herramienta interna que use el secreto `PROVISIONING_KEY`; entrega el SG1 al administrador. El administrador crea los vendedores desde el módulo Equipo.

Los sitios estáticos se generan durante la compilación: si cambias `STOCKGO_API_URL`, vuelve a desplegar el frontend. Render documenta que un sitio estático usa `runtime: static` y que sus variables son de compilación, no secretas en tiempo de ejecución. [Referencia de Blueprint de Render](https://render.com/docs/blueprint-spec) y [sitios estáticos de Render](https://render.com/docs/static-sites).

## Configuración manual en otro proveedor

### Backend

Usa el contenido de `backend/` y [backend/.env.example](../backend/.env.example):

- Ejecuta `python -m stockgo_cloud.start` o construye `backend/Dockerfile`.
- Configura `API_PUBLIC_URL=https://api.tu-dominio.example`.
- Configura `ALLOWED_ORIGINS=https://app.tu-dominio.example` con URLs exactas, sin `*`.
- Guarda `DATABASE_URL` y `PROVISIONING_KEY` en el gestor de secretos del proveedor.
- En producción utiliza PostgreSQL privada con TLS. Nunca publiques el puerto 5432.

### Frontend

Usa [frontend_web/.env.example](../frontend_web/.env.example):

```powershell
$env:STOCKGO_API_URL = 'https://api.tu-dominio.example'
python .\frontend_web\build.py
```

Publica solo `frontend_web/dist/` en un host estático HTTPS. `config.js` contiene la URL pública de API, por lo que puede ser visible; no es un lugar para contraseñas ni claves.

## Docker local para desarrollo

```powershell
Copy-Item .env.example .env
# Edita POSTGRES_PASSWORD y PROVISIONING_KEY con secretos locales.
$env:STOCKGO_API_URL = 'http://127.0.0.1:8081'
python .\frontend_web\build.py
docker compose up --build
```

API local: `http://127.0.0.1:8081`. Cliente web local: `http://127.0.0.1:8082`. Este modo es solo de desarrollo y no reemplaza el despliegue central.
