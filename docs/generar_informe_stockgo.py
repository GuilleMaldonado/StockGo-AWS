from pathlib import Path
import re
from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_CELL_VERTICAL_ALIGNMENT
from docx.oxml import OxmlElement
from docx.oxml.ns import qn

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs' / 'StockGo_Informe_tecnico_APA.docx'
d = Document()
s = d.sections[0]
s.page_width, s.page_height = Inches(8.5), Inches(11)
s.top_margin = s.bottom_margin = s.left_margin = s.right_margin = Inches(1)
s.header_distance = Inches(.5)
normal = d.styles['Normal']
normal.font.name = 'Times New Roman'
normal.font.size = Pt(12)
normal.font.color.rgb = RGBColor(0, 0, 0)
normal.paragraph_format.line_spacing = 2
normal.paragraph_format.space_before = Pt(0)
normal.paragraph_format.space_after = Pt(0)
normal.paragraph_format.first_line_indent = Inches(.5)
normal.paragraph_format.widow_control = True
for name in ['Title', 'Subtitle', 'Heading 1', 'Heading 2', 'Heading 3']:
    st = d.styles[name]
    st.font.name = 'Times New Roman'
    st.font.size = Pt(12)
    st.font.color.rgb = RGBColor(0, 0, 0)
    st.font.bold = name != 'Subtitle'
    st.paragraph_format.line_spacing = 2
    st.paragraph_format.first_line_indent = Inches(0)
    st.paragraph_format.space_before = Pt(0)
    st.paragraph_format.space_after = Pt(0)
    st.paragraph_format.keep_with_next = True
    st.paragraph_format.alignment = WD_ALIGN_PARAGRAPH.CENTER if name in ['Title', 'Heading 1'] else WD_ALIGN_PARAGRAPH.LEFT
# La plantilla de Word incorpora fuentes de tema y una línea azul en Title.
# Eliminar esas herencias para mantener tipografía y presentación APA.
for st in d.styles:
    for border in list(st.element.iter(qn('w:pBdr'))):
        border.getparent().remove(border)
for name in ['Normal', 'Title', 'Subtitle', 'Heading 1', 'Heading 2', 'Heading 3']:
    rp = d.styles[name].element.get_or_add_rPr()
    fonts = rp.find(qn('w:rFonts'))
    if fonts is not None:
        for attr in list(fonts.attrib):
            if 'theme' in attr.lower(): del fonts.attrib[attr]
        for attr in ['ascii', 'hAnsi', 'eastAsia', 'cs']:
            fonts.set(qn('w:'+attr), 'Times New Roman')
header = s.header.paragraphs[0]
header.alignment = WD_ALIGN_PARAGRAPH.RIGHT
header.paragraph_format.first_line_indent = Inches(0)
field = OxmlElement('w:fldSimple'); field.set(qn('w:instr'), 'PAGE')
header._p.append(field)
lang = OxmlElement('w:lang'); lang.set(qn('w:val'), 'es-GT')
normal.element.get_or_add_rPr().append(lang)
d.core_properties.title = 'Informe técnico de StockGo y guía de compilación'
d.core_properties.subject = 'Inventario y ventas de lubricantes y repuestos automotrices'
d.core_properties.author = ''
d.core_properties.keywords = 'StockGo, Flutter, SQLite, inventario, ventas, APK, Windows, APA'

def p(text, indent=True):
    x = d.add_paragraph(text)
    if not indent: x.paragraph_format.first_line_indent = Inches(0)
    return x

def h(text, level=1):
    return d.add_paragraph(text, f'Heading {level}')

def code(text):
    x = d.add_paragraph()
    x.paragraph_format.first_line_indent = Inches(0)
    x.paragraph_format.line_spacing = 1
    x.paragraph_format.space_before = Pt(6)
    x.paragraph_format.space_after = Pt(6)
    x.paragraph_format.keep_together = True
    for i, line in enumerate(text.split('\n')):
        if i: x.add_run().add_break()
        r = x.add_run(line); r.font.name = 'Consolas'; r.font.size = Pt(9)
    return x

number_table = 0
def table(title, headers, rows, widths=None):
    global number_table
    number_table += 1
    cap = p('', False); cap.paragraph_format.keep_with_next = True
    cap.add_run(f'Tabla {number_table}').bold = True
    title_p = p('', False); title_p.paragraph_format.keep_with_next = True
    title_p.add_run(title).italic = True
    t = d.add_table(rows=1, cols=len(headers)); t.alignment = WD_TABLE_ALIGNMENT.CENTER
    t.autofit = False
    if widths:
        for c, w in zip(t.columns, widths): c.width = Inches(w)
    props = t._tbl.tblPr
    borders = OxmlElement('w:tblBorders')
    for side in ['top','left','bottom','right','insideH','insideV']:
        el = OxmlElement('w:' + side)
        for key, value in [('val','single'),('sz','4'),('color','D9D9D9')]: el.set(qn('w:'+key),value)
        borders.append(el)
    props.append(borders)
    for idx, record in enumerate([headers] + list(rows)):
        cells = t.rows[0].cells if idx == 0 else t.add_row().cells
        if idx == 0:
            repeat = OxmlElement('w:tblHeader'); t.rows[0]._tr.get_or_add_trPr().append(repeat)
        for j, (cell, value) in enumerate(zip(cells, record)):
            if widths: cell.width = Inches(widths[j])
            cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
            tcpr = cell._tc.get_or_add_tcPr()
            margins = OxmlElement('w:tcMar')
            for side in ['top','left','bottom','right']:
                el = OxmlElement('w:'+side); el.set(qn('w:w'),'90'); el.set(qn('w:type'),'dxa'); margins.append(el)
            tcpr.append(margins)
            if idx == 0:
                sh = OxmlElement('w:shd'); sh.set(qn('w:fill'),'F2F2F2'); tcpr.append(sh)
            cp = cell.paragraphs[0]
            cp.paragraph_format.first_line_indent = Inches(0)
            cp.paragraph_format.line_spacing = 1.1
            cp.paragraph_format.space_after = Pt(2)
            cp.paragraph_format.keep_with_next = idx == 0
            run = cp.add_run(str(value)); run.font.name = 'Times New Roman'; run.font.size = Pt(10)
            run.bold = idx == 0
        no_split = OxmlElement('w:cantSplit'); t.rows[idx]._tr.get_or_add_trPr().append(no_split)
    gap = p('', False); gap.paragraph_format.line_spacing = 1; gap.paragraph_format.space_after = Pt(4)
    return t

# Portada académica con campos editables y sin atribuciones inventadas.
for _ in range(3): p('', False)
d.add_paragraph('Informe técnico de StockGo y guía de compilación', 'Title')
for text in ['Sistema de inventario y ventas para aceiterías y repuestos automotrices', '',
             '[Nombre completo del estudiante]', '[Nombre de la universidad]',
             '[Carrera y asignatura]', '[Nombre del docente]', '23 de octubre de 2026']:
    x = p(text, False); x.alignment = WD_ALIGN_PARAGRAPH.CENTER
d.add_page_break()

