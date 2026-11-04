package com.stockgo.nativeapp

import android.util.Base64
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URI

class ApiError(val status: Int, message: String) : Exception(message)

object HostPolicy {
    fun privateHost(host: String): Boolean {
        if (host == "localhost" || host == "::1" || host == "[::1]") return true
        val bytes = ipv4(host) ?: return false
        return bytes[0] == 10 || bytes[0] == 127 ||
            (bytes[0] == 192 && bytes[1] == 168) ||
            (bytes[0] == 172 && bytes[1] in 16..31)
    }

    private fun ipv4(host: String): List<Int>? {
        if (!Regex("[0-9]+(?:\\.[0-9]+){3}").matches(host)) return null
        val parts = host.split('.').map { it.toIntOrNull() ?: return null }
        if (parts.any { it !in 0..255 } || host.split('.').any { it.length > 1 && it.startsWith('0') }) return null
        return parts
    }

    fun vpnHost(host: String): Boolean {
        val b = ipv4(host) ?: return false
        return b[0] == 100 && b[1] in 64..127
    }

    fun validate(url: String, vpn: Boolean): URI {
        val uri = try { URI(url.trim()) } catch (_: Exception) { throw IllegalArgumentException("Código de conexión inválido.") }
        require(uri.scheme in listOf("http", "https") && !uri.host.isNullOrBlank() &&
            uri.rawUserInfo == null && uri.rawQuery == null && uri.rawFragment == null &&
            uri.path in listOf("", "/") && (uri.port == -1 || uri.port in 1..65535)) { "Dirección de servidor inválida." }
        require(uri.scheme == "https" || privateHost(uri.host) || (vpn && vpnHost(uri.host))) {
            "HTTP solo se permite en Wi-Fi privada o en una VPN indicada por el código."
        }
        return uri
    }
}

data class BusinessCode(val url: String, val id: String, val vpn: Boolean) {
    companion object {
        fun parse(raw: String): BusinessCode {
            require(raw.trim().startsWith("SG1-") && raw.trim().length <= 4096) { "Pega el código completo que empieza por SG1-." }
            val json = try {
                JSONObject(String(Base64.decode(raw.trim().substring(4), Base64.URL_SAFE or Base64.NO_WRAP), Charsets.UTF_8))
            } catch (_: Exception) { throw IllegalArgumentException("Código SG1 inválido o incompleto.") }
            val url = json.getString("url")
            val id = json.getString("negocio")
            val vpn = json.optBoolean("vpn", false)
            require(Regex("[A-Fa-f0-9]{32}").matches(id)) { "Identificador de negocio inválido." }
            HostPolicy.validate(url, vpn)
            return BusinessCode(url.trimEnd('/'), id, vpn)
        }
    }
}

class Api(val business: BusinessCode) {
    var token = ""
    var user = JSONObject()
    var name = "StockGo"
    val admin get() = user.optString("rol") == "administrador"
    val seller get() = user.optString("rol") in listOf("administrador", "vendedor")
    val mustChange get() = user.optBoolean("requiereCambioPassword")

    suspend fun request(method: String, path: String, body: JSONObject? = null): JSONObject = withContext(Dispatchers.IO) {
        HostPolicy.validate(business.url, business.vpn)
        val connection = URI(business.url + "/" + path).toURL().openConnection() as HttpURLConnection
        try {
            connection.requestMethod = method
            connection.instanceFollowRedirects = false
            connection.connectTimeout = 12000
            connection.readTimeout = 25000
            connection.setRequestProperty("Content-Type", "application/json; charset=utf-8")
            connection.setRequestProperty("X-StockGo-Code", business.id)
            if (token.isNotEmpty()) connection.setRequestProperty("Authorization", "Bearer $token")
            if (body != null) {
                connection.doOutput = true
                val bytes = body.toString().toByteArray(Charsets.UTF_8)
                connection.setFixedLengthStreamingMode(bytes.size)
                connection.outputStream.use { it.write(bytes) }
            }
            val status = connection.responseCode
            if (status in 300..399) throw ApiError(status, "El servidor intentó redirigir la conexión. Revisa el código.")
            val stream = if (status >= 400) connection.errorStream else connection.inputStream
            val raw = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }.orEmpty()
            val result = try { JSONObject(raw) } catch (_: Exception) { throw IOException("El servidor no devolvió una respuesta válida.") }
            if (status >= 400) throw ApiError(status, result.optString("error", "El servidor rechazó la operación."))
            result
        } finally {
            connection.disconnect()
        }
    }

    suspend fun connect() {
        name = request("POST", "connect", JSONObject().put("codigo", business.id)).optString("nombreNegocio", "StockGo")
    }

    suspend fun login(username: String, password: String, guest: Boolean = false) {
        val result = request("POST", if (guest) "auth/guest" else "auth/login",
            if (guest) JSONObject() else JSONObject().put("usuario", username).put("password", password))
        token = result.getString("token")
        user = result.getJSONObject("usuario")
    }
}
