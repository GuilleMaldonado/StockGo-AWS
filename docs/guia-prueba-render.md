# Guía de publicación y prueba en Render

## 1. Crear la infraestructura

1. Inicia sesión en [Render](https://dashboard.render.com/) usando la cuenta de GitHub propietaria del repositorio.
2. Selecciona **New → Blueprint** y elige `jhonnatanGranados/StockGo-AWS`.
3. Selecciona la rama `codex/aws-postgresql` y confirma el Blueprint.
4. Espera a que se creen `stockgo-api-demo`, `stockgo-web-demo` y `stockgo-demo-db`.
5. En cada servicio abre **Events** hasta ver el estado **Live**. Copia las URL públicas de API y sitio web desde el panel, sin modificarlas.

El archivo `render.yaml` ya define HTTPS, CORS, PostgreSQL, secretos, migraciones al arrancar y despliegue automático por commit. La API usa la base únicamente desde el backend; Android y web nunca reciben `DATABASE_URL`.

## 2. Verificar que la nube funciona

Con las URL reales, ejecuta desde la carpeta del proyecto:

```powershell
.\scripts\verificar_render.ps1 `
  -ApiUrl 'https://TU-API.onrender.com' `
  -WebUrl 'https://TU-WEB.onrender.com'
```

Debe mostrar tres líneas `OK`: API health, API ready y Sitio web. Si Render dejó dormir la API gratuita, la primera comprobación puede tardar hasta 90 segundos.

## 3. Crear el administrador de plataforma y el primer negocio

Hay dos niveles distintos de administración:

| Nivel | Dónde entra | Qué puede hacer |
|---|---|---|
| Responsable de plataforma | Panel de Render | Gestiona despliegue, PostgreSQL, logs y secretos. |
| Administrador del negocio | Aplicación StockGo | Gestiona inventario, vendedores, ventas, auditoría y recuperación de cuentas. |

Para crear el primer negocio:

1. En Render abre `stockgo-api-demo → Environment`.
2. Copia temporalmente `PROVISIONING_KEY` en un lugar seguro. No la envíes por WhatsApp ni la subas a GitHub.
3. Abre la URL de `stockgo-web-demo`.
4. Selecciona **Crear negocio**.
5. Completa nombre único del negocio, nombres, apellidos, usuario y contraseña del administrador inicial.
6. Pega `PROVISIONING_KEY` y confirma.
7. StockGo mostrará un código **SG1**. Guárdalo: identifica el negocio y permite que otros dispositivos se conecten a la nube correcta.
8. Regresa a Render y regenera `PROVISIONING_KEY` cuando termines la prueba. Así la clave usada deja de servir.

El primer usuario es **Administrador del negocio**. Su contraseña no se muestra ni se puede recuperar como texto; puede generar claves temporales para vendedores desde el módulo Equipo.

## 4. Crear vendedores y compartir el código

1. Inicia sesión con el administrador inicial y abre **Vendedores y equipo**.
2. Selecciona crear integrante, escribe nombres, apellidos, usuario y contraseña inicial; el sistema crea también su código interno.
3. Abre **Invitar al negocio** y copia el SG1.
4. Entrega el SG1 al vendedor por un canal privado. El código no otorga permisos: solo indica a qué negocio y API debe conectarse.
5. En Android o web, el vendedor pega SG1, inicia sesión con su propio usuario y contraseña, y puede consultar inventario y registrar ventas.

No reutilices la cuenta Administrador entre vendedores. Así cada venta conserva quién la realizó.

## 5. Recuperar acceso

1. El vendedor selecciona **Recuperar contraseña**, escribe SG1 y usuario.
2. StockGo registra la solicitud sin confirmar si el usuario existe.
3. El administrador abre **Vendedores y equipo**, selecciona el usuario y usa **Restablecer contraseña**.
4. El administrador confirma su propia contraseña. Se muestra una clave temporal válida por 30 minutos.
5. El vendedor entra con esa clave y debe crear una contraseña nueva antes de continuar.

## 6. Prueba funcional recomendada

1. Crea un negocio y guarda el SG1.
2. Crea un vendedor con nombre y apellidos reales de prueba.
3. Registra un producto con precio de compra menor o igual a precio de venta y cantidad positiva.
4. Inicia sesión como vendedor desde otro navegador o Android usando el SG1.
5. Busca el producto, agrégalo a la cuenta, escribe nombre y descripción breve del cliente y confirma la venta.
6. Verifica desde Administrador que se redujo el stock y que el historial indica el vendedor correcto.
7. Anula la venta como Administrador y comprueba que el stock vuelve una sola vez.
8. Solicita recuperación de contraseña para el vendedor y verifica el flujo de clave temporal.

## 7. Rutas de consulta

Reemplaza `TU-API` por la URL real de Render:

| Ruta | Uso |
|---|---|
| `https://TU-API.onrender.com/health` | Estado básico de proceso y API. |
| `https://TU-API.onrender.com/ready` | Comprueba conexión a PostgreSQL. |
| `https://TU-API.onrender.com/ws` | WebSocket interno de la aplicación; no abrir manualmente para administrar. |
| URL de `stockgo-web-demo` | Interfaz de administración, vendedores y ventas. |

No existe una ruta pública que permita administrar negocios sin autenticación ni una ruta para revelar contraseñas. Eso es intencional.