h('Resumen')
x = p('StockGo es una aplicación de inventario y ventas orientada a pequeños negocios de lubricantes y repuestos automotrices. Su implementación actual utiliza Flutter y Dart para la interfaz, SQLite para la persistencia y un servidor HTTP local para compartir el negocio desde un dispositivo maestro. El sistema diferencia los permisos del administrador, vendedor e invitado; permite registrar productos con imágenes y fichas técnicas por categoría; conserva las ventas con la identidad de su responsable; y presenta indicadores comerciales. Este informe describe la versión 1.1.2+4, su organización de archivos, modelo de datos, validaciones, flujo de trabajo y procedimientos de ejecución y distribución. Incluye instrucciones reproducibles para generar la APK Android y el instalador ejecutable de Windows mediante los scripts del proyecto. El diseño permite operar sin Firebase ni un servidor público, siempre que los clientes compartidos alcancen al maestro en la red local. Las pruebas automatizadas aportan evidencia sobre las reglas implementadas, pero no sustituyen las pruebas de instalación, conectividad y funcionamiento en dispositivos reales. La firma digital de la APK identifica las actualizaciones; no representa una aprobación de Google Play Protect.', False)
p('Palabras clave: inventario, ventas, Flutter, SQLite, red local, compilación.', False)
h('Introducción')
p('Un negocio automotriz necesita distinguir productos semejantes por marca, presentación, referencia, viscosidad o compatibilidad. También requiere conocer las existencias disponibles y reconocer quién realizó cada venta. Un inventario con solo nombre y precio resulta insuficiente cuando se manejan lubricantes, filtros, aditivos y piezas con diferentes aplicaciones o lotes del fabricante.')
p('StockGo integra estas tareas en una aplicación con acceso por roles y un flujo de negocio compartido. La base funcional actual se encuentra en archivos Dart; las carpetas Android, iOS, Windows, macOS y Linux actúan como proyectos anfitriones de Flutter. La implementación vigente no utiliza entidades Room, DAO de Kotlin ni Firebase. La descripción técnica y los procedimientos de este documento corresponden al código fuente y a los scripts de la versión 1.1.2+4 (StockGo, 2026).')
p('La presentación académica utiliza los criterios de APA para portada, jerarquía de títulos, márgenes, citas y referencias (American Psychological Association, s. f.). Las tablas y los comandos se presentan con espaciado adaptado para facilitar su lectura técnica.')

h('Objetivos del proyecto')
h('Objetivo general', 2)
p('Desarrollar un sistema multiplataforma para gestionar el inventario y las ventas de pequeños negocios de lubricantes y repuestos automotrices, con almacenamiento local, permisos por rol, trazabilidad de ventas y acceso compartido mediante una red local.')
h('Objetivos específicos', 2)
for text in [
    '1. Registrar, consultar, modificar y desactivar productos sin eliminar el historial relacionado.',
    '2. Capturar fichas técnicas diferentes para lubricantes, repuestos, filtros, aditivos y accesorios.',
    '3. Identificar a los usuarios con nombres, apellidos y un código interno, y aplicar permisos en la interfaz, el repositorio y la API.',
    '4. Compartir el inventario desde un maestro autorizado, utilizando un código que identifique el negocio y su dirección de conexión.',
    '5. Registrar ventas de varios productos con control de cantidades, lotes, precios y disponibilidad.',
    '6. Consultar el historial y calcular indicadores comerciales por período, producto y vendedor.',
    '7. Generar paquetes reproducibles para probar Android y Windows sin depender del entorno de desarrollo del usuario final.'
]: p(text, False)
h('Alcance y límites', 2)
p('La aplicación cubre gestión de cuentas, negocios, productos, imágenes, inventario, ventas y reportes. No implementa facturación fiscal certificada, cuentas por cobrar, compras completas, devoluciones, control de asistencia ni un sistema contable. La unicidad del nombre empresarial se comprueba en el catálogo del dispositivo; no existe un registro global que compare negocios creados en equipos independientes. Tampoco hay replicación automática o fusión de bases de datos entre maestros.')

h('Tecnologías y arquitectura')
p('La lógica compartida utiliza Dart y widgets de Flutter. La interfaz adopta componentes Material, una paleta celeste, tarjetas de productos, menús por módulo y navegación adaptada al ancho disponible. Las importaciones condicionales separan las implementaciones web y nativas para evitar el uso de bibliotecas de escritorio en el navegador.')
table('Tecnologías declaradas en el proyecto', ['Componente', 'Uso técnico'], [
('Flutter y Dart', 'Interfaz, navegación, validación y lógica compartida. Restricción Dart declarada: ^3.13.5.'),
('SQLite y sqflite', 'Persistencia móvil; sqflite_common_ffi para Windows y Linux; sqflite_common_ffi_web para web.'),
('cryptography', 'Derivación de contraseñas con PBKDF2 y HMAC SHA 256.'),
('http y dart io', 'Cliente HTTP y servidor local nativo, respectivamente.'),
('image_picker', 'Implementaciones Android, iOS y web para elegir fotografías.'),
('Gradle y Android SDK', 'Compilación, empaquetado y herramientas de verificación Android.'),
('Visual Studio y CMake', 'Compilación del anfitrión nativo Windows con herramientas C++.'),
('Inno Setup', 'Generación del instalador StockGo para Windows con extensión .exe.')
], [1.65, 4.85])
h('Capas de la solución', 2)
p('Presentación: lib/screens contiene las pantallas y lib/widgets los componentes reutilizables. Estado: StockGoStore conserva la sesión, el negocio seleccionado y el modo local o conectado. Datos: StockGoRepository concentra las reglas y las operaciones SQLite. Red: StockGoApi realiza solicitudes al maestro y StockGoLanServer vuelve a comprobar los permisos antes de ejecutar las acciones. Plataforma: las fábricas de base de datos, selectores de imágenes y control de Windows resuelven diferencias entre sistemas operativos.')
p('El recorrido local es pantalla, estado, repositorio y SQLite. El recorrido remoto es pantalla, estado, cliente HTTP, servidor maestro, repositorio autorizado y SQLite del maestro. Los clientes conectados consultan ese origen; no mantienen una réplica independiente sincronizada para vender sin conexión.')

h('Usuarios y flujo operativo')
table('Permisos funcionales por rol', ['Acción', 'Administrador', 'Vendedor', 'Invitado'], [
('Consultar y buscar productos activos', 'Sí', 'Sí', 'Sí'),
('Crear editar o desactivar productos', 'Sí', 'No', 'No'),
('Consultar productos desactivados', 'Sí', 'No', 'No'),
('Registrar ventas', 'Sí', 'Sí', 'No'),
('Consultar ventas y estadísticas', 'Del negocio', 'Solo propias', 'No'),
('Ver equipo y crear cuentas administrativas', 'Sí', 'No', 'No'),
('Alojar el negocio desde la aplicación nativa', 'Local y autorizado', 'No', 'No')
], [2.65, 1.35, 1.25, 1.25])
p('El propietario crea el negocio y su cuenta de administrador. Después selecciona el negocio al iniciar sesión, registra los productos y agrega las cuentas del equipo. Cada cuenta utiliza su usuario y contraseña; el vendedor posee nombres, apellidos y un código interno con prefijo VD. Un invitado puede consultar sin adquirir permisos de venta o modificación.')
p('Para compartir, el administrador abre Compartir inventario e inicia el servidor del negocio elegido. Luego copia el código para los vendedores. El vendedor abre Conectarme a un negocio, pega el código completo SG1 y accede con las credenciales de ese negocio. El código no contiene la contraseña ni concede el rol Administrador. El registro remoto disponible genera una cuenta de vendedor, no una cuenta propietaria.')
p('Al vender, se arma una cuenta con uno o varios productos, se revisa la cantidad y se confirma una sola operación. El sistema registra el responsable y reduce las existencias. El administrador revisa las ventas y los indicadores en Historial y estadísticas. Cerrar sesión limpia el acceso actual; si corresponde al administrador local que comparte el negocio, detiene también el servidor.')

