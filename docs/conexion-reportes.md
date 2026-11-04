# Conexión y reportes — StockGo 1.1.2

El identificador del negocio es persistente. El código SG1 contiene ese identificador y la dirección del dispositivo maestro. La terminación .2 de 192.168.0.2 es parte de su IP, no un cambio del identificador ni el número de vendedores.

En Compartir inventario, el administrador inicia el servidor y elige la red para conectar a los vendedores. Se priorizan interfaces físicas frente a VirtualBox/Hyper-V/VPN y se muestra un solo código de la red seleccionada. Elegir la IP de la misma Wi-Fi; no se puede inferir siempre cuál es correcta cuando existen varias interfaces físicas. Si cambia la IP del maestro, reiniciar el servidor y compartir el nuevo código. Mantenerlo abierto y permitir StockGo en la red privada de Windows.

Desde Inicio o el menú Módulos se abre Historial y estadísticas. El administrador ve las ventas de su negocio; cada vendedor solo las propias, con restricción aplicada también en la base de datos/API. Invitados no tienen acceso. Filtros: hoy, últimos 7/30 días o todo el historial, y vendedor para administradores. Actualizar para obtener ventas nuevas.

Cada venta muestra nombre completo/código interno del vendedor, fecha, productos, cantidades, lote, precios históricos y total. Métricas: importe vendido, número de ventas, unidades, ticket promedio, margen bruto para administradores, ranking de productos y rendimiento de vendedores con ventas en el período. No son métricas de horas trabajadas: no se registra asistencia. Unidades no equivalen a litros ni cajas. El margen bruto utiliza costos históricos y no descuenta impuestos ni gastos; se indica cuando faltan costos antiguos. No se limita el historial a las últimas 100 ventas.

Validación: pruebas de agregación, historial superior a 100 ventas, pantalla móvil/detalle/permisos, conexión a negocios separados y persistencia del código. La conexión PC/teléfono en la Wi-Fi real requiere probarse en los dispositivos del usuario.