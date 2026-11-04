# Base de datos para aceitería y repuestos

SQLite versión 9. Las migraciones agregan columnas, catálogos y tablas de ventas conservando los usuarios, productos y fotos existentes. No se usa Firebase ni se borra la base para actualizarla. Consulta también [Flujo y ventas](flujo-ventas.md).

## Negocios y separación de datos

La base principal contiene `negocios`: id, nombre, nombreNormalizado (UNIQUE) y ruta. El nombre se compara en minúsculas, quitando espacios externos y agrupando espacios internos. Cada negocio dispone de un archivo SQLite independiente con usuarios, productos y configuración. Un usuario del negocio A no autentica en el negocio B; un código de producto puede existir en ambos negocios. Selecciona el negocio en Login antes de iniciar sesión. Los datos anteriores siguen disponibles en **Inventario local anterior**.

Crear una empresa registra a su propietario como Administrador. Los vendedores e invitados no pueden alojar el inventario. Compartir exige una sesión local de Administrador y un negocio configurado; cambiar de negocio exige cerrar sesión. El servidor comparte únicamente la base del negocio seleccionado. Las direcciones aparecen en la pantalla, sin un procedimiento de terminal.

Los nombres son únicos en el catálogo del dispositivo que aloja los negocios. No existe un registro global entre PC y teléfonos independientes. Se puede compartir un negocio a la vez por instancia de StockGo (puerto 8081).

## Productos

| Grupo | Columnas |
| --- | --- |
| Identificación | id, nombre, codigo único, categoria, marca, tipo, descripcion |
| Referencias | numeroParte, referenciaOEM, codigoBarras |
| Venta e inventario | precio, costo, cantidad, stockMinimo, unidadVenta, presentacion, ubicacion, proveedor |
| Trazabilidad | lote, vencimiento, activo, imagen |
| Lubricantes | viscosidadSAE, baseAceite, normaAPI, normaACEA (ACEA/ILSAC), homologaciones, aplicacion |
| Repuestos | calibre, dimensiones, material, posicion, compatibilidad |

Son columnas SQLite explícitas, no un único texto JSON. Hay índices por marca, número de parte, categoría y estado; el código permanece reservado cuando se desactiva un producto. Precio/costo son REAL no negativos, existencias y stock mínimo INTEGER no negativos, activo tiene valores 0/1 e imagen es BLOB. La API transmite la misma ficha a los clientes conectados. La búsqueda incluye nombre, código, marca, número de parte, OEM y compatibilidad.

El formulario exige marca, tipo y unidad de venta; para Lubricante exige viscosidad. Los campos técnicos se muestran según categoría. Los registros anteriores conservan los campos nuevos vacíos para que el administrador los complete. Se valida costo, stock mínimo, tamaños de textos y vencimiento con fecha AAAA-MM-DD real. Los datos técnicos deben transcribirse de etiqueta/ficha del fabricante: la app no certifica homologaciones ni decide automáticamente si una pieza o aceite es adecuado para un vehículo.

Compatibilidad admite una aplicación por línea con marca, modelo, rango de años, motor y combustible. Es una declaración manual, no un catálogo de vehículos integrado. Lote y vencimiento corresponden a un lote por registro; todavía no hay tablas de recepciones, múltiples lotes por SKU, proveedores normalizados ni movimientos de venta.

## Investigación utilizada

- [API Motor Oil Guide](https://www.api.org/products-and-services/engine-oil/documents/motor-oil-guide): viscosidad SAE, categorías de servicio API y marcas de calidad del aceite.
- [API Engine Oil Licensing](https://www.api.org/products-and-services/engine-oil): especificaciones y clasificación SAE J300 para aceites de motor.
- [TecAlliance](https://www.tecalliance.net/products): números de artículo y referencia, GTIN, atributos, presentación y enlaces a vehículos.
- [Formato TecDoc](https://dwnld.aws.tecalliance.com/TecDoc/Downloads/TecDoc-Data-Format.pdf): referencias de artículos y criterios de aplicación por vehículo/motor.

El calibre se usa para medidas de repuestos. Para aceite se registra la viscosidad SAE; no se confunden ambos campos.

## Conexión y fichas por categoría

Compartir inventario muestra el identificador persistente del negocio y permite copiar un código completo SG1- con la dirección del maestro. El vendedor pega ese código en Login. El servidor verifica la identidad de la empresa antes de permitir login, registro, invitado y consultas. Los roles se obtienen de la cuenta autenticada. Cerrar sesión del administrador local detiene el servicio. Consulta docs/conexion-negocios.md.

Cada categoría dispone de una selección distinta de columnas en el formulario y el detalle:

- Lubricante: viscosidad SAE, base, API, ACEA/ILSAC, homologaciones y aplicación.
- Repuesto: número de parte, OEM, calibre, dimensiones, material, posición y compatibilidad.
- Filtro: número de parte, OEM, dimensiones, compatibilidad, gradoFiltracion y valvulaBypass.
- Aditivo: dosificacion, fluidoCompatible y aplicación. No solicita viscosidad SAE.
- Accesorio: número de parte, dimensiones, material, compatibilidad, voltaje y potencia.

Al cambiar de categoría, el formulario conserva el borrador mientras se edita; al guardar escribe únicamente los campos aplicables y limpia los que pertenecían a otra categoría. Los campos comerciales y de logística son comunes. Las nuevas columnas se agregan con la migración a versión 7.