h('Conexión del dispositivo maestro')
p('El maestro puede ejecutarse como aplicación nativa. Windows ofrece además un panel local para administrarlo desde el navegador. Un navegador aislado no puede iniciar por sí mismo el servidor LAN: necesita la aplicación Windows abierta o conectarse al maestro nativo de otro equipo. La operación en iOS y macOS requiere compilar y comprobar sus proyectos en un Mac.')
table('Servicios de red del proyecto', ['Puerto', 'Ámbito', 'Función'], [
('8079', '127.0.0.1 de Windows', 'Sirve el panel web local y el puente autorizado de control de la aplicación de escritorio.'),
('8081', 'Red local del maestro', 'Atiende la API de inventario, usuarios y ventas con código de negocio y sesión.'),
('8080', 'Desarrollo web', 'Origen habitual del cliente iniciado con Flutter desde VS Code; no es el servidor del inventario.')
], [.65, 1.8, 4.05])
p('CodigoNegocio representa una dirección y un identificador persistente del negocio. El texto SG1 es un JSON codificado en Base64 URL, no un cifrado. Incluye url y negocio, de modo que el cliente pueda ubicar al maestro y verificar la empresa. El identificador se genera de forma aleatoria con 128 bits y se conserva en configuración. El código cambia si cambia la dirección de red, aunque el identificador empresarial permanezca igual.')
p('Una dirección como http://192.168.0.2:8081 identifica al maestro. La terminación .2 es parte de la dirección IPv4 y no indica un segundo negocio ni un segundo vendedor. Las interfaces virtuales pueden producir otras direcciones. La pantalla permite elegir la red compartida y muestra un solo código de esa selección. Las interfaces identificadas como virtuales se ordenan después de las físicas; la elección final debe corresponder a la red alcanzable desde el teléfono.')
p('Ambos equipos deben utilizar una red que permita comunicarse entre sí. El maestro debe permanecer abierto; no hay un servicio móvil permanente en segundo plano. Una red de invitados o con aislamiento de clientes puede impedir la conexión. En Windows se permite StockGo en la red privada del firewall. Los códigos con localhost o 127.0.0.1 solo sirven en el propio equipo.')
h('Autenticación y seguridad de la conexión', 2)
p('La API utiliza el identificador del negocio en X-StockGo-Code y una sesión Bearer para operaciones autenticadas. Las sesiones remotas expiran a las ocho horas y se invalidan al cerrar sesión o detener el servidor. Los roles se obtienen del usuario autenticado, no de valores enviados libremente por el cliente.')
p('Las contraseñas se almacenan como un resultado PBKDF2 con HMAC SHA 256, 120 000 iteraciones y sal aleatoria individual. Esto protege la representación almacenada, pero no cifra el tráfico: el prototipo usa HTTP local autorizado y las credenciales viajan sin TLS dentro de esa red. El código limita HTTP a hosts locales o direcciones privadas. Para un despliegue comercial se requiere diseñar TLS, respaldo, auditoría y una revisión de seguridad adicional.')

h('Modelo de datos y persistencia')
p('El esquema SQLite está en la versión 9. Las migraciones agregan entidades y columnas sin usar una eliminación destructiva de la base. Las claves foráneas se habilitan con PRAGMA foreign_keys. El catálogo principal relaciona negocios con sus archivos independientes; la sesión debe cerrarse antes de cambiar de negocio. Una copia completa de un archivo conserva la identidad de ese negocio y no constituye por sí misma una empresa nueva.')
table('Tablas principales y relaciones', ['Tabla', 'Contenido y restricciones'], [
('negocios', 'id, nombre, nombreNormalizado único y ruta. Catálogo local de archivos empresariales.'),
('usuarios', 'id, nombre único sin distinción de mayúsculas, password_hash, salt, rol, nombres, apellidos y codigoInterno.'),
('configuracion', 'Pares clave y valor para propietario, identidad del negocio y ajustes persistentes.'),
('productos', 'Identificación, cantidades, precios, categoría, imagen y columnas comerciales y técnicas. codigo único y activo con valores 0 o 1.'),
('ventas', 'id, solicitud única, usuarioId, vendedor, codigoVendedor, fecha UTC y totalCentavos. Relación con usuarios.'),
('venta_detalles', 'Relaciones con venta y producto; copia histórica de nombre, código, lote, vencimiento, unidad, cantidad, precio y costo en centavos.')
], [1.35, 5.15])
p('Los precios y costos del catálogo se almacenan como REAL con validación de hasta dos decimales. Al vender se convierten a centavos enteros y se conservan en la cabecera y el detalle. La venta guarda los valores históricos: un cambio posterior en el producto no debe modificar el importe registrado. Hay índices para búsquedas por marca, referencia, categoría y estado, además de índices para consultar ventas y sus detalles.')
p('En Windows los datos se guardan en %LOCALAPPDATA%\\StockGo\\databases, separados de la carpeta instalada. Existe un procedimiento para trasladar datos de ubicaciones anteriores conservando el origen y sin sobrescribir un destino existente. En móvil se utiliza el espacio privado de la aplicación. En web la persistencia queda vinculada al navegador y al origen del sitio; borrar sus datos puede eliminar ese inventario local.')
p('SQLite permite agrupar los cambios en transacciones: una operación completa se confirma o se revierte, lo que resulta pertinente para no registrar una venta incompleta mientras cambia el inventario (SQLite, s. f.). El respaldo consistente debe realizarse con la aplicación cerrada o mediante una copia SQLite coherente, no copiando únicamente un archivo activo sin considerar sus archivos auxiliares.')

