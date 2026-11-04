# StockGo — Android Kotlin · Servidor Python · Clientes Flutter

## Migración Kotlin y Python

La nueva aplicación Android nativa está en `android_kotlin/`. El servidor Python para PC está en `servidor_python/` y tiene un panel gráfico para crear/importar negocios, autenticarse como Administrador, iniciar/detener el servidor y copiar el código SG1. Flutter se conserva para iOS, web y escritorio. El APK Kotlin es un cliente conectado: en esta arquitectura el maestro es la PC; no aloja un servidor en el teléfono ni funciona desconectado.

Guía actual: [instalación, importación y compilación](docs/migracion-kotlin-python.md).

```powershell
# Panel del servidor Python (sin códigos ni contraseñas en la terminal)
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\iniciar_servidor_python.ps1
# APK Android nativo firmado
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\compilar_android_kotlin.ps1
```

También hay tareas en VS Code: **Terminal → Ejecutar tarea → StockGo: servidor Python** y **StockGo: compilar APK Kotlin**. Abre `android_kotlin/` en Android Studio para depurar Kotlin. Las configuraciones Flutter de Android permanecen identificadas como históricas. `compilar_apk.ps1` genera Kotlin por defecto; `-FlutterLegacy` permite reconstruir la entrega anterior. Los instaladores Flutter existentes no se sustituyen automáticamente.

Las notas siguientes describen la versión Flutter anterior y sus plataformas conservadas; no son las instrucciones del nuevo APK Kotlin.

## Versión 1.2.0 y mantenimiento remoto

La versión actual incorpora restablecimiento administrativo con contraseña temporal, cambio obligatorio, revocación de sesiones, auditoría y códigos para una conexión privada con Tailscale. Consulta [mantenimiento remoto](docs/mantenimiento-remoto.md) para instalación, permisos y prueba entre dispositivos. El túnel debe instalarse y autorizarse aparte; StockGo no contrata alojamiento ni configura cuentas externas. SQLite migra a versión 10 conservando los datos. El informe Word de 1.1.2 conserva su valor como documentación de esa entrega anterior.

Las notas siguientes incluyen procedimientos históricos. Para distribuir la versión actual utiliza `scripts/crear_instaladores.ps1` y conserva la firma Android original.

Aplicación de inventario y Login con tres roles, con almacenamiento local SQLite.
Android usa sqflite; Chrome y Edge usan SQLite WebAssembly, guardado en IndexedDB.

## Ejecutar desde VS Code

1. Abre esta carpeta raíz, donde está `pubspec.yaml`.
2. Instala las extensiones Flutter y Dart recomendadas por el proyecto.
3. Si pide el SDK, selecciona `C:/src/flutter`.
4. Abre **Ejecutar y depurar** (`Ctrl + Shift + D`).
5. Selecciona **StockGo - Chrome** y pulsa **F5**.

La configuración está en `.vscode/launch.json`. También hay una configuración
**StockGo - Edge**. Ambas usan `http://localhost:8080` para mantener la misma
ubicación del almacenamiento entre ejecuciones.

Para ejecutar desde la terminal de VS Code:

```powershell
& C:/src/flutter/bin/flutter.bat pub get
& C:/src/flutter/bin/flutter.bat run -d chrome --web-hostname=localhost --web-port=8080
```

Detén la ejecución anterior antes de comenzar otra en el puerto 8080. Desde la
terminal de Flutter usa `q`; desde VS Code usa el botón Detener.

## Archivos web necesarios

El repositorio incluye `web/sqlite3.wasm` y `web/sqflite_sw.js`.
Si actualizas la dependencia SQLite web, regenera los archivos compatibles:

```powershell
& C:/src/flutter/bin/dart.bat run sqflite_common_ffi_web:setup --force
```

También se incluyen scripts `scripts/preparar.ps1` y `scripts/ejecutar.ps1`, y
sus tareas en `.vscode/tasks.json`. Para el uso habitual basta con F5 o el
comando Flutter anterior.

## Accesos de demostración

| Rol | Usuario | Contraseña |
| --- | --- | --- |
| Administrador | admin | Admin123! |
| Vendedor | vendedor | Vendedor123! |
| Invitado | Botón «Continuar como invitado» | Sin contraseña |

Los usuarios se crean al inicializar la base de datos. El rol se obtiene de
SQLite; no se selecciona antes de entrar. Las contraseñas se guardan con
PBKDF2-HMAC-SHA256 y salt individual. La sesión se cierra al reiniciar la app.

## Probar el inventario

