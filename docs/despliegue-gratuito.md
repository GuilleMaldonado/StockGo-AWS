# Prueba gratuita, `.env` y conexión de los clientes

Configuración revisada el 4 de noviembre de 2026. No se han creado recursos AWS ni contratado servicios. La prueba local utiliza PostgreSQL en esta PC; no emula una base con SQLite.

## Opción sencilla: Render gratuito

El repositorio incluye `render.yaml`: un servicio web Docker **free** y una base PostgreSQL **free**, en la misma región. La API, el WebSocket y el frontend web se publican juntos. El APK es un cliente de ese mismo backend.

1. Crea tu cuenta de Render desde su página oficial y conecta GitHub con los permisos que elijas. La aceptación de condiciones y las credenciales las completas tú.
2. Elige **New → Blueprint**, selecciona `jhonnatanGranados/StockGo-AWS` y la rama **codex/aws-postgresql**.
3. Revisa que **servicio y base indiquen Free** antes de crear. No selecciones planes de pago. Si tu cuenta o región no ofrece la opción gratuita o exige un compromiso de pago, detén ese paso y utiliza la prueba local.
4. Render lee el Dockerfile y `render.yaml`. `DATABASE_URL` se enlaza a la base automáticamente. `PROVISIONING_KEY` se genera como secreto y no se publica en Git. El URL se toma de `RENDER_EXTERNAL_URL` si no defines `PUBLIC_API_URL`.
5. Espera a que termine el primer despliegue. El inicio ejecuta Alembic, con bloqueo para que dos procesos no migren simultáneamente. Abre la dirección `https://TU-SERVICIO.onrender.com`.
6. En el panel privado de variables de Render copia el valor de `PROVISIONING_KEY`. En la página StockGo elige **Crear un negocio**, escribe la clave de aprovisionamiento y los datos de su administrador. No incluyas esa clave en un APK ni se la entregues a vendedores.
7. Inicia sesión y abre **Invitar al negocio**. Copia el SG1 de ese URL HTTPS. En el APK StockGo Cloud pega el código e inicia sesión con tu cuenta del negocio.
8. Usa dos dispositivos o un navegador y un teléfono. Crea un producto, vende a un cliente con nombre y descripción y verifica el cambio en el otro. Como Administrador anula la venta: debe volver el stock, quedar marcada como anulada y desaparecer de los ingresos del informe.

Render permite WebSockets. Un servicio free sin tráfico se detiene tras 15 minutos; al siguiente acceso puede tardar aproximadamente un minuto en arrancar. Los clientes cierran el canal al ir a segundo plano y reconectan con espera progresiva al volver. No hay un monitor externo manteniendo despierto el servicio.

**Duración de la prueba:** la base PostgreSQL gratuita de Render caduca a los 30 días, tiene 1 GB y no incluye respaldos administrados. Hay límites de horas, transferencia y compilación. No es almacenamiento permanente para negocios reales. Usa datos ficticios en la presentación, exporta tus datos antes de la fecha límite y revisa los límites en el panel. No se promete gratuidad ilimitada ni se activa una actualización de pago.

