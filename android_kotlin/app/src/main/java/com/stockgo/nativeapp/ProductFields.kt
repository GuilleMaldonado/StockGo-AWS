package com.stockgo.nativeapp

data class Field(val key: String, val label: String, val options: List<String> = emptyList())

object ProductFields {
    val categories = listOf("Repuesto", "Lubricante", "Filtro", "Aditivo", "Accesorio")
    private fun choices(value: String) = value.split('|')
    fun fields(category: String, type: String = ""): List<Field> {
        val types = when (category) {
            "Lubricante" -> "Aceite de motor|Aceite de transmisión manual|Aceite de diferencial|ATF|CVT|Aceite hidráulico|Grasa"
            "Filtro" -> "Filtro de aceite|Filtro de aire|Filtro de combustible|Filtro de habitáculo"
            "Aditivo" -> "Aditivo de combustible|Aditivo de aceite|Limpiador de inyectores|Tratamiento de refrigerante"
            "Accesorio" -> "Iluminación|Eléctrico|Limpieza|Interior|Exterior"
            else -> "Bujía|Pastilla de freno|Disco de freno|Correa|Rodamiento|Suspensión|Empaque"
        }
        val common = listOf(
            Field("marca", "Marca"), Field("tipo", "Tipo / subcategoría", choices(types)),
            Field("descripcion", "Descripción"), Field("codigoBarras", "Código de barras / GTIN"),
            Field("unidadVenta", "Unidad de venta", choices("Unidad|Botella|Litro|Galón|Caja|Juego|Par|Kilogramo")),
            Field("presentacion", "Presentación / contenido"), Field("ubicacion", "Ubicación en almacén"),
            Field("proveedor", "Proveedor"), Field("lote", "Lote del fabricante"),
            Field("vencimiento", "Vencimiento (AAAA-MM-DD, si aplica)")
        )
        val gear = type in listOf("Aceite de transmisión manual", "Aceite de diferencial")
        val noSae = type in listOf("ATF", "CVT", "Aceite hidráulico", "Grasa")
        val specific = when (category) {
            "Lubricante" -> listOf(
                Field("viscosidadSAE", "Viscosidad SAE", choices(when {
                    noSae -> "No aplica; consultar especificación del fabricante"
                    gear -> "70W|75W|80W|85W|75W-80|75W-85|75W-90|75W-140|80W-90|85W-140|90|140"
                    else -> "0W-8|0W-12|0W-16|0W-20|0W-30|0W-40|5W-20|5W-30|5W-40|5W-50|10W-30|10W-40|15W-40|15W-50|20W-50|SAE 30|SAE 40|SAE 50"
                })),
                Field("baseAceite", "Base del aceite", choices("Mineral|Semisintético|Sintético|No especificado")),
                Field("normaAPI", "Clasificación API", choices(if (gear) "GL-4|GL-5|No especificado" else if (noSae) "No especificado" else "SQ|SP|SN PLUS|SN|SM|SL|CK-4|FA-4|CJ-4|CI-4|CH-4|No especificado")),
                Field("normaACEA", "ACEA / ILSAC", choices("A3/B4|A5/B5|A7/B7|C2|C3|C4|C5|C6|C7|ILSAC GF-7A|ILSAC GF-7B|ILSAC GF-6A|ILSAC GF-6B|No especificado")),
                Field("homologaciones", "Homologaciones del fabricante"), Field("aplicacion", "Aplicación")
            )
            "Filtro" -> listOf(Field("numeroParte", "Número de parte"), Field("referenciaOEM", "Referencias OEM"),
                Field("dimensiones", "Dimensiones / rosca"), Field("compatibilidad", "Vehículos compatibles"),
                Field("gradoFiltracion", "Grado de filtración (micras)"), Field("valvulaBypass", "Válvula bypass"))
            "Aditivo" -> listOf(Field("dosificacion", "Dosificación según etiqueta"),
                Field("fluidoCompatible", "Fluido compatible", choices("Gasolina|Diésel|Aceite de motor|Refrigerante|Transmisión")), Field("aplicacion", "Aplicación"))
            "Accesorio" -> listOf(Field("numeroParte", "Número de parte"), Field("dimensiones", "Dimensiones"),
                Field("material", "Material"), Field("compatibilidad", "Vehículos compatibles"),
                Field("voltaje", "Voltaje", choices("12 V|24 V|6 V|No aplica")), Field("potencia", "Potencia / capacidad"))
            else -> listOf(Field("numeroParte", "Número de parte"), Field("referenciaOEM", "Referencias OEM"),
                Field("calibre", "Calibre / medida y unidad"), Field("dimensiones", "Dimensiones / rosca"),
                Field("material", "Material", choices("Acero|Aluminio|Cerámica|Cobre|Plástico|Caucho|Material compuesto")),
                Field("posicion", "Posición de montaje", choices("Delantero|Trasero|Izquierdo|Derecho|Delantero izquierdo|Delantero derecho|Trasero izquierdo|Trasero derecho|No aplica")),
                Field("compatibilidad", "Vehículos compatibles (marca, modelo, años, motor)"))
        }
        return common + specific
    }
}