h('Registro de productos automotrices')
p('El catálogo diferencia identificación, datos comerciales, logística y características técnicas. Los campos comunes incluyen nombre, código interno, marca, tipo, descripción, código de barras, precio de compra, precio de venta, cantidad, stock mínimo, unidad, presentación, ubicación, proveedor, lote, vencimiento, estado e imagen. Los códigos se normalizan a mayúsculas y permanecen reservados si se desactiva el artículo.')
table('Ficha técnica según categoría', ['Categoría', 'Campos diferenciados'], [
('Lubricante', 'viscosidadSAE, baseAceite, normaAPI, normaACEA, homologaciones y aplicacion.'),
('Repuesto', 'numeroParte, referenciaOEM, calibre, dimensiones, material, posicion y compatibilidad.'),
('Filtro', 'numeroParte, referenciaOEM, dimensiones, compatibilidad, gradoFiltracion y valvulaBypass.'),
('Aditivo', 'dosificacion, fluidoCompatible y aplicacion; no exige viscosidad SAE.'),
('Accesorio', 'numeroParte, dimensiones, material, compatibilidad, voltaje y potencia.')
], [1.1, 5.4])
p('Los controles de selección se basan en opciones_ficha.dart y admiten las alternativas previstas por el formulario. Categoría, tipo, unidad de venta, base del aceite y viscosidad son ejemplos de opciones guiadas. Referencias del fabricante, lote, medidas particulares, homologaciones y aplicaciones requieren transcripción verificada. Una selección de viscosidad no determina automáticamente si el producto es compatible con un motor.')
p('La ficha de un lubricante identifica la viscosidad SAE, mientras que el calibre se utiliza para medidas de repuestos. Cada registro representa un lote del fabricante. Para conservar trazabilidad cuando llega un lote diferente se usa otro código de inventario. No existe una tabla de recepción que asigne varios lotes simultáneos al mismo SKU ni una conversión automática entre cajas, botellas y litros.')
h('Validaciones e imágenes', 2)
p('El nombre del producto admite hasta 100 caracteres y su código hasta 50. Cantidad y stock mínimo son enteros no negativos. Compra y venta deben ser finitas, no negativas y de hasta dos decimales; la venta no puede ser inferior a la compra. Para vender, el precio debe ser mayor que cero. Los lubricantes y aditivos necesitan lote; el lote admite hasta 100 caracteres sin saltos de línea. El vencimiento, si se informa, debe ser una fecha real en formato AAAA-MM-DD.')
p('Los nombres y apellidos de personas aceptan letras, espacios y separadores previstos, sin números, con hasta 80 caracteres por campo. El usuario de acceso utiliza de 3 a 40 caracteres permitidos y no admite números en su formato actual. Las cuentas propietarias requieren una contraseña de 8 a 128 caracteres. Las cuentas antiguas deben completar su identidad antes de vender.')
p('La selección de imágenes separa web y plataformas nativas. prepararImagenProducto acepta archivos de entrada de hasta 20 MB, consulta las dimensiones antes de decodificar y reduce el lado mayor a 1200 píxeles. Convierte el resultado a PNG y rechaza un archivo procesado de más de 5 MB. El resultado se almacena como BLOB y se transmite como Base64 por la API. Se liberan los recursos gráficos para reducir el consumo de memoria. Elegir una imagen inválida debe mostrar un error sin sustituir el producto por datos incompletos.')

h('Ventas y trazabilidad')
p('VentasScreen permite construir una cuenta con varios productos, revisar el total y confirmar. Administradores y vendedores pueden vender; un invitado no. La cantidad es entera y positiva, y el servidor vuelve a comprobar los artículos activos, el stock, el vencimiento, el lote requerido y la relación entre costo y precio. Si el precio cambió desde la revisión del cliente, se exige actualizar antes de confirmar.')
p('La operación utiliza una transacción para descontar existencias e insertar la cabecera y los detalles. El descuento se condiciona a que el producto siga activo y disponga de la cantidad solicitada. Si dos vendedores intentan vender la última unidad, solo una operación puede completarse. La clave solicitud es única: un reintento de la misma solicitud no debe producir una segunda venta; una solicitud reutilizada con otro contenido se rechaza.')
p('El detalle conserva la identificación del producto, lote, vencimiento, unidad comercial, cantidad, precio y costo de ese momento. La cabecera guarda nombre completo y código interno del vendedor. Desactivar un producto no elimina esas filas. El registro se identifica por negocio y responsable, lo que permite consultar la actividad sin depender del nombre actual del artículo.')
p('La venta por lote corresponde a la cantidad del registro que pertenece a ese lote del fabricante. No es una función de producción o de división automática de paquetes. Si la unidad comercial configurada es una caja, una cantidad de dos representa dos unidades de ese registro; la aplicación no deduce cuántas botellas contiene cada caja.')
h('Historial y estadísticas', 2)
p('ReportesScreen ofrece filtros de hoy, últimos siete días, últimos treinta días o todo el historial. El administrador puede filtrar por vendedor y consultar el negocio completo. El vendedor recibe únicamente las ventas propias, restricción aplicada en el repositorio y también al consultar por API. El listado ya no se limita a las últimas 100 ventas. La actualización se solicita con el botón correspondiente o el gesto de recarga.')
table('Indicadores calculados sobre las ventas filtradas', ['Indicador', 'Regla de cálculo'], [
('Importe vendido', 'Suma de totalCentavos de las ventas, mostrada en quetzales.'),
('Ventas completadas', 'Número de cabeceras de venta del período.'),
('Unidades vendidas', 'Suma de cantidades del detalle; no equivale a litros, cajas convertidas o volumen.'),
('Promedio por venta', 'Importe vendido dividido entre ventas completadas; cero si no hay ventas.'),
('Margen bruto estimado', 'Ingresos menos costo histórico por cantidad; solo para administradores. Se advierten costos incompletos.'),
('Rendimiento por vendedor', 'Importe, número de ventas y unidades por responsable con ventas en el período.'),
('Productos más vendidos', 'Hasta diez productos ordenados por unidades del detalle histórico.')
], [1.7, 4.8])
p('Las métricas representan actividad comercial registrada. No evalúan horas trabajadas, asistencia, comisiones ni rentabilidad neta. El margen bruto no descuenta gastos ni impuestos. El sistema no implementa devoluciones y anulaciones contables, por lo que incorporarlas requerirá ajustar la interpretación de los indicadores y no solo restar existencias manualmente.')

h('Preparación del entorno de desarrollo')
p('Abrir en VS Code la carpeta que contiene pubspec.yaml. En este equipo se encuentra en C:\\Users\\a5326\\OneDrive\\Desktop\\aplicacion android. Las rutas absolutas siguientes corresponden al entorno preparado; en otra computadora deben ajustarse antes de ejecutar los scripts. Los usuarios finales que instalan la aplicación no necesitan Flutter ni VS Code.')
code('Set-Location "C:\\Users\\a5326\\OneDrive\\Desktop\\aplicacion android"\n& "C:\\src\\flutter\\bin\\flutter.bat" --version\n& "C:\\src\\flutter\\bin\\flutter.bat" doctor -v')
p('Android requiere Android SDK, Build Tools, licencias aceptadas, Java compatible y los componentes de Gradle utilizados por el proyecto. Windows requiere Visual Studio o Build Tools con Desarrollo para escritorio con C++, MSVC, CMake y Windows SDK. VS Code es el editor; no reemplaza ese compilador nativo (Flutter, s. f.-c). Para el instalador se necesita Inno Setup y el runtime redistribuible de Visual C++.')
code('& "C:\\src\\flutter\\bin\\flutter.bat" doctor --android-licenses\n& "C:\\src\\flutter\\bin\\flutter.bat" pub get\npowershell -NoProfile -ExecutionPolicy Bypass `\n  -File .\\scripts\\preparar.ps1')
p('preparar.ps1 descarga las dependencias y prepara los archivos SQLite y worker del cliente web. Si Flutter ya está en PATH, puede utilizarse flutter en lugar de la ruta completa. No se inicia un comando con -NoProfile: ese parámetro debe ir después de powershell. El uso de Bypass del ejemplo se limita al proceso que ejecuta el script; no requiere cambiar la política de ejecución de todo el equipo.')
h('Ejecución durante el desarrollo', 2)
code('& "C:\\src\\flutter\\bin\\flutter.bat" devices\n& "C:\\src\\flutter\\bin\\flutter.bat" run -d windows\n# Para el cliente web de desarrollo\n& "C:\\src\\flutter\\bin\\flutter.bat" run -d chrome `\n  --web-hostname=localhost --web-port=8080')
p('Cada comando run se ejecuta por separado y permanece activo durante la depuración. Para Android se sustituye el destino por el identificador que devuelve flutter devices. Un emulador es opcional: no se necesita para generar una APK destinada a un teléfono físico. En VS Code también puede usarse Flutter Select Device y F5 con las configuraciones de .vscode.')

