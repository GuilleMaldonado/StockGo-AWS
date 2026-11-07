package com.stockgo.nativeapp

import org.junit.Assert.*
import org.junit.Test

class HostPolicyTest {
    @Test fun cloudPolicyOnlyAllowsSimpleHttpsUrls() {
        assertNotNull(HostPolicy.validate("https://stockgo.example.org"))
        listOf(
            "http://192.168.0.2:8081",
            "https://stockgo.example.org/path",
            "https://user:secret@stockgo.example.org",
            "https://stockgo.example.org?secret=x",
            "file:///etc/passwd",
        ).forEach { value ->
            assertThrows(IllegalArgumentException::class.java) { HostPolicy.validate(value) }
        }
    }
    @Test fun technicalFieldsChangeByCategory() {
        assertTrue(ProductFields.fields("Lubricante").any { it.key == "viscosidadSAE" })
        assertFalse(ProductFields.fields("Lubricante").any { it.key == "calibre" })
        assertTrue(ProductFields.fields("Repuesto").any { it.key == "calibre" })
        assertTrue(ProductFields.fields("Filtro").any { it.key == "gradoFiltracion" })
        assertEquals(listOf("No aplica; consultar especificación del fabricante"),
            ProductFields.fields("Lubricante", "ATF").first { it.key == "viscosidadSAE" }.options)
    }
}
