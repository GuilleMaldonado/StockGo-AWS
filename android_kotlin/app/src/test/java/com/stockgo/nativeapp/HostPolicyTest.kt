package com.stockgo.nativeapp

import org.junit.Assert.*
import org.junit.Test

class HostPolicyTest {
    @Test fun privateNetworksAndVpnNeedExplicitPermission() {
        listOf("http://192.168.0.2:8081", "http://10.0.2.2:8081", "http://127.0.0.1:8081", "http://172.16.0.1").forEach {
            assertNotNull(HostPolicy.validate(it, false))
        }
        assertNotNull(HostPolicy.validate("http://100.64.0.1:8081", true))
        assertNotNull(HostPolicy.validate("http://100.127.255.254:8081", true))
        listOf("http://100.64.0.1", "http://8.8.8.8", "http://172.32.0.1", "http://192.168.1.2.evil.test", "http://2130706433").forEach {
            assertThrows(IllegalArgumentException::class.java) { HostPolicy.validate(it, false) }
        }
        listOf("http://100.63.255.255", "http://100.128.0.1", "http://8.8.8.8", "file:///etc/passwd", "http://user:secret@192.168.0.2", "http://192.168.0.2/path", "http://192.168.0.2?secret=x").forEach {
            assertThrows(IllegalArgumentException::class.java) { HostPolicy.validate(it, true) }
        }
    }
    @Test fun protocolAllowsTlsAndRejectsAmbiguousIpv4() {
        assertNotNull(HostPolicy.validate("https://stockgo.example.org", false))
        assertFalse(HostPolicy.privateHost("192.168.000.2"))
        assertFalse(HostPolicy.privateHost("192.168.0.999"))
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