h('Procedimiento para generar la APK Android')
p('Primero comprobar el proyecto y revisar la versión en pubspec.yaml. La entrega descrita usa 1.1.2+4: el nombre visible es 1.1.2 y el número interno Android es 4. En una actualización debe aumentarse el número de compilación y conservarse applicationId y la clave original si se desea actualizar una instalación existente.')
code('& "C:\\src\\flutter\\bin\\flutter.bat" analyze\n& "C:\\src\\flutter\\bin\\flutter.bat" test --concurrency=1\npowershell -NoProfile -ExecutionPolicy Bypass `\n  -File .\\scripts\\compilar_apk.ps1')
p('compilar_apk.ps1 localiza Flutter, prepara o reutiliza la firma privada y ejecuta una compilación release para android-arm y android-arm64. Genera build/app/outputs/flutter-apk/app-release.apk y copia el resultado a dist/StockGo-Android-pruebas.apk y dist/StockGo-1.1.2-Android.apk. El script es el punto de entrada recomendado: el Gradle del proyecto exige la configuración de firma para release, por lo que no basta con omitirla y ejecutar el comando de Flutter aislado.')
p('La clave se encuentra fuera del repositorio, en %LOCALAPPDATA%\\StockGoBuildKeys\\stockgo-release.jks, y el secreto se protege con DPAPI en firma-secreto.xml. La clave usa alias stockgo y RSA de 3072 bits. No debe adjuntarse a la APK, subirse al repositorio ni regenerarse para una actualización. Es necesario un respaldo privado y un procedimiento de recuperación: el archivo DPAPI no es portable por sí solo a otro usuario de Windows.')
p('Android exige una firma digital válida para instalar y actualizar APK. La continuidad del certificado es distinta de la reputación o revisión de la aplicación (Android Developers, s. f.). El proceso de release de Flutter también contempla revisar icono, manifiesto, versión y configuración antes de distribuir (Flutter, s. f.-a).')
h('Verificación de la APK', 2)
code('$env:JAVA_HOME = "C:\\Program Files\\Android\\Android Studio\\jbr"\n& "C:\\Android\\sdk\\build-tools\\36.0.0\\apksigner.bat" `\n  verify --verbose --print-certs .\\dist\\StockGo-1.1.2-Android.apk\n& "C:\\Android\\sdk\\build-tools\\36.0.0\\zipalign.exe" `\n  -c -P 16 4 .\\dist\\StockGo-1.1.2-Android.apk\nGet-FileHash .\\dist\\StockGo-1.1.2-Android.apk -Algorithm SHA256')
p('La salida debe confirmar una firma válida y el certificado de StockGo; zipalign debe terminar con código cero. La APK de esta entrega declara minSdk 24, correspondiente a Android 7.0, e incluye ARM de 32 bits y ARM64. El objetivo comprobado del artefacto es API 36. Estas características no demuestran que se haya probado físicamente cada modelo de teléfono. La alineación de archivo es una comprobación de compatibilidad y no una revisión completa del comportamiento del sistema.')
h('Instalación en un teléfono real', 2)
p('Transferir el archivo .apk completo, abrirlo desde una aplicación autorizada para instalar archivos y seguir las opciones que muestre Android. No convertirlo en .zip. Si ya existe una versión con una firma distinta, no desinstalarla sin respaldar sus datos locales. Una instalación de la versión 1.1.1 firmada con la misma clave StockGo puede actualizarse conservando esa identidad; las compilaciones antiguas con certificado Android Debug no son equivalentes.')
p('Play Protect puede bloquear una aplicación desconocida aun cuando la firma sea válida. Leer Más detalles y permitir el análisis si se ofrece. Si continúa un bloqueo que se considera incorrecto, se requiere el proceso oficial de revisión; recompilar o cambiar el icono no garantiza eliminarlo. La guía de Google distingue advertencias de aplicación desconocida, permisos sensibles, software potencialmente dañino y compatibilidad antigua (Google for Developers, s. f.).')

h('Procedimiento para generar el ejecutable de Windows')
p('Deben distinguirse dos archivos .exe. StockGo.exe es la aplicación compilada y necesita las bibliotecas y carpetas situadas junto a ella. StockGo-Instalador-Windows.exe es el asistente que instala esa aplicación completa y crea accesos directos. Enviar únicamente el primer archivo no equivale a entregar un instalador. Flutter permite distribuir aplicaciones Windows fuera de Microsoft Store, aunque la distribución de tienda tiene su propio empaquetado (Flutter, s. f.-b).')
h('Compilar la aplicación de escritorio', 2)
code('powershell -NoProfile -ExecutionPolicy Bypass `\n  -File .\\scripts\\compilar_windows.ps1')
p('Este script compila primero web y luego Windows. Los archivos web se incluyen para el panel de la PC. El ejecutable queda en build/windows/x64/runner/Release/StockGo.exe y se crea un acceso directo de desarrollo salvo que se utilice -SinAtajo. Debe conservarse toda la carpeta Release con sus archivos data y bibliotecas; no deben incluirse bases de datos personales al distribuirla.')
h('Crear el instalador ejecutable', 2)
code('powershell -NoProfile -ExecutionPolicy Bypass `\n  -File .\\scripts\\crear_instaladores.ps1')
p('crear_instaladores.ps1 realiza en secuencia las compilaciones web, Windows y Android. Después incorpora las DLL del runtime MSVC, busca ISCC.exe de Inno Setup y procesa installer/windows/stockgo.iss. El compilador puede encontrarse en build/tools/inno/ISCC.exe o en PATH. Finalmente genera el instalador .exe, copia la APK y escribe SHA256.txt con las huellas de los archivos principales. El proyecto usa las directivas de empaquetado de Inno Setup para incluir archivos y accesos directos (Russell & Laan, s. f.).')
p('La opción -SinCompilar solo debe utilizarse si ya existen compilaciones web, Windows y Android actualizadas y correspondientes a la misma versión. No prepara desde cero esas salidas. Para una entrega nueva es preferible usar el comando completo y comprobar cada resultado antes de compartirlo.')
code('Get-Item .\\dist\\StockGo-Instalador-Windows.exe\nGet-FileHash .\\dist\\StockGo-Instalador-Windows.exe `\n  -Algorithm SHA256')
p('El archivo .iss declara versión 1.1.2, instalación por usuario y compatibilidad x64. Instala en %LOCALAPPDATA%\\Programs\\StockGo y excluye archivos .db, .db-shm, .db-wal y .dart_tool. Los datos de operación permanecen en %LOCALAPPDATA%\\StockGo\\databases. Para actualizar se cierra la aplicación y se ejecuta el instalador; conservar una copia de seguridad sigue siendo necesario. Un instalador generado no equivale a una certificación de Microsoft ni garantiza reputación SmartScreen.')

