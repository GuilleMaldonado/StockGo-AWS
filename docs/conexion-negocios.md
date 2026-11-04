# Conectar vendedores a su negocio

1. El propietario crea su negocio en el teléfono maestro (Android/iOS) o en la app nativa de PC e inicia sesión como Administrador.
2. Abre Compartir inventario, inicia el servidor y pulsa Copiar código para el vendedor. El código completo empieza con `SG1-`.
3. En otro dispositivo, el vendedor abre Soy vendedor · Conectarme a un negocio, pega el código, ingresa su usuario y contraseña y pulsa Conectar e iniciar sesión. StockGo resuelve la dirección incluida en el código y valida la cuenta en ese negocio en un solo paso.
4. Si todavía no tiene cuenta, usa Conectar para crear cuenta o entrar como invitado y después Crear cuenta: se registra como Vendedor en esa empresa. El registro público de vendedor desde modo local también exige el código del negocio maestro.

Una contraseña o un código incorrectos mantienen abierto el formulario para corregirlos y no sustituyen la conexión anterior. El código no reemplaza la contraseña ni concede permisos de administrador.

El código contiene la dirección de red actual y un identificador aleatorio de 128 bits persistido en la base de ese negocio. El servidor compara ese identificador en la conexión y en todas las solicitudes; un código de otra empresa es rechazado aunque sus usuarios se llamen igual. No se concede el rol Administrador al compartir el código. Cada empresa tiene su propia base y sesiones independientes.

No hace falta escribir la dirección aparte. No hay servidor central ni búsqueda mundial por número corto. En la misma Wi-Fi, el código lleva la dirección necesaria para encontrar al maestro y funciona también en el cliente web. Si el router cambia la IP del maestro, vuelve a copiar el código desde la pantalla; el identificador de empresa permanece igual. Una copia completa de la base representa el mismo negocio, no uno nuevo.

Mantén la aplicación maestro abierta. El navegador es cliente y no puede alojar el servidor. Las compilaciones móviles requieren pruebas en dispositivos reales; iOS se compila en Mac con Xcode.
