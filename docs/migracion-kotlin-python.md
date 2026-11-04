# StockGo: Android Kotlin, servidor Python y clientes Flutter

Fecha: 2 de noviembre de 2026. Esta implementación está separada de la entrega Flutter 1.2.0; no requiere fusionar ramas ni reemplazar datos existentes.

## Arquitectura elegida

| Componente | Tecnología | Responsabilidad |
|---|---|---|
| Android nuevo | Kotlin, vistas Android, lifecycleScope y corrutinas | Conexión, cuentas, inventario, imágenes, ventas y reportes |
| PC maestra | Python 3.11+ y SQLite | Datos oficiales del negocio, autenticación, permisos y transacciones |
| Panel del servidor PC | Tkinter | Crear/importar negocios, validar Administrador, iniciar/detener y copiar código |
| iOS, navegador, Windows y macOS | Flutter existente | Conectarse al mismo negocio mediante el contrato HTTP conservado |

En este alcance **el servidor es la PC**, no el teléfono. Android Kotlin necesita conexión al maestro para consultar y guardar. No se ha implementado Room, inventario sin conexión ni sincronización posterior. SQLite se conserva como almacenamiento local del servidor, sin Firebase ni servicios de pago.

El código SG1 contiene la dirección y el identificador persistente del negocio. No cifra la información ni concede rol administrativo. Cada cuenta pertenece a la base del negocio seleccionado. Se permiten varios negocios con nombres distintos en el catálogo de esa PC; la unicidad no se consulta en un registro mundial. Este panel aloja **un negocio a la vez**, en el puerto 8081. Otros maestros pueden alojar otros negocios con sus propios códigos.

## Archivos principales

| Ruta | Contenido |
|---|---|
| `android_kotlin/` | Proyecto Android Studio independiente; no carga el motor Flutter |
| `android_kotlin/app/src/main/java/com/stockgo/nativeapp/Api.kt` | Código SG1, validación de destinos, cliente HTTP, sesiones |
| `android_kotlin/app/src/main/java/com/stockgo/nativeapp/MainActivity.kt` | Pantallas nativas, navegación por módulos, formularios y cuenta de venta |
| `android_kotlin/app/src/main/java/com/stockgo/nativeapp/ProductFields.kt` | Fichas diferentes y opciones por categoría |
| `servidor_python/stockgo/database.py` | Esquema SQLite v10, catálogo, importación y hashes compatibles |
| `servidor_python/stockgo/service.py` | Permisos y reglas de productos, cuentas, contraseñas y ventas |
| `servidor_python/stockgo/http_server.py` | API compatible con Flutter, CORS y límites de solicitudes |
| `servidor_python/stockgo/desktop.py` | Panel gráfico de administración del servidor |
| `lib/` | Clientes Flutter conservados |

## Empezar sin usar la terminal para los códigos

1. Abre `dist/StockGo-Servidor-Python.exe` en Windows. Es un ejecutable portátil del panel: no es el instalador de la interfaz Flutter. No requiere instalar Python en la PC de destino.
2. Selecciona **Crear negocio**. Escribe nombre de negocio, nombres y apellidos del administrador, usuario y contraseña. Los nombres personales no admiten números; el usuario admite letras, puntos y guiones. La contraseña tiene entre 8 y 128 caracteres y se confirma antes de crear la cuenta.
3. Selecciona el negocio e ingresa sus credenciales Administrador. Pulsa **Iniciar servidor**. Una cuenta Vendedor no puede activar el maestro.
4. Elige la dirección adecuada en la lista. Para un teléfono real utiliza la IP Wi-Fi/Ethernet de la PC, por ejemplo `http://192.168.0.2:8081`. No utilices una tarjeta VirtualBox o Hyper-V si el teléfono no pertenece a esa red.
5. Pulsa **Copiar código para el equipo**. El código está dentro del sistema; no se imprime en la terminal.
6. Instala `dist/StockGo-Kotlin-Android.apk`. Aparece como **StockGo Kotlin** y puede coexistir con el APK Flutter anterior.
7. En Android pega el SG1 completo, pulsa **Conectar al negocio** e inicia sesión. El administrador puede crear vendedores desde **Módulos → Vendedores y equipo → Crear integrante** y compartir el código desde **Invitar al negocio**.
8. El vendedor entra con su cuenta y registra ventas desde Inventario o Cuenta. El invitado consulta productos activos y puede cerrar sesión.

