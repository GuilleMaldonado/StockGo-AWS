# StockGo en Windows, navegador y equipo

La aplicación Windows guarda el inventario en SQLite y aloja el servidor del negocio. Mantenerla abierta permite administrarlo también desde el navegador de esa PC. El navegador usa la aplicación local; no abre sockets por sí mismo.

## Compilar y abrir

Instala Visual Studio Build Tools con Desarrollo para escritorio con C++, MSVC, CMake y Windows SDK. Desde la carpeta del proyecto:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\compilar_windows.ps1
```

El script compila web y Windows, incluye los archivos web junto al ejecutable y crea el acceso directo **StockGo proyecto**. Conserva toda la carpeta `build/windows/x64/runner/Release`: el ejecutable necesita los archivos vecinos.

1. Abre StockGo para Windows desde el acceso directo.
2. Crea o selecciona el negocio en Windows. La cuenta propietaria es su administrador.
3. Usa **Compartir inventario → Iniciar servidor** en escritorio, o abre `http://127.0.0.1:8079/` en el navegador.
4. En el navegador elige **Activar servidor de esta PC**, selecciona el negocio de Windows e ingresa sus credenciales de administrador. El servidor se activa y el navegador inicia sesión en ese negocio.

La base local del navegador y la del emulador son independientes. Este flujo no las importa ni las fusiona. Si Windows tiene otro negocio con una sesión abierta, cierra esa sesión antes de cambiar de negocio desde el navegador.

Para desarrollar se conserva **StockGo - Windows (servidor desde la app)** en VS Code. La versión web de desarrollo puede iniciarse en `http://localhost:8080/` y usa el mismo panel local.

## Puertos y permisos

- **8079**, únicamente `127.0.0.1`: interfaz web y puente de control de la aplicación Windows. Solo admite solicitudes de control desde localhost/127.0.0.1 en 8080 o desde su propio origen. Activar el servidor exige contraseña válida y rol administrador del negocio seleccionado.
- **8081**, servidor LAN del inventario: los clientes necesitan el código del negocio y su sesión. Los vendedores e invitados consultan; las modificaciones requieren administrador.
- Para conectar teléfonos reales, elige el código que contiene la IP de la Wi-Fi. Windows puede pedir permiso de firewall para StockGo: permite la red privada para esa prueba. El código con 127.0.0.1 sirve únicamente en la PC que aloja el servidor.
- Mantén StockGo para Windows abierto. Cerrar la aplicación detiene el servidor y el puente. Cerrar sesión detiene el servidor del inventario.

## Vendedores e invitaciones

El administrador abre **Vendedores y equipo**. La pantalla muestra el negocio, el total de vendedores registrados, los administradores, sus usuarios y roles. Puede buscar y actualizar la lista o crear una cuenta del equipo.

**Invitar vendedor** copia el código y las instrucciones para compartirlas manualmente. El destinatario entra en **Conectarme a un negocio**, pega el código y usa una cuenta del negocio o crea una cuenta de vendedor en ese servidor. El código no concede permisos de administrador. La aplicación no envía mensajes automáticamente ni muestra contraseñas o hashes.

La pertenencia se obtiene de la base del negocio: no se buscan cuentas de otras empresas y los invitados sin cuenta no aumentan el contador de vendedores.
