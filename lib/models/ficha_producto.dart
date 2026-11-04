class CampoProducto {
  const CampoProducto(
    this.clave,
    this.etiqueta,
    this.ejemplo, {
    this.grupo = 'general',
  });
  final String clave;
  final String etiqueta;
  final String ejemplo;
  final String grupo;
}

const camposProducto = [
  CampoProducto('marca', 'Marca', 'Castrol, Mobil, Bosch, NGK'),
  CampoProducto(
    'tipo',
    'Tipo / subcategoría',
    'Aceite de motor, filtro de aceite, bujía',
  ),
  CampoProducto(
    'descripcion',
    'Descripción',
    'Características y observaciones',
  ),
  CampoProducto(
    'numeroParte',
    'Número de parte del fabricante',
    'Referencia del catálogo del fabricante',
  ),
  CampoProducto(
    'referenciaOEM',
    'Referencias OEM / equivalencias',
    'Referencias originales verificadas',
  ),
  CampoProducto(
    'codigoBarras',
    'Código de barras / GTIN',
    'Código de la etiqueta',
  ),
  CampoProducto(
    'unidadVenta',
    'Unidad de venta',
    'Unidad, botella, litro, caja, juego',
  ),
  CampoProducto(
    'presentacion',
    'Presentación / contenido',
    '1 L, 4 L, 1 galón, juego de 4',
  ),
  CampoProducto('ubicacion', 'Ubicación en almacén', 'Pasillo A, estante 2'),
  CampoProducto('proveedor', 'Proveedor', 'Nombre comercial del proveedor'),
  CampoProducto(
    'lote',
    'Lote del fabricante',
    'Copia el lote del envase. Usa un código de inventario distinto por lote para conservar la trazabilidad.',
  ),
  CampoProducto('vencimiento', 'Vencimiento', 'AAAA-MM-DD, si aplica'),
  CampoProducto(
    'viscosidadSAE',
    'Viscosidad SAE',
    '5W-30, 10W-40, 75W-90',
    grupo: 'aceite',
  ),
  CampoProducto(
    'baseAceite',
    'Base del aceite',
    'Mineral, semisintético, sintético',
    grupo: 'aceite',
  ),
  CampoProducto(
    'normaAPI',
    'Clasificación API',
    'Copiar la clasificación del envase',
    grupo: 'aceite',
  ),
  CampoProducto(
    'normaACEA',
    'Especificación ACEA / ILSAC',
    'Copiar la especificación del envase',
    grupo: 'aceite',
  ),
  CampoProducto(
    'homologaciones',
    'Homologaciones del fabricante',
    'Aprobaciones indicadas en la ficha técnica',
    grupo: 'aceite',
  ),
  CampoProducto(
    'aplicacion',
    'Aplicación',
    'Motor gasolina/diésel, transmisión, diferencial',
    grupo: 'aceite',
  ),
  CampoProducto(
    'calibre',
    'Calibre / medida',
    'Medida y unidad, según el repuesto',
    grupo: 'repuesto',
  ),
  CampoProducto(
    'dimensiones',
    'Dimensiones / rosca',
    'Diámetro, largo, rosca y unidad',
    grupo: 'repuesto',
  ),
  CampoProducto(
    'material',
    'Material',
    'Acero, aluminio, cerámica',
    grupo: 'repuesto',
  ),
  CampoProducto(
    'posicion',
    'Posición de montaje',
    'Delantero, trasero, izquierdo, derecho',
    grupo: 'repuesto',
  ),
  CampoProducto(
    'compatibilidad',
    'Vehículos compatibles',
    'Una aplicación por línea: marca, modelo, años, motor, combustible',
    grupo: 'repuesto',
  ),
  CampoProducto(
    'gradoFiltracion',
    'Grado de filtración',
    'Micras según ficha del fabricante',
    grupo: 'filtro',
  ),
  CampoProducto(
    'valvulaBypass',
    'Válvula bypass',
    'Presión / especificación, si aplica',
    grupo: 'filtro',
  ),
  CampoProducto(
    'dosificacion',
    'Dosificación',
    'ml por litro o por depósito según etiqueta',
    grupo: 'aditivo',
  ),
  CampoProducto(
    'fluidoCompatible',
    'Fluido / sistema compatible',
    'Combustible, aceite, refrigerante; según etiqueta',
    grupo: 'aditivo',
  ),
  CampoProducto(
    'voltaje',
    'Voltaje de operación',
    '12 V, 24 V; si aplica',
    grupo: 'accesorio',
  ),
  CampoProducto(
    'potencia',
    'Potencia / capacidad',
    'W, A u otra unidad indicada',
    grupo: 'accesorio',
  ),
];

const categoriasProducto = [
  'Repuesto',
  'Lubricante',
  'Filtro',
  'Aditivo',
  'Accesorio',
];

List<CampoProducto> camposParaCategoria(String categoria) {
  const comunes = {
    'marca',
    'tipo',
    'descripcion',
    'codigoBarras',
    'unidadVenta',
    'presentacion',
    'ubicacion',
    'proveedor',
    'lote',
    'vencimiento',
  };
  final tecnicos = switch (categoria) {
    'Lubricante' => {
      'viscosidadSAE',
      'baseAceite',
      'normaAPI',
      'normaACEA',
      'homologaciones',
      'aplicacion',
    },
    'Filtro' => {
      'numeroParte',
      'referenciaOEM',
      'dimensiones',
      'compatibilidad',
      'gradoFiltracion',
      'valvulaBypass',
    },
    'Aditivo' => {'dosificacion', 'fluidoCompatible', 'aplicacion'},
    'Accesorio' => {
      'numeroParte',
      'dimensiones',
      'material',
      'compatibilidad',
      'voltaje',
      'potencia',
    },
    _ => {
      'numeroParte',
      'referenciaOEM',
      'calibre',
      'dimensiones',
      'material',
      'posicion',
      'compatibilidad',
    },
  };
  return camposProducto
      .where((c) => comunes.contains(c.clave) || tecnicos.contains(c.clave))
      .toList();
}

String tituloFichaCategoria(String categoria) => switch (categoria) {
  'Lubricante' => 'Ficha de lubricante',
  'Filtro' => 'Ficha de filtro',
  'Aditivo' => 'Ficha de aditivo',
  'Accesorio' => 'Ficha de accesorio',
  _ => 'Ficha de repuesto',
};

String descripcionFichaCategoria(String categoria) => switch (categoria) {
  'Lubricante' => 'Viscosidad, base y especificaciones del aceite. Transcribe los datos del envase o fabricante.',
  'Filtro' => 'Referencias, medidas, filtración y aplicación por vehículo.',
  'Aditivo' => 'Sistema de aplicación, compatibilidad y dosificación indicados en la etiqueta.',
  'Accesorio' =>
    'Dimensiones, material y características eléctricas cuando correspondan.',
  _ => 'Identifica la pieza, sus medidas y las aplicaciones verificadas en el catálogo del fabricante.',
};