Fuentes oficiales: [planes gratuitos y limitaciones](https://render.com/docs/free), [primer despliegue](https://render.com/docs/your-first-deploy), [Blueprint YAML](https://render.com/docs/blueprint-spec).

## Archivo `.env`

- `.env.example`: plantilla pública completa, sin credenciales reales; se puede subir a GitHub.
- `.env`: configuración de la prueba local de esta PC; está excluida de Git.
- `.env.render`: plantilla privada preparada para cargar variables manualmente en el proveedor; debes completar `DATABASE_URL` y tu URL HTTPS, o usar el Blueprint que las enlaza por ti. También está excluida de Git.

Para configurar manualmente un Web Service de Render, usa Docker, rama `codex/aws-postgresql`, directorio raíz del repositorio, Dockerfile `Dockerfile`, health check `/health` y plan Free. En Environment importa `.env.render` después de reemplazar los valores pendientes. No subas ese archivo al repositorio público. Las claves permanecen solo en la configuración del backend.

| Variable | Para qué sirve |
|---|---|
| `APP_ENV` | `development` local; `production` en el proveedor |
| `DATABASE_URL` | Conexión PostgreSQL privada: usuario, contraseña, host, puerto y base; admite `postgresql://` o `postgresql+psycopg://` |
| `PUBLIC_API_URL` | Dirección HTTPS pública, sin `/api` ni barra final; se incluye en los códigos SG1 |
| `PROVISIONING_KEY` | Secreto del responsable del servicio para crear negocios |
| `ALLOWED_ORIGINS` | URLs exactas autorizadas para navegador; el URL propio se agrega automáticamente |
| `DB_SSLMODE` | `verify-full` verifica certificado y hostname. El Blueprint usa `require` solo para la conexión interna de Render: cifra, pero no verifica la identidad del servidor PostgreSQL |
| `DB_SSLROOTCERT` | Archivo CA para `verify-full`; vacío utiliza el conjunto de certificados públicos de Python. Para RDS se requiere su CA de AWS |
| `DB_POOL_SIZE` | Conexiones reutilizadas por proceso; predeterminado 3 |
| `DB_MAX_OVERFLOW` | Conexiones adicionales máximas por proceso; predeterminado 2 |
| `WEB_CONCURRENCY` | Procesos de API; usar 1 en la prueba gratuita. Multiplica el pool y el listener por cada proceso |
| `PORT` | Puerto interno del proceso; el proveedor puede asignarlo automáticamente |
| `FORWARDED_ALLOW_IPS` | Proxy de confianza para reconocer HTTPS/WSS; `*` solo detrás del proxy administrado de Render o de un balanceador que sea el único autorizado a alcanzar el contenedor |
| `POSTGRES_PASSWORD` | Solo para Docker Compose local. No lo utiliza el RDS ni Render enlazado por Blueprint |

Si no defines `DATABASE_URL`, la API también admite `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`; esto permite inyectar secretos de AWS sin construir una URL en el APK. Los valores con símbolos deben ir codificados si se usan dentro de una URL. No añadas `sslmode=disable` para resolver errores TLS.

## WebSocket y consumo

El acceso inicial usa HTTPS. Después el canal `/ws` se autentica con un primer mensaje JSON que contiene la sesión y el negocio, sin poner el token en el URL. Las solicitudes llevan identificador y las respuestas se correlacionan por ese identificador. El servidor valida rol y negocio en cada solicitud, aunque el canal ya esté abierto.

Un solo `LISTEN/NOTIFY` de PostgreSQL por proceso distribuye invalidaciones a sus clientes; no se abre una conexión PostgreSQL por cada WebSocket. Las escrituras avisan después de confirmar la transacción. Los avisos no incluyen el inventario ni los datos del cliente. La reconexión solicita una fotografía actual para cubrir avisos perdidos; los avisos no son una cola duradera.

No se consulta inventario mediante polling. Los eventos se agrupan durante 750 ms, las búsquedas esperan 600 ms al terminar de escribir y el catálogo carga 50 miniaturas por página. La caché de 45 segundos se invalida con cambios; al revalidar se usa ETag/304 para no reenviar un catálogo sin cambios. Se actualiza también al entrar, al pulsar Actualizar y después de las propias modificaciones. Los precios y el stock se comprueban de nuevo en PostgreSQL al confirmar una venta: la caché no autoriza ventas.

Los pings del protocolo mantienen un canal activo; también consumen algunos bytes y memoria. No se afirma que un WebSocket no consuma recursos. Al desaparecer los clientes se cierra el listener. `/health` comprueba el proceso sin consultar inventario ni despertar la base; `/ready` verifica la conexión PostgreSQL cuando se necesita diagnosticarla.

## Prueba local sin contratar alojamiento

En esta PC se preparó una instalación portátil de PostgreSQL únicamente dentro de `build/tools/pgsql`, con datos de demostración dentro de `build/pgdata`, accesible por loopback en el puerto 55439. No se instaló un servicio Windows ni se abrió el firewall.

```powershell
# Desde la carpeta StockGo-AWS:
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\iniciar_local.ps1
```

Abre `http://127.0.0.1:8081`. La base debe estar iniciada antes de ejecutar ese comando. En otra PC instala PostgreSQL o utiliza Docker Compose; `build/` no se sube a GitHub y no contiene un instalador portátil distribuido.

Para volver a iniciar la base portátil de esta PC:

```powershell
.\build\tools\pgsql\bin\pg_ctl.exe -D .\build\pgdata -l .\build\postgres-test.log -o "-h 127.0.0.1 -p 55439" -w start
```

El modo de autenticación `trust` de esa base es exclusivo de la prueba por loopback; no lo uses en un servidor compartido ni copies el `.env` local como configuración de producción.

El navegador y el servidor pueden probarse en esta PC sin emulador. Para Android emulado, el anfitrión suele ser `10.0.2.2`; para un teléfono real en Wi-Fi utiliza la dirección privada de la PC y un código generado para esa dirección. Un código con `127.0.0.1` solo alcanza el dispositivo donde se abre. Cuando el servidor es Render, todos usan el mismo URL HTTPS y no dependen de la Wi-Fi de la PC.

## Amazon más adelante

La API está encapsulada por el Dockerfile y separada de PostgreSQL. La misma imagen se puede ejecutar en un contenedor o instancia de AWS. Configura un RDS PostgreSQL privado al que solo llegue el backend y una entrada HTTPS que admita WebSockets. Para verificar RDS utiliza su CA oficial y `DB_SSLMODE=verify-full`. No expongas 5432 al teléfono ni incluyas contraseñas de base de datos en el APK. No se han creado stacks ni recursos facturables.
