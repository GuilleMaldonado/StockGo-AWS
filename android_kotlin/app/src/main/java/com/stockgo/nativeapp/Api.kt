package com.stockgo.nativeapp

import android.util.Base64
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URI
import java.util.concurrent.ConcurrentHashMap

class ApiError(val status: Int, message: String) : Exception(message)

object HostPolicy {
    /** El cliente cloud nunca acepta URL locales ni HTTP sin cifrar. */
    fun validate(url: String): URI {
        val uri = try { URI(url.trim()) } catch (_: Exception) { throw IllegalArgumentException("Código de conexión inválido.") }
        require(uri.scheme == "https" && !uri.host.isNullOrBlank() &&
            uri.rawUserInfo == null && uri.rawQuery == null && uri.rawFragment == null &&
            uri.path in listOf("", "/") && (uri.port == -1 || uri.port in 1..65535)) { "Dirección de servidor inválida." }
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
            HostPolicy.validate(url)
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
    private data class Cached(val raw: String, val etag: String, var instant: Long)
    private val cache = ConcurrentHashMap<String, Cached>()
    var onChange: ((String) -> Unit)? = null
    private var realtimeSupported = false
    val realtimeReady get() = realtime.ready
    private val realtime = Realtime { domain ->
        if (domain != "disconnected") cache.clear()
        onChange?.invoke(domain)
    }
    fun clearCache() { cache.clear() }
    fun resumeRealtime() { if (realtimeSupported && token.isNotEmpty()) realtime.open(business, token) }
    fun pauseRealtime() { realtime.close() }

    suspend fun request(method: String, path: String, body: JSONObject? = null): JSONObject = withContext(Dispatchers.IO) {
        HostPolicy.validate(business.url)
        val cacheable = method == "GET" && (path.startsWith("products?") || path == "sales")
        val key = "$token|$path"
        val previous = if (cacheable) cache[key] else null
        if (previous != null && System.currentTimeMillis() - previous.instant < 45000) return@withContext JSONObject(previous.raw)
        if (method != "GET") cache.clear()
        val canUseSocket = realtime.ready && path !in listOf("connect", "auth/login", "auth/guest", "auth/register")
        if (canUseSocket) {
            // Una escritura fallida nunca se reenvía automáticamente por HTTP.
            val result = realtime.request(method, path, body, previous?.etag.orEmpty())
            val status = result.getInt("status")
            if (status == 304 && previous != null) {
                previous.instant = System.currentTimeMillis(); return@withContext JSONObject(previous.raw)
            }
            val data = result.optJSONObject("data") ?: JSONObject()
            if (status >= 400) throw ApiError(status, data.optString("error", "Operación rechazada."))
            if (cacheable) {
                if (cache.size > 30) cache.clear()
                cache[key] = Cached(data.toString(), result.optString("etag"), System.currentTimeMillis())
            }
            return@withContext data
        }
        val connection = URI(business.url + "/" + path).toURL().openConnection() as HttpURLConnection
        try {
            connection.requestMethod = method
            connection.instanceFollowRedirects = false
            connection.connectTimeout = 12000
            connection.readTimeout = 25000
            connection.setRequestProperty("Content-Type", "application/json; charset=utf-8")
            connection.setRequestProperty("X-StockGo-Code", business.id)
            if (token.isNotEmpty()) connection.setRequestProperty("Authorization", "Bearer $token")
            if (!previous?.etag.isNullOrBlank()) connection.setRequestProperty("If-None-Match", previous!!.etag)
            if (body != null) {
                connection.doOutput = true
                val bytes = body.toString().toByteArray(Charsets.UTF_8)
                connection.setFixedLengthStreamingMode(bytes.size)
                connection.outputStream.use { it.write(bytes) }
            }
            val status = connection.responseCode
            if (status == 304 && previous != null) {
                previous.instant = System.currentTimeMillis(); return@withContext JSONObject(previous.raw)
            }
            if (status in 300..399) throw ApiError(status, "El servidor intentó redirigir la conexión. Revisa el código.")
            val stream = if (status >= 400) connection.errorStream else connection.inputStream
            val raw = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }.orEmpty()
            val result = try { JSONObject(raw) } catch (_: Exception) { throw IOException("El servidor no devolvió una respuesta válida.") }
            if (status >= 400) throw ApiError(status, result.optString("error", "El servidor rechazó la operación."))
            if (cacheable) {
                if (cache.size > 30) cache.clear()
                cache[key] = Cached(result.toString(), connection.getHeaderField("ETag").orEmpty(), System.currentTimeMillis())
            }
            result
        } finally {
            connection.disconnect()
        }
    }

    suspend fun connect() {
        val result = request("POST", "connect", JSONObject().put("codigo", business.id))
        name = result.optString("nombreNegocio", "StockGo")
        realtimeSupported = result.optString("websocket") == "/ws"
    }

    suspend fun login(username: String, password: String, guest: Boolean = false) {
        val result = request("POST", if (guest) "auth/guest" else "auth/login",
            if (guest) JSONObject() else JSONObject().put("usuario", username).put("password", password))
        token = result.getString("token")
        user = result.getJSONObject("usuario")
    }
}