1. Entra como administrador y pulsa **Gestionar Productos**.
2. Pulsa **Agregar producto** y registra Cuaderno, CUAD-001, 15.50 y 20.
3. Guarda: el producto aparece en el inventario.
4. Busca por nombre o código y selecciona un producto para ver el detalle.
5. Usa **Editar** para actualizarlo o **Desactivar** y confirma el cambio.
6. Activa **Mostrar también desactivados** para ver el historial.
7. Entra como vendedor o invitado: solo podrás buscar y consultar activos.
8. Recarga el navegador y vuelve a entrar: los productos deben seguir guardados.

Desactivar cambia `activo` a 0; nunca elimina la fila. El código sigue reservado.
Los permisos administrativos se comprueban en la interfaz y en el acceso a datos.

## Almacenamiento por plataforma

- Android: archivo `stockgo.db` en el almacenamiento privado de la aplicación.
- Navegador: SQLite persistido en IndexedDB del navegador y del origen web.
- Cambiar navegador, hostname o puerto crea otro espacio de almacenamiento.
- Borrar los datos del sitio elimina el inventario de ese navegador.
- Los datos del navegador no se sincronizan con los del teléfono.

## Android

Conecta un teléfono con depuración USB o inicia un emulador. Usa
**Flutter: Select Device** y selecciona Android. Después inicia
**StockGo - dispositivo Android seleccionado**.

Desde la terminal puedes listar los dispositivos y elegir el ID Android:

```powershell
& C:/src/flutter/bin/flutter.bat devices
& C:/src/flutter/bin/flutter.bat run -d ID_DEL_DISPOSITIVO_ANDROID
```

La compilación Android necesita Gradle y los componentes del SDK. El APK anterior
no se generó porque la descarga de Gradle no terminó.

## Error de Visual Studio

`Unable to find suitable Visual Studio toolchain` aparece al elegir **Windows**
como destino nativo. VS Code es el editor; Visual Studio y sus herramientas C++
son los componentes que Flutter necesita para compilar Windows.
Para probar este proyecto usa **StockGo - Chrome**, Edge o un dispositivo Android.
Las configuraciones Chrome/Edge no necesitan compilar la aplicación Windows.

## Estructura

- `lib/main.dart`: arranque de Flutter y navegación según sesión.
- `lib/data/platform/database_connection.dart`: selección por import condicional.
- `lib/data/platform/database_native.dart`: SQLite para móvil y escritorio.
- `lib/data/platform/database_web.dart`: SQLite para Chrome/Edge.
- `lib/data/stockgo_store.dart`: Login, roles, consultas y escrituras con permisos.
- `lib/models/`: usuario y producto.
- `lib/screens/`: Login, inicio, inventario y formulario.
- `.vscode/`: ejecución, tareas, extensiones y ubicación del SDK de este equipo.
- `scripts/`: preparación y ejecución explícita por plataforma.
- `web/sqlite3.wasm` y `web/sqflite_sw.js`: motor SQLite y worker web.
- `test/`: pruebas de datos e interfaz.

## Verificar

```powershell
& C:/src/flutter/bin/flutter.bat analyze
& C:/src/flutter/bin/flutter.bat test
& C:/src/flutter/bin/flutter.bat build web --no-web-resources-cdn
```

La carpeta original contenía la plantilla de Flutter. No incluía archivos Kotlin
ni una base Room para importar. Esta implementación cubre Login y RF-02, RF-03,
RF-04, RF-05 y RF-09. No incluye ventas ni facturación.

El precio se guarda como REAL y se muestra con dos decimales; un futuro módulo
contable debería usar centavos enteros y reglas de redondeo.