La PC y el teléfono deben poder comunicarse en la misma red. Si Windows solicita acceso de firewall, permite el programa solo en tu red privada autorizada. No abras el puerto en el router. El panel debe permanecer abierto; cerrar o detener el maestro interrumpe las conexiones. Si otra instancia StockGo ya ocupa 8081, detenla desde su propia interfaz antes de iniciar Python: el panel muestra el error y no termina otros procesos.

Para un emulador Android, la dirección especial hacia la PC anfitriona es `http://10.0.2.2:8081`, disponible en el selector. Ese código no sirve para un teléfono físico. Esta entrega no inicia ningún emulador automáticamente.

## Ejecutar desde el código en VS Code

Instala Python 3.11 o posterior con Tcl/Tk. No hay dependencias externas para ejecutar el servidor. El script busca Python y omite el alias de Microsoft Store; también admite `STOCKGO_PYTHON` con una ruta explícita.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\iniciar_servidor_python.ps1
```

También puedes usar **Terminal → Ejecutar tarea → StockGo: servidor Python (panel gráfico)**. Para depurar Python instala las extensiones recomendadas y usa la configuración **StockGo - Servidor Python**, seleccionando tu intérprete Python. Sus códigos y contraseñas siguen apareciendo únicamente en la interfaz.

Para Flutter web conserva el comando existente:

```powershell
& C:/src/flutter/bin/flutter.bat run -d chrome --web-hostname=localhost --web-port=8080
```

Dentro de Flutter usa **Conectarme a un negocio**, pega el código generado por Python y accede con la cuenta del mismo negocio. El servidor API no sirve por sí solo los archivos de la aplicación web. No confundas el puerto web 8080 con el API 8081.

Para Android abre `android_kotlin/` en Android Studio, sincroniza Gradle y elige el teléfono conectado. Desde VS Code hay una tarea **StockGo: ejecutar Android Kotlin (dispositivo conectado)** que compila, instala y abre el APK de depuración, sin iniciar un emulador. Requiere Platform Tools y autorizar depuración USB. Las configuraciones Flutter de Android se conservan etiquetadas como históricas.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\ejecutar_android_kotlin.ps1
# Si hay más de un dispositivo:
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\ejecutar_android_kotlin.ps1 -Dispositivo IDENTIFICADOR_ADB
```

## Importar un negocio existente de Flutter

