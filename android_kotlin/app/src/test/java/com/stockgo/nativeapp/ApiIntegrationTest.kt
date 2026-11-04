package com.stockgo.nativeapp

import kotlinx.coroutines.runBlocking
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import java.io.File
import java.util.UUID

/** Ejecuta el cliente HTTP Kotlin real contra Python y SQLite efímeros. */
class ApiIntegrationTest {
    @Test fun kotlinClientConnectsCreatesProductAndSellerSells() = runBlocking {
        val python = System.getenv("STOCKGO_TEST_PYTHON") ?: "python"
        val fixture = File("../../api/tests/fixture_server.py").canonicalFile
        require(fixture.exists()) { "No se encontró el servidor de pruebas: $fixture" }
        val process = ProcessBuilder(python, "-u", fixture.path).start()
        try {
            val line = process.inputStream.bufferedReader().readLine()
                ?: error("Python no inició: ${process.errorStream.bufferedReader().readText()}")
            val config = JSONObject(line)
            val business = BusinessCode(config.getString("url"), config.getString("codigo"), false)
            val admin = Api(business)
            admin.connect()
            assertEquals("Negocio de prueba", admin.name)
            admin.login("propietario", "Universidad123!")
            assertTrue(admin.admin)
            admin.resumeRealtime()
            repeat(200) { if (!admin.realtimeReady) kotlinx.coroutines.delay(50) }
            assertTrue("El cliente debe poder usar solicitudes WebSocket", admin.realtimeReady)
            admin.request("POST", "users", JSONObject().put("usuario", "vendedor.uno").put("password", "Vendedor123!")
                .put("nombres", "Juan").put("apellidos", "Pérez").put("rol", "vendedor"))
            val product = JSONObject().put("nombre", "Filtro aceite").put("codigo", "F-001").put("precio", 50)
                .put("costo", 30).put("cantidad", 4).put("categoria", "Filtro").put("numeroParte", "ABC123")
            val id = admin.request("POST", "products", product).getInt("id")
            val seller = Api(business)
            seller.connect(); seller.login("vendedor.uno", "Vendedor123!")
            assertTrue(seller.seller); assertFalse(seller.admin)
            val found = seller.request("GET", "products?q=F-001").getJSONArray("productos").getJSONObject(0)
            assertFalse(found.has("costo"))
            val request = JSONObject().put("solicitud", UUID.randomUUID().toString())
                .put("cliente", JSONObject().put("nombre", "Carlos Pérez").put("descripcion", "Cliente de mostrador"))
                .put("lineas", JSONArray()
                .put(JSONObject().put("productoId", id).put("cantidad", 2).put("precioEsperadoCentavos", 5000)))
            val sale = seller.request("POST", "sales", request).getJSONObject("venta")
            val retry = seller.request("POST", "sales", request).getJSONObject("venta")
            assertEquals(sale.getInt("id"), retry.getInt("id"))
            assertEquals(10000, sale.getInt("totalCentavos"))
            assertEquals("Juan Pérez", sale.getString("vendedor"))
            assertFalse(sale.getJSONArray("detalles").getJSONObject(0).has("costoCentavos"))
            assertEquals(2, admin.request("GET", "products/$id").getJSONObject("producto").getInt("cantidad"))
            assertEquals(1, seller.request("GET", "sales").getJSONArray("ventas").length())
            assertEquals("Carlos Pérez", sale.getJSONObject("cliente").getString("nombre"))
            admin.request("POST", "sales/${sale.getInt("id")}/cancel", JSONObject().put("motivo", "Cliente cancela la venta"))
            assertEquals(4, admin.request("GET", "products/$id").getJSONObject("producto").getInt("cantidad"))
            val userId = seller.user.getInt("id")
            val temporary = admin.request("POST", "users/reset-password", JSONObject().put("usuarioId", userId)
                .put("passwordAdmin", "Universidad123!")).getString("temporal")
            try { seller.request("GET", "products"); fail("Una sesión revocada no debe acceder") }
            catch (e: ApiError) { assertEquals(401, e.status) }
            seller.login("vendedor.uno", temporary)
            assertTrue(seller.mustChange)
            seller.user = seller.request("POST", "auth/password", JSONObject().put("actual", temporary)
                .put("nueva", "PersonalNueva123!")).getJSONObject("usuario")
            assertFalse(seller.mustChange)
            seller.request("GET", "products")
            seller.request("POST", "auth/logout", JSONObject())
            admin.pauseRealtime()
            Unit
        } finally {
            process.outputStream.close()
            if (!process.waitFor(20, java.util.concurrent.TimeUnit.SECONDS)) process.destroyForcibly()
        }
    }
}