h('Pruebas y diagnóstico')
p('La carpeta test contiene verificaciones de datos, red, permisos, imágenes, diseño y reglas de venta. Para validar una modificación se ejecuta el análisis y las pruebas pertinentes; antes de una entrega se recomienda ejecutar la suite completa con concurrencia uno en equipos de memoria limitada. Los resultados de una ejecución anterior no deben presentarse como si se hubieran repetido después de cualquier cambio.')
code('& "C:\\src\\flutter\\bin\\flutter.bat" analyze\n& "C:\\src\\flutter\\bin\\flutter.bat" test --concurrency=1\n# Comprobación focalizada de conexión y reportes\n& "C:\\src\\flutter\\bin\\flutter.bat" test `\n  test/reportes_test.dart test/red_seleccionada_test.dart `\n  test/ventas_test.dart test/codigo_negocio_test.dart `\n  --concurrency=1')
p('La validación previa de 1.1.2 registró 17 pruebas seleccionadas correctas, análisis sin observaciones y verificación de firma y alineación de la APK. Incluyó agregación de indicadores, más de 100 ventas, permisos de reportes, detalle móvil, identidad del negocio, selector de red y operación transaccional por API. Se conserva esta evidencia como antecedente de esa entrega; no acredita una prueba física en todos los sistemas operativos.')
table('Problemas frecuentes y comprobación correspondiente', ['Síntoma', 'Comprobación y acción'], [
('No se encuentra Visual Studio toolchain', 'Revisar Desktop development with C++, MSVC, CMake y Windows SDK; VS Code no instala ese compilador.'),
('No aparece emulator 5554', 'Consultar flutter devices; usar el ID real. Para crear la APK no es necesario abrir un emulador.'),
('No conecta el código SG1', 'Verificar maestro abierto, IP de la misma Wi-Fi, identidad correcta, red privada y firewall. Compartir de nuevo si cambió la IP.'),
('Servidor deshabilitado en el navegador', 'Abrir StockGo nativo. En Windows usar el panel local 8079 y autenticarse como administrador.'),
('La APK no se instala', 'Leer la causa concreta: firma diferente, archivo incompleto, permisos de instalación o bloqueo Play Protect. No asumir incompatibilidad solo por el mensaje genérico.'),
('La foto se rechaza', 'Probar un archivo válido dentro de los límites de entrada y salida; revisar el mensaje de formato o tamaño.'),
('Se deniega una venta', 'Comprobar rol, perfil, producto activo, lote requerido, stock, vencimiento, precio positivo y precio de venta no inferior al costo.')
], [2.0, 4.5])
h('Plan de prueba entre PC y teléfono', 2)
p('Instalar la versión actual en ambos equipos. Crear un negocio de prueba en el maestro y un vendedor con identidad completa. Registrar dos productos con lote y stock conocido. Iniciar el servidor, elegir la IP correcta y copiar el código. Desde el teléfono conectarse con ese código y la cuenta del vendedor. Registrar una venta de dos productos, verificar el descuento de stock en el maestro y comprobar la identidad y el detalle en Historial y estadísticas. Probar también que el invitado no vende y que un vendedor no modifica el catálogo. Finalmente cerrar sesión del administrador y confirmar que el servidor se detiene. La evidencia debe incluir versión, equipos, fecha y resultado, sin registrar contraseñas ni claves privadas.')

h('Conclusiones')
p('StockGo reúne inventario, registro de ventas y reportes en una base Flutter compartida. La separación entre presentación, estado, repositorio y red permite mantener las reglas comerciales en el acceso a datos, además de ofrecer controles de interfaz adecuados al rol. Esta estructura reduce la dependencia de una pantalla específica para aplicar permisos y conservar el comportamiento entre clientes.')
p('Las fichas diferenciadas por categoría representan mejor el negocio automotriz que un formulario único. Los campos de viscosidad y homologación de lubricantes, así como referencias, dimensiones y compatibilidad de repuestos, mejoran la identificación del artículo. La calidad de esos datos sigue dependiendo de la documentación y verificación del fabricante; el sistema no certifica la adecuación de un producto para un vehículo.')
p('Las transacciones, el control de solicitudes repetidas y los detalles históricos proporcionan una base para vender sin duplicar operaciones y reconocer al responsable. Los reportes convierten esa información en indicadores comerciales comprensibles. Sin registros de gastos, devoluciones o asistencia no puede deducirse rentabilidad neta ni productividad por hora.')
p('El modelo de maestro en red local permite compartir información sin Firebase ni un servicio público, pero depende de la disponibilidad del equipo anfitrión y de una red alcanzable. El código SG1 facilita elegir el negocio; no reemplaza la autenticación ni el cifrado de transporte. Los procedimientos de firma, compilación y empaquetado hacen repetible la entrega Android y Windows, mientras que la aceptación de plataformas y las pruebas físicas requieren validaciones separadas.')
h('Recomendaciones', 2)
p('Antes de utilizar la aplicación con información comercial definitiva, establecer copias de seguridad y una prueba de restauración; evaluar TLS y control de acceso a la red; incorporar anulaciones y devoluciones auditables; normalizar proveedores y recepciones si se requieren varios lotes por SKU; y diseñar conversiones explícitas para cajas y unidades. La publicación en tiendas debe contar con cuentas, certificados y revisiones oficiales. iOS y macOS deben compilarse y probarse en un Mac con Xcode, sin equiparar la presencia de esas carpetas a una distribución ya validada.')

d.add_page_break()
h('Referencias')
refs = [
('American Psychological Association. (s. f.). ', 'Paper format', '. https://apastyle.apa.org/style-grammar-guidelines/paper-format'),
('Android Developers. (s. f.). ', 'Sign your app', '. https://developer.android.com/studio/publish/app-signing'),
('Flutter. (s. f.-a). ', 'Build and release an Android app', '. https://docs.flutter.dev/deployment/android'),
('Flutter. (s. f.-b). ', 'Build and release a Windows desktop app', '. https://docs.flutter.dev/deployment/windows'),
('Flutter. (s. f.-c). ', 'Set up Windows development', '. https://docs.flutter.dev/platform-integration/windows/setup'),
('Google for Developers. (s. f.). ', 'Developer guidance for Google Play Protect warnings', '. https://developers.google.com/android/play-protect/warning-dev-guidance'),
('Russell, J., & Laan, M. (s. f.). ', 'Inno Setup help', '. https://jrsoftware.org/ishelp/'),
('SQLite. (s. f.). ', 'SQLite is transactional', '. https://www.sqlite.org/transactional.html'),
('StockGo. (2026). ', 'StockGo', ' (Versión 1.1.2+4) [Código fuente y documentación técnica no publicados]. Proyecto local.'),
]
for before, title, after in refs:
    x = p('', False); x.paragraph_format.left_indent = Inches(.5); x.paragraph_format.first_line_indent = Inches(-.5)
    x.add_run(before); x.add_run(title).italic = True; x.add_run(after)