1. Haz una copia de seguridad y evita seguir editando el origen durante la transición. Cierra su servidor anterior.
2. En Windows, las bases anteriores suelen estar en `%LOCALAPPDATA%\StockGo\databases\`. Selecciona la base **del negocio**, por ejemplo `stockgo.db_negocio_1.db`, no el catálogo general `stockgo.db`.
3. En el panel Python elige **Importar negocio Flutter** y selecciona el archivo `.db` del esquema 10 (StockGo 1.2.0). Las versiones anteriores deben actualizarse primero desde Flutter.
4. Se abre el origen en modo lectura y se utiliza SQLite backup para obtener una copia consistente, incluyendo operaciones ya confirmadas en WAL. Se comprueban tablas, columnas e integridad. El archivo original no se escribe, elimina ni reemplaza.
5. Se conservan nombre, identificador de negocio, usuarios y hashes, roles, códigos internos, productos, imágenes, fichas, existencias, ventas, detalles históricos y auditoría.
6. Los datos nuevos se guardan en `%LOCALAPPDATA%\StockGoPython\`. La copia original y la nueva son independientes después de importar: **no se sincronizan entre sí**. Usa Python como maestro desde ese momento y comparte el código con su nueva dirección.

No se extrae automáticamente la base privada de un teléfono Android ni el IndexedDB de un navegador. Esos casos requieren un archivo SQLite exportado de forma autorizada. El identificador Android nuevo es `com.stockgo.nativeapp`, distinto del Flutter anterior: evita reemplazarlo accidentalmente, pero no puede leer sus archivos privados. No desinstales el anterior para intentar importar datos.

## Funciones de Android Kotlin

- Login, registro de vendedor, acceso Invitado y cierre de sesión. El rol se obtiene del servidor.
- Administrador: crear integrantes Administrador/Vendedor, consultar equipo, copiar invitación, restablecer otra contraseña con reautenticación y consultar auditoría.
- Cambiar contraseña propia y forzar cambio de una temporal antes de acceder al inventario. Las temporales vencen en 30 minutos y revocan sesiones anteriores.
- Buscar inventario por nombre/código/marca/referencia, ver ficha, precio y disponibilidad. Solo Administrador registra, edita y desactiva.
- Formularios diferentes para Lubricante, Repuesto, Filtro, Aditivo y Accesorio. SAE, API, base, unidades, materiales y otras opciones permiten selección y entrada manual según el fabricante.
- Fotos mediante selector del sistema, sin permiso general de almacenamiento. Original máximo 20 MB, decodificación y procesamiento fuera del hilo de interfaz, corrección de orientación EXIF, máximo 1200 px y PNG final hasta 5 MB.
- Venta con varios productos, cantidad entera de cada unidad de venta y lote del fabricante guardado en el detalle. No hay conversión automática entre caja y piezas ni stock de varios lotes dentro de un mismo SKU.
- Confirmación con total y vendedor identificado por nombres, apellidos y código interno.
- Historial, filtros de periodo y vendedor (Administrador), ingresos, unidades, ticket promedio, margen bruto estimado (Administrador) y productos más vendidos. El vendedor ve únicamente sus ventas.
- Paleta celeste/azul, encabezado degradado, tarjetas con relieve, transición de entrada, menú de módulos y gráficos simples de productos vendidos.

Una cuenta normal sin confirmar permanece en memoria. Al enviar una venta se guarda en el almacenamiento privado un resumen y su identificador de reintento, sin fotografías ni costos: permite recuperar una respuesta pendiente después de cerrar el proceso y volver a iniciar sesión en el mismo negocio con la misma cuenta. El servidor usa ese identificador para no duplicar la venta. Consulta siempre el historial si se interrumpe una operación. No equivale a vender sin conexión.

## Validaciones y seguridad conservadas

- PBKDF2-HMAC-SHA256, 120 000 iteraciones, salt aleatoria, comparación de hashes con `hmac.compare_digest`. Compatibilidad con contraseñas de la base Flutter importada.
- Sesiones aleatorias de 256 bits, vencimiento a 8 horas y comprobación de versión de credencial en cada operación. No se guarda el token en disco en el cliente Kotlin.
- Permisos comprobados en Python, además de ocultar botones. Costos/proveedores y costos históricos se excluyen de respuestas a vendedores/invitados.
- Nombre/código y categoría válidos, código único incluso desactivado, cantidades enteras no negativas, precios finitos con dos decimales, venta ≥ compra, fechas reales, lote obligatorio en lubricantes/aditivos.
- Lote y vencimiento no se cambian mientras quede stock de un lote identificado. No se venden productos vencidos o sin existencias.
- Ventas SQLite transaccionales, descuento condicionado, control de precio esperado, límites del total e idempotencia. Desactivar conserva productos y ventas históricas.
- Límites de intentos por IP/ruta, sesiones y tamaño de solicitudes, conexión con timeout y número acotado de hilos. No se registran credenciales ni claves temporales en logs.
- HTTP nativo restringido en el cliente a redes privadas o al rango VPN explícito del código; redirecciones rechazadas. El manifiesto habilita HTTP para el prototipo LAN ya autorizado.

**Límites importantes:** SQLite no está cifrado; el HTTP de Wi-Fi no incorpora TLS. El servidor basado en la biblioteca estándar de Python se entrega para demostración y pruebas locales/VPN; no debe publicarse directamente en Internet como servicio de producción. El registro de vendedores por código conserva el comportamiento anterior y no incluye aprobación administrativa previa. No hay recuperación automática por correo ni cuenta maestra oculta. La administración remota requiere una cuenta Administrador autorizada y un túnel configurado por separado. El código no instala ni verifica Tailscale. La interfaz Windows para activar el maestro exige una contraseña Administrador vigente; si la única cuenta es temporal y no hay otro servidor activo, requiere recuperación presencial autorizada.

El EXE no tiene firma de editor comercial y el APK usa la firma de desarrollo propia de StockGo. Esto no garantiza eliminar advertencias de Windows o Google Play Protect. No se pide desactivar sus protecciones.

## Compilar y verificar

SDK Android 36, Java 17 o compatible y Gradle wrapper incluido. AGP 9.1 usa Kotlin integrado; no se aplica el plugin Flutter al proyecto nativo. El APK tiene mínimo Android 7.0/API 24; la biblioteca de desugaring permite usar fechas en esas versiones.

```powershell
# APK release con la firma original de StockGo
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\compilar_android_kotlin.ps1
# Compilar y ejecutar pruebas Kotlin + análisis Android
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\compilar_android_kotlin.ps1 -Verificar
# Ejecutable portátil de servidor Windows (incluye Python/Tk)
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\compilar_servidor_python.ps1
# Pruebas Python, compatibilidad Flutter/Python, análisis Flutter y Kotlin
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verificar_migracion.ps1
```

El empaquetador Python instala PyInstaller en `build/tools/python-packaging`, sin cambiar los paquetes globales. La primera compilación necesita Internet. Ejecutar el servidor desde fuentes no lo necesita. El empaquetado se hace en Windows para generar EXE Windows.

`scripts/compilar_apk.ps1` ahora dirige a Kotlin. `-FlutterLegacy` conserva explícitamente la compilación Android Flutter anterior. `crear_instaladores.ps1` conserva el instalador de la interfaz Windows Flutter y utiliza el APK Kotlin para Android. El servidor Python se empaqueta por su script separado; no está integrado automáticamente en el instalador Flutter.

Salidas nuevas:

- `dist/StockGo-Kotlin-Android.apk`: Android nativo firmado, para instalar en teléfono.
- `dist/StockGo-Servidor-Python.exe`: panel y servidor portátil, para abrir en PC.
- `dist/StockGo-Kotlin-Android-debug.apk`: solo si se solicita `-Debug`; usa firma de depuración y no actualiza un release firmado.

Las claves no se incluyen en Git ni en estos paquetes. Se utiliza `%LOCALAPPDATA%\StockGoBuildKeys\stockgo-release.jks` y su secreto protegido existente. Conserva la misma firma para actualizar el APK Kotlin en el futuro.

## Pruebas y limitaciones de verificación

Las pruebas Python ejercitan HTTP real y SQLite temporal: roles, imágenes, búsqueda, baja lógica, aislamiento de negocios, duplicados, importación sin escritura en el origen, transacciones y concurrencia, idempotencia, precio/lote/vencimiento, sesiones, restablecimiento y auditoría, CORS y límites. Una prueba Tk ejecuta la activación y detención desde el panel con credenciales válidas e inválidas, sin usar datos reales.

La prueba Kotlin ejecuta el cliente HTTP real de la app contra un servidor Python efímero: conexión, login, creación de producto/equipo, venta del vendedor, reintento, privacidad de costos, revocación y cambio de contraseña. Las pruebas unitarias validan redes admitidas y fichas por categoría.

`test/python_compatibility_test.dart` crea una base con el repositorio Flutter real, la importa en Python y se conecta con el cliente Flutter real. Comprueba que las cuentas y ventas anteriores se conservan, que el vendedor puede vender y que la base original queda sin modificar.

Compilar y pasar estas pruebas no sustituye probar el APK en un teléfono físico, permisos de firewall, el selector de fotos de cada fabricante, accesibilidad, cambios de red o un túnel remoto real. iOS/macOS se conservan en Flutter; no se ha generado ni validado un binario Apple desde Windows.

## Referencias técnicas

- Android Developers, AGP 9.1 y requisitos: https://developer.android.com/build/releases/agp-9-1-0-release-notes
- Python, SQLite y backup: https://docs.python.org/3/library/sqlite3.html
- Python, alcance de http.server: https://docs.python.org/3/library/http.server.html
- PyInstaller, generación de ejecutables y modo windowed: https://pyinstaller.org/en/stable/usage.html
