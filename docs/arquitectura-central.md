# Arquitectura central en la nube

## Flujo de los equipos

```text
Usuario Android / Navegador / Lanzador de PC
                 │
                 │ HTTPS para acceso y operaciones
                 │ WSS para cambios en tiempo real
                 ▼
           API StockGo Python
                 │ conexión privada TLS
                 ▼
            PostgreSQL administrada
```

Cada negocio se crea una sola vez por el responsable de la plataforma. La API devuelve un código `SG1` que contiene únicamente la URL HTTPS pública de la API y el identificador no secreto del negocio.

El administrador entrega ese código a vendedores. El código no contiene una contraseña, no entrega permisos de administrador y no permite ejecutar un servidor en el teléfono.

## Límites de cada componente

- `backend/`: único componente con `DATABASE_URL`, migraciones y `PROVISIONING_KEY`.
- `frontend_web/`: archivos estáticos. Al compilar se crea `config.js` con `STOCKGO_API_URL`; esa URL es pública.
- `android_kotlin/`: recibe el SG1, valida HTTPS y se conecta a la API central. No conoce las credenciales PostgreSQL.
- `desktop/`: abre el sitio web HTTPS. No inicia Python, PostgreSQL ni un servidor LAN.

## Crear negocios sin exponer secretos

La ruta `POST /businesses` sigue protegida por el encabezado `X-StockGo-Provisioning-Key`. No hay un formulario público para crear negocios en el frontend ni en Android. El responsable de la plataforma realiza ese aprovisionamiento desde una herramienta interna o una consola segura del proveedor y entrega después el SG1 resultante.

No pongas `PROVISIONING_KEY`, `DATABASE_URL`, archivos `.env` reales, certificados ni copias de base de datos en Git, en el APK o en el sitio estático.

## Consumo eficiente

La API usa WebSockets autenticados para avisar cambios. No consulta el inventario cada pocos segundos: el cliente mantiene una caché breve, recibe invalidaciones y revalida con ETag. PostgreSQL usa un listener `LISTEN/NOTIFY` por proceso, no por cada vendedor conectado.
