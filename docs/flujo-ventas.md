# Flujo de StockGo

1. El propietario crea un negocio y su cuenta de administrador. Selecciona el negocio al iniciar sesión.
2. Registra los productos con sus precios de compra y venta, unidad, cantidad y ficha específica de la categoría.
3. En **Vendedores y equipo**, crea las cuentas de quienes trabajarán en ese negocio.
4. En el dispositivo maestro, abre **Compartir inventario → Iniciar servidor**. El maestro puede ser Android, iOS o Windows; el navegador accede al servidor de Windows mediante el panel local.
5. Regresa a **Vendedores y equipo → Invitar vendedor** y comparte el código completo SG1-. No compartas la contraseña del administrador.
6. El vendedor abre **Conectarme a un negocio**, introduce código, usuario y contraseña y entra al inventario del maestro.
7. Administradores y vendedores usan **Ventas**, agregan productos, revisan cantidades y total y confirman. El invitado solo consulta.

El vendedor también puede conectarse para crear una cuenta en ese negocio. Compartir el código no concede permisos de administrador.

El registro exige nombres y apellidos sin números y genera un código interno para identificar al vendedor. Las cuentas anteriores conservan sus credenciales y completan sus datos personales antes de vender. Cada venta guarda el nombre completo y el código del responsable.

Desde el inventario, el vendedor puede abrir **Nueva venta** o seleccionar un artículo y tocar **Vender**. Una cuenta admite varios productos. En **Cantidad**, elige unidades o **Todo el lote**, que utiliza todas las existencias del código seleccionado; el servidor vuelve a comprobar el stock al confirmar.

La ficha de producto comienza con la categoría y organiza los campos en datos, precios y stock, ficha técnica e imagen opcional. Los accesos superiores permiten cambiar de sección y el botón de guardar permanece visible.

## Precios y existencias

- Precio de venta mayor o igual al de compra, ambos por la misma unidad y hasta dos decimales.
- Los importes del historial se guardan en centavos enteros. El servidor calcula el total con los precios vigentes; el cliente no puede imponer otro precio.
- Si el precio cambia después de armar la venta, se rechaza la confirmación y debe revisarse el carrito.
- Las cantidades son enteras de la unidad registrada. Por ejemplo, una caja de 12 se registra como una caja con su precio por caja; esta versión no maneja fracciones de litros.
- No se venden productos desactivados, agotados, vencidos o con stock insuficiente.
- Toda la venta y el descuento de existencias se guardan en una transacción: si falla una línea, no se guarda ni descuenta ninguna.
- Reintentar la misma solicitud confirmada devuelve la venta original, sin descontar stock dos veces.
- El administrador ve las últimas 100 ventas del negocio; el vendedor ve sus últimas 100 ventas. Las anteriores permanecen en la base.

## Lotes del fabricante

Cada código de inventario representa un lote. Si llega el mismo artículo en dos lotes distintos, registra códigos distintos, por ejemplo `ACE-5W30-L001` y `ACE-5W30-L002`, conservando la misma marca y referencia de fabricante.

Los lubricantes y aditivos requieren lote. Los repuestos permiten registrar el lote si el fabricante lo proporciona. Vencimiento es opcional, pero cuando se indica debe ser una fecha válida `AAAA-MM-DD`. No se puede cambiar el lote o su vencimiento mientras queden existencias de un lote ya identificado: esto evita reclasificar mercancía vieja como nueva. Para registros anteriores sin lote, se permite completar su identificación.

La venta conserva código, nombre, lote, vencimiento, cantidad, unidad, precio, costo y vendedor originales aunque después se edite o desactive el producto. Esta versión aún no agrupa varios lotes bajo un único SKU ni genera facturas fiscales.

## Apariencia

Azul y turquesa para navegación y acciones principales; verde para confirmar ventas; amarillo para destacar el acceso a ventas; gris y negro para texto y superficies. Fondo con textura vectorial ligera, transiciones de entrada y total animado, respetando la configuración de movimiento reducido.

## Base de datos

La versión 8 agregó `ventas` y `venta_detalles`; la migración a versión 9 agrega nombres, apellidos, códigos internos y el código del vendedor en cada venta. Conserva usuarios, productos, imágenes, negocios e historial. Las ventas anteriores mantienen el responsable registrado originalmente. Cada negocio mantiene sus datos en su propia base local; las operaciones remotas se ejecutan sobre la base del maestro.