d.add_page_break()
h('Apéndice A')
h('Inventario técnico de archivos')
p('Los siguientes listados describen los archivos propios de la aplicación y sus puntos de configuración. Las rutas son relativas a la raíz del proyecto. Las carpetas de compilación y dependencias generadas no forman parte de la lógica que debe modificarse manualmente. El inventario de pantallas, datos, red, servicios y widgets corresponde a la versión 1.1.2+4.', False)
purposes = {
'main.dart': 'Inicializa Flutter, fábrica SQLite, estado, tema y control local de Windows.',
'data/stockgo_store.dart': 'Sesión, selección de negocio y enrutamiento local o remoto de operaciones.',
'data/stockgo_repository.dart': 'Esquema v9, migraciones, credenciales, permisos, productos y ventas SQLite.',
'data/platform/database_connection.dart': 'Exportación condicional de la fábrica de base de datos.',
'data/platform/database_native.dart': 'SQLite móvil y FFI de escritorio; prepara almacenamiento Windows.',
'data/platform/database_web.dart': 'Fábrica SQLite para almacenamiento web.',
'data/platform/windows_storage.dart': 'Ubicación estable y migración segura del almacenamiento Windows.',
'models/usuario.dart': 'Rol, identidad, código interno y validación de nombres.',
'models/producto.dart': 'Modelo y mapeo de campos de producto e imagen.',
'models/negocio.dart': 'Identidad del catálogo local de negocios.',
'models/ficha_producto.dart': 'Definición de campos técnicos y categorías.',
'models/opciones_ficha.dart': 'Opciones de captura según campo, categoría y tipo.',
'models/venta.dart': 'Líneas de solicitud, cabecera y detalles históricos de venta.',
'models/resumen_ventas.dart': 'Agregación de ventas, unidades, costos y rankings.',
'screens/login_screen.dart': 'Acceso local o remoto y selección del negocio.',
'screens/registro_screen.dart': 'Registro de cuenta o propietario y validación personal.',
'screens/home_screen.dart': 'Resumen del negocio y acceso a módulos por rol.',
'screens/productos_screen.dart': 'Catálogo, búsqueda, filtros, detalle y acciones autorizadas.',
'screens/producto_form_screen.dart': 'Alta y edición del producto con ficha e imagen.',
'screens/equipo_screen.dart': 'Consulta de vendedores y administradores e invitaciones.',
'screens/servidor_screen.dart': 'Inicio y detención del maestro, elección de red y copia del código.',
'screens/ventas_screen.dart': 'Cuenta con varios productos y confirmación de la venta.',
'screens/reportes_screen.dart': 'Historial, filtros, detalle y estadísticas.',
'network/codigo_negocio.dart': 'Codifica y valida el paquete SG1 de dirección e identidad.',
'network/stockgo_api.dart': 'Cliente HTTP con código empresarial y sesión.',
'network/stockgo_lan_server.dart': 'Servidor LAN, sesiones y rutas de datos autorizadas.',
'network/local_host.dart': 'Validación de hosts locales y rangos privados para HTTP.',
'network/hosting.dart': 'Exportación condicional del anfitrión del servidor.',
'network/hosting_native.dart': 'Adaptador de servidor para plataforma nativa.',
'network/hosting_web.dart': 'Restricción de alojamiento directo desde el navegador.',
'network/windows_browser_control.dart': 'Puente local Windows para el panel web y su control autorizado.',
'services/windows_control.dart': 'Selección condicional del control Windows.',
'services/windows_control_native.dart': 'Puesta en marcha nativa del puente Windows.',
'services/windows_control_web.dart': 'Comportamiento de control desde la compilación web.',
'services/imagen_producto.dart': 'Lectura de dimensiones, reducción y conversión de imágenes.',
'services/imagen_picker.dart': 'Exportación condicional para elegir imágenes.',
'services/imagen_picker_native.dart': 'Selección de imágenes en plataforma nativa.',
'services/imagen_picker_web.dart': 'Selección de imágenes en navegador.',
'theme/stockgo_theme.dart': 'Colores celestes, tipografía y estilos Material compartidos.',
'widgets/acceso_negocio_dialog.dart': 'Ingreso del código y datos para conectar a un negocio.',
'widgets/campo_seleccion_producto.dart': 'Control reutilizable de opciones para campos de producto.',
'widgets/cantidad_venta_dialog.dart': 'Captura y comprobación de la cantidad que se venderá.',
'widgets/cerrar_sesion_button.dart': 'Acción de cierre de sesión y limpieza de navegación.',
'widgets/ficha_tecnica_form.dart': 'Formulario técnico dinámico por categoría.',
'widgets/maestro_web_panel.dart': 'Interfaz del navegador para activar el maestro Windows autorizado.',
'widgets/negocio_pasos.dart': 'Orientación de pasos para configurar y compartir un negocio.',
'widgets/perfil_personal_dialog.dart': 'Completar identidad de cuentas anteriores.',
'widgets/producto_imagen.dart': 'Visualización y tratamiento de estados de la fotografía.',
'widgets/stockgo_background.dart': 'Fondo visual y animaciones con adaptación de movimiento.',
'widgets/stockgo_bottom_navigation.dart': 'Navegación móvil por módulos y roles.',
'widgets/stockgo_design.dart': 'Tarjetas, distintivos de iconos y elementos visuales comunes.',
'widgets/stockgo_inventory_scene.dart': 'Ilustración vectorial de inventario.',
'widgets/stockgo_login_decoration.dart': 'Formas y bandas decorativas del acceso.',
'widgets/stockgo_module_menu.dart': 'Menú de módulos y comprobación del acceso por rol.',
'widgets/stockgo_product_card.dart': 'Tarjeta de producto con fotografía, precio y disponibilidad.',
'widgets/stockgo_showcase.dart': 'Presentación visual y acción principal del inicio.',
'widgets/windows_servidor_dialog.dart': 'Configuración y activación del maestro Windows desde el cliente.',
}
for label, prefix in [('Arranque y datos', ['main.dart','data/']), ('Modelos', ['models/']), ('Pantallas', ['screens/']), ('Red y servicios', ['network/','services/']), ('Tema y componentes visuales', ['theme/','widgets/'])]:
    h(label, 2)
    files = sorted(f for f in (ROOT/'lib').rglob('*.dart') if any(f.relative_to(ROOT/'lib').as_posix().startswith(x) for x in prefix))
    table(label, ['Archivo dentro de lib', 'Responsabilidad'], [(f.relative_to(ROOT/'lib').as_posix(), purposes.get(f.relative_to(ROOT/'lib').as_posix(), 'Componente de soporte de la aplicación.')) for f in files], [2.65, 3.85])

