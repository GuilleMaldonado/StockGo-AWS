# Diseño compartido de StockGo

El tema de `lib/theme/stockgo_theme.dart` y los componentes de `lib/widgets/stockgo_design.dart` se utilizan en Android, iOS, Windows, macOS, Linux y web. No requieren imágenes descargadas ni servicios externos.

- Azul marino para títulos, turquesa para acciones principales, azul y verde para distinguir módulos y tonos cálidos para alertas.
- Tarjetas con bordes suaves, sombras ligeras e iconos dentro de contenedores con degradado.
- Inicio con resumen compacto y módulos en una, dos o tres columnas según el espacio disponible; ancho máximo de 1160 píxeles.
- Campos, botones, chips, diálogos e indicadores mantienen el mismo estilo en todas las pantallas.
- Respuesta visual al pasar el cursor, enfocar con teclado o pulsar. Las animaciones respetan la opción de reducir movimiento.
- En teléfonos estrechos, las opciones de registro se colocan en vertical para evitar recortes.

Las pruebas de widgets comprueban la navegación con temas Android, iOS, macOS y Windows, tamaños de móvil y escritorio, y texto ampliado. Las capturas de revisión se generan en `build/previews/` con `--dart-define=CAPTURAR_UI=true`. Estas pruebas no sustituyen una compilación nativa en Apple: iOS y macOS deben compilarse y probarse con Flutter y Xcode en una Mac.

## Navegación y nueva identidad visual
Menú de módulos en la esquina superior izquierda: Inicio, Inventario/Stock, Ventas, Equipo y Conexión. Las opciones dependen del rol. Tarjetas centradas, iconos Material redondeados en degradados, azul real, turquesa, verde y acentos amarillos. Login con relieve e ilustración vectorial original de cajas y lubricante, sin descargas de imágenes ni dependencias externas.

Referencias de organización visual: https://www.zoho.com/inventory/help/getting-started/dashboard.html y https://www.zoho.com/us/inventory/mobile-apps/. Iconos integrados de Material: https://developers.google.com/fonts/docs/material_icons. La ilustración de StockGo es propia.

## Actualización celeste 1.1.1
Referencia proporcionada por el usuario: catálogo móvil con imágenes grandes y login blanco con bandas azules curvas. La implementación de StockGo utiliza celeste, azul petróleo para contraste y verde para disponibilidad; mantiene la identidad de un negocio automotriz.

Catálogo con cuadrícula adaptable de 1/2/3/4 columnas, fotos del negocio, ilustraciones de categoría cuando falta una foto, filtros Lubricantes/Repuestos/Filtros/Aditivos/Accesorios, precio y stock visibles. No se añaden productos ficticios a las bases reales. Navegación inferior por rol en pantallas móviles, menú superior en todos los tamaños. El punto de venta bloquea la navegación mientras guarda o procesa una operación. Login con campos de tipo cápsula y decoración vectorial original inspirada en la referencia. Icono Android propio, adaptable desde API 26 y versión vectorial para API 24–25.