Referencias: [SQLite web](https://pub.dev/packages/sqflite_common_ffi_web) y
[configuración de ejecución de Dart/Flutter en VS Code](https://dartcode.org/docs/launch-configuration/).

## Crear cuentas y compartir el inventario

En Login pulsa **Crear cuenta**. Para crear un negocio introduce un nombre de empresa único en este dispositivo. Puedes crear varios negocios y elegirlos en Login; cada uno conserva sus propias cuentas e inventario. Elige **Soy vendedor** para una cuenta de consulta, o **Crear mi negocio** para registrar al primer propietario con rol Administrador. El propietario puede agregar productos con fotos y crear cuentas de vendedor o de administrador. Al configurar el negocio se deshabilitan las contraseñas de demostración. Vendedores e invitados solo consultan productos activos. **Cerrar sesión** está disponible también para invitados y limpia la navegación.

### PC como servidor

Abre la aplicación nativa StockGo para Windows. En Login pulsa **Crear cuenta → Crear mi negocio**, registra al propietario e inicia sesión con esa cuenta de Administrador. Luego pulsa **Compartir inventario → Iniciar servidor**. La dirección y el código completo del negocio (SG1-) aparecen en la propia pantalla: el vendedor copia el código SG1- y lo pega en **Conectarme a un negocio**. No hay que iniciar un servidor desde la terminal ni copiar códigos de ella. Todos deben estar en la misma Wi-Fi; el firewall de la PC debe permitir el puerto 8081 en la red privada.

Para desarrollar en VS Code selecciona **StockGo - Windows (servidor desde la app)** y pulsa F5. La compilación nativa Windows requiere Visual Studio con las herramientas C++ para escritorio; VS Code es el editor y no reemplaza ese compilador. Chrome puede ser cliente, pero el navegador no puede escuchar conexiones como servidor. Si esas herramientas no están instaladas, usa la app Android/iOS como servidor.

### Teléfono como servidor

En Android o iOS, crea tu negocio localmente, inicia sesión como propietario y pulsa **Compartir inventario**. Inicia el servidor y copia el código completo del negocio y pégalo en el Login de los demás dispositivos. El inventario compartido es el de ese teléfono. Mantén la aplicación abierta y el teléfono activo: este prototipo no implementa un servicio en segundo plano. Cerrar la sesión del propietario detiene su servidor.

El navegador puede conectarse a un servidor, pero no alojarlo. Cada negocio tiene su propia base y puede compartirse desde el dispositivo que la aloja. Cada PC o teléfono mantiene su catálogo de negocios; elige un servidor para cada negocio. No hay mezcla automática entre bases locales ni replicación entre servidores. Los clientes consultan el inventario remoto; la lista se actualiza periódicamente. Las fotos se guardan junto con el producto.

El uso de HTTP en la Wi-Fi fue autorizado para este proyecto universitario. Las credenciales y los datos viajan sin cifrar en esa red. La aplicación limita HTTP a hosts locales y direcciones privadas válidas. Detalles en `docs/red-local-http.md`.

## iOS

El código incluye SQLite, selección de fotos y configuración de red local para iOS. Para compilar y ejecutar en un iPhone necesitas un Mac con Xcode, Flutter y la firma correspondiente. En el Mac abre esta carpeta, ejecuta `flutter pub get`, selecciona el dispositivo iOS y ejecuta `flutter run`. Windows permite verificar el código y compilar web, pero no generar el binario iOS.

La base de datos está en versión 9 y conserva usuarios y productos existentes mediante migraciones. La implementación incluye registro de cuentas, sesiones, permisos, fotos y servidor local. Las compilaciones nativas Android/iOS necesitan validación en sus respectivos dispositivos.


La ficha automotriz y el diseño de las bases se describen en [docs/base-datos-automotriz.md](docs/base-datos-automotriz.md). Incluye marca, tipo, referencias OEM, calibre, compatibilidad y especificaciones de lubricantes.



El código de conexión aparece dentro de Compartir inventario, con botones para copiarlo; conserva el identificador del negocio al reiniciar el servidor. No reemplaza el usuario y la contraseña ni concede privilegios de Administrador. Las fichas ahora son distintas para Lubricante, Repuesto, Filtro, Aditivo y Accesorio; solo se guardan los campos que aplican a la categoría seleccionada.


### Cargar fotografías de productos

Selecciona una fotografía de hasta 20 MB. StockGo consulta sus dimensiones y la reduce a un máximo de 1200 píxeles, conservando la proporción, antes de generar la vista previa. Guarda la imagen procesada junto con el producto (máximo 5 MB). Durante el procesamiento muestra un indicador; si falla o supera 20 segundos, permite volver a intentarlo sin perder los campos del formulario.

Después de actualizar este código, detén la ejecución en VS Code y vuelve a iniciar con F5 para cargar la nueva implementación del selector de imágenes.


El flujo actualizado para vendedores está en [docs/conexion-negocios.md](docs/conexion-negocios.md). Las opciones y campos manuales se explican en [docs/campos-seleccion-automotriz.md](docs/campos-seleccion-automotriz.md).



### Android en la PC, sin teléfono físico

Para alojar el servidor en escritorio y activarlo desde el navegador de Windows, consulta [Windows, navegador y equipo](docs/windows-navegador-equipo.md). Incluye el ejecutable, el panel local, la lista de vendedores y las invitaciones por negocio.

En Android Studio abre SDK Manager → SDK Tools e instala Android Emulator en el SDK C:/Android/sdk. En Device Manager crea un dispositivo virtual, descarga una imagen Android x86_64 y enciéndelo. En VS Code usa Flutter: Select Device, elige el emulador y pulsa F5 con StockGo - dispositivo Android o iOS seleccionado. Flutter instala la versión de desarrollo automáticamente en el emulador; no necesitas copiar un APK manualmente.

El inventario del emulador es independiente del navegador. Para probar que otro teléfono se conecte al servidor del emulador hay que configurar redirección de puertos de su red virtual; para compartir directamente en Wi-Fi utiliza un teléfono físico o la aplicación nativa Windows.

El flujo del negocio, permisos, ventas, precios y lotes se describe en [docs/flujo-ventas.md](docs/flujo-ventas.md).