h('Scripts y configuración', 2)
table('Archivos de preparación y distribución', ['Ruta o carpeta', 'Responsabilidad'], [
('pubspec.yaml y pubspec.lock', 'Metadatos, versión, dependencias declaradas y resolución exacta.'),
('analysis_options.yaml', 'Reglas de análisis estático Dart.'),
('.vscode', 'Configuración del SDK, tareas, extensiones y destinos de depuración.'),
('scripts/flutter-sdk.ps1', 'Localiza el SDK Flutter que usarán los demás scripts.'),
('scripts/preparar.ps1', 'Prepara dependencias y archivos SQLite web.'),
('scripts/ejecutar.ps1', 'Ejecuta Chrome, Edge o un único destino Android detectado.'),
('scripts/compilar_apk.ps1', 'Firma release persistente y APK para ARM y ARM64.'),
('scripts/compilar_windows.ps1', 'Compila web y escritorio; crea acceso directo de desarrollo.'),
('scripts/crear_instaladores.ps1', 'Compila y empaqueta APK y Windows con Inno Setup y huellas SHA 256.'),
('scripts/iniciar_emulador.ps1', 'Inicia el AVD configurado para el desarrollo Android.'),
('scripts/habilitar_emulador_windows.ps1', 'Soporte para configurar requisitos de virtualización en Windows.'),
('bin/preparar_datos_windows.dart', 'Utilidad de preparación del almacenamiento de escritorio.'),
('installer/windows/stockgo.iss', 'Directivas del instalador: versión, archivos, rutas, accesos y exclusiones.'),
('android', 'Anfitrión Kotlin, Gradle, manifiesto, permisos y recursos de icono.'),
('ios y macos', 'Anfitriones Apple, configuración y permisos nativos; requieren Mac para distribución.'),
('windows y linux', 'Anfitriones de escritorio con compilación CMake y recursos del ejecutable.'),
('web', 'Entrada web, manifiesto, iconos, SQLite WASM y worker.'),
('build y .dart_tool', 'Resultados y herramientas generadas; no editar como código funcional.'),
('dist', 'Entregables APK y .exe, instrucciones y huellas de verificación.'),
('docs', 'Notas de conexión, modelo automotriz, ventas, interfaz y distribución.'),
('README.md', 'Guía general con notas históricas; confirmar los detalles vigentes en código y scripts.')
], [2.65, 3.85])
p('Los archivos de anfitrión y los registradores de plugins se generan o mantienen con Flutter. No sustituyen las clases Dart de negocio. La carpeta build puede contener herramientas locales como el compilador Inno; esas herramientas deben reinstalarse o ubicarse en PATH cuando se prepara otra computadora.', False)

h('Pruebas automatizadas', 2)
test_desc = {
'reportes_test.dart': 'Totales, costos históricos, más de 100 ventas y permisos del detalle móvil.',
'red_seleccionada_test.dart': 'Código copiado con la IP seleccionada y la misma identidad empresarial.',
'ventas_test.dart': 'Ventas por API, concurrencia de stock, lotes, permisos e idempotencia.',
'ventas_widget_test.dart': 'Venta por unidad o lote y revisión del flujo visual.',
'codigo_negocio_test.dart': 'Identidad de empresas separadas y persistencia de códigos.',
'servidor_test.dart': 'Datos e imágenes compartidos y permisos por sesión.',
'windows_storage_test.dart': 'Migración y conservación del almacenamiento Windows.',
'windows_control_equipo_test.dart': 'Puente Windows y operaciones de equipo.',
'identidad_test.dart': 'Validación de identidad e identificación interna.',
'local_host_test.dart': 'Hosts locales válidos y rechazo de direcciones fuera del alcance.',
}
rows=[]
for f in sorted((ROOT/'test').glob('*.dart')):
    desc=test_desc.get(f.name)
    if desc is None:
        if 'imagen' in f.name or 'fotos' in f.name: desc='Selección, procesamiento o persistencia de imágenes y cuentas.'
        elif any(w in f.name for w in ['visual','responsive','catalogo']): desc='Diseño, navegación y adaptación de interfaz.'
        elif any(w in f.name for w in ['ficha','opciones']): desc='Conexión o captura de ficha técnica por categoría.'
        elif any(w in f.name for w in ['negocio','acceso','compartir']): desc='Selección de negocio, acceso y permisos de colaboración.'
        elif 'sesion' in f.name: desc='Registro, acceso y cierre de sesión.'
        else: desc='Flujo de aplicación, persistencia y permisos funcionales.'
    rows.append((f.name, desc))
table('Inventario de pruebas del proyecto', ['Archivo dentro de test', 'Cobertura principal'], rows, [2.75,3.75])

d.add_page_break()
h('Apéndice B')
h('Contrato básico de la API local')
p('Las rutas siguientes son relativas a la base API utilizada por StockGoApi. El código del negocio y la autenticación se validan según la operación. La lista sirve para comprender la comunicación; no es necesario escribir estas solicitudes para usar la aplicación.', False)

table('Operaciones HTTP principales', ['Método y ruta', 'Función y acceso'], [
('POST connect', 'Verifica identidad del negocio antes de usarlo como destino.'),
('GET health', 'Estado y datos generales de disponibilidad del maestro.'),
('POST setup', 'Configuración inicial protegida por código; no crea otro propietario si ya existe.'),
('POST auth/register', 'Registro remoto de vendedor en un negocio configurado.'),
('POST auth/login', 'Autentica cuenta del negocio y devuelve sesión.'),
('POST auth/guest', 'Crea acceso de invitado sin permisos de escritura.'),
('PUT auth/profile', 'Completa datos personales de la sesión.'),
('POST auth/logout', 'Invalida la sesión correspondiente.'),
('GET users y POST users', 'Consulta del equipo y creación de cuentas por administrador.'),
('GET server/info', 'Datos para invitaciones del negocio por administrador.'),
('GET products', 'Consulta autorizada; q filtra e inactivos se reserva al administrador.'),
('GET products/id', 'Detalle de producto según visibilidad del rol.'),
('POST products y PUT products/id', 'Registro y edición administrativa de productos.'),
('POST products/id/deactivate', 'Desactivación administrativa sin borrar la fila.'),
('GET sales', 'Historial del negocio para administrador o solo propio para vendedor.'),
('POST sales', 'Venta transaccional para administrador o vendedor autenticado.')
], [2.4,4.1])

# Integridad estructural y alcance del inventario.
actual={f.relative_to(ROOT/'lib').as_posix() for f in (ROOT/'lib').rglob('*.dart')}
missing=actual-set(purposes)
if missing: raise RuntimeError(f'Faltan descripciones de archivos: {missing}')
OUT.parent.mkdir(parents=True, exist_ok=True)
d.save(OUT)
print(OUT)
print(f'Archivos Dart documentados: {len(actual)}; pruebas: {len(rows)}; tablas: {number_table}')
