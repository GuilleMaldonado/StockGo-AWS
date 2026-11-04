# Mantenimiento remoto gratuito para la presentación

## Qué incorpora StockGo 1.2.0

- Restablecimiento desde **Vendedores y equipo → icono de llave**. Requiere una cuenta Administrador del negocio y confirmar su contraseña actual. No se utiliza el correo como llave maestra ni hay cuentas ocultas de soporte.
- La aplicación genera una clave temporal aleatoria, válida durante 30 minutos. No guarda la clave en texto ni la escribe en la auditoría. Hay que entregarla en privado después de comprobar la identidad del destinatario.
- Al iniciar sesión con esa clave, es obligatorio elegir una contraseña propia antes de consultar productos o vender. Después del cambio, la temporal y las sesiones anteriores dejan de tener acceso.
- **Inicio → icono de contraseña** permite cambiar la contraseña propia. El invitado no tiene cuenta con contraseña.
- **Equipo → Historial de seguridad** muestra los últimos 200 eventos con responsable, cuenta afectada y fecha. La tabla SQLite conserva todos los eventos. No incluye contraseñas ni claves temporales.
- La API elimina costo y proveedor de los productos enviados a vendedores e invitados, y costoCentavos de los detalles de venta enviados a vendedores.
- Se limitan a 10 solicitudes por minuto, dirección de origen y ruta los puntos de conexión, login, registro, configuración, cambio y restablecimiento. El límite está en memoria y se reinicia al detener el servidor; no es una solución completa contra denegación de servicio.
- Migración SQLite de versión 9 a 10, sin borrar usuarios, productos ni ventas. La versión de credencial permite rechazar también sesiones locales anteriores tras un cambio.

## Preparar acceso desde tu PC

1. Instalar StockGo actualizado en tu PC y en el dispositivo que guarda el negocio. Si el maestro es una PC del negocio, instalarlo allí. Actualizar maestro y clientes juntos; los antiguos no incluyen el cambio obligatorio de contraseña ni los códigos VPN.
2. Para esta demostración universitaria no comercial, instalar Tailscale desde https://tailscale.com/download en ambos dispositivos. Crear la red privada y autorizar los dispositivos. Usar invitaciones y políticas de acceso; no compartir una contraseña personal entre varias personas.
3. Tailscale ofrece un plan Personal gratuito para uso no comercial, de hasta seis usuarios según la tarifa consultada. No equivale a alojamiento gratis para empresas en producción. Condiciones: https://tailscale.com/pricing.
4. Dejar Tailscale conectado. En el maestro, iniciar StockGo como administrador y abrir **Compartir inventario → Iniciar servidor**.
5. Elegir la dirección **VPN** en el selector. Las direcciones Tailscale IPv4 pertenecen al rango 100.64.0.0/10. Si no aparece, comprobar la instalación y conexión del túnel; detener y volver a iniciar el servidor para actualizar las interfaces.
6. Copiar el código SG1 de esa dirección. Lleva una marca VPN explícita: los códigos Wi-Fi anteriores siguen funcionando y no permiten automáticamente direcciones nuevas. El cliente continúa rechazando HTTP hacia direcciones públicas fuera de los rangos admitidos.
7. En tu PC abrir **Conectarme a un negocio**, pegar el código y acceder con una cuenta Administrador que ese negocio haya autorizado para soporte. La conexión privada no concede permisos por sí sola.
8. Buscar la cuenta en Equipo, verificar su identidad, pulsar la llave y confirmar tu contraseña de administrador. Entregar la temporal en privado. El usuario ingresa con su nombre de usuario existente y completa el cambio obligatorio.
9. Revisar el Historial de seguridad. Al terminar, cerrar sesión y retirar el acceso VPN de soporte si era temporal.

La misma conexión puede utilizarse desde Android, iOS o Windows que tengan el túnel configurado. El maestro debe estar encendido y StockGo debe seguir abierto; en teléfono no se implementa alojamiento permanente en segundo plano. Tener Internet no inicia automáticamente el servidor. En Windows, el firewall debe permitir StockGo en la interfaz/red privada correspondiente, sin abrir el puerto 8081 públicamente en el router.

## Alcance del cifrado

StockGo no instala Tailscale, no inicia sesión en él ni comprueba sus claves. La dirección y la marca VPN identifican el modo de conexión, pero no demuestran que el túnel esté activo. El tráfico entre dispositivos queda protegido cuando se utiliza realmente el túnel cifrado de Tailscale. No se debe exponer el servicio HTTP directamente a Internet.

La base permanece en el maestro: Tailscale retransmite conexiones y no aloja el inventario. No permite recuperar una cuenta si el maestro está apagado. No se ha agregado HTTPS nativo al servidor, cifrado SQLite, sincronización en nube ni recuperación automática por correo. La conexión Wi-Fi HTTP existente conserva sus condiciones anteriores. Arquitectura del túnel: https://tailscale.com/docs/reference/connection-types.

## Evitar quedarse sin administrador

Preparar antes de la presentación una cuenta administrativa de soporte autorizada por el propietario. Si se olvida la única contraseña administrativa y no hay otra cuenta autorizada, este módulo no permite saltarse el acceso: requiere un procedimiento presencial y una copia consistente de la base. El código SG1 no permite restablecer cuentas por sí solo.

El registro de vendedores por código conserva el comportamiento anterior: todavía no hay una bandeja de aprobación de cuentas nuevas. El instalador Windows sigue sin certificado de editor y una firma APK válida no elimina automáticamente avisos de Play Protect.

## Validar

```powershell
& C:/src/flutter/bin/flutter.bat analyze
& C:/src/flutter/bin/flutter.bat test test/mantenimiento_remoto_test.dart --concurrency=1
```

Las pruebas automatizadas de red utilizan un servidor de prueba local, no una red Tailscale real. La demostración a distancia requiere autorizar físicamente ambos dispositivos y probar el túnel con conexiones de Internet diferentes.

## Compilar

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\crear_instaladores.ps1
```

El resultado Android es `dist/StockGo-1.2.0-Android.apk`; el instalador es `dist/StockGo-Instalador-Windows.exe`. Conservar la firma Android original y respaldar los datos antes de actualizar.
