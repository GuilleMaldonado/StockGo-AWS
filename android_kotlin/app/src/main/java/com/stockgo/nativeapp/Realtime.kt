package com.stockgo.nativeapp

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.withTimeout
import okhttp3.*
import org.json.JSONObject
import java.io.IOException
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.TimeUnit

/** Solicitudes correlacionadas y avisos por el mismo canal autenticado. */
class Realtime(private val onEvent: (String) -> Unit) : WebSocketListener() {
    private val client = OkHttpClient.Builder().connectTimeout(12, TimeUnit.SECONDS).readTimeout(0, TimeUnit.SECONDS)
        .followRedirects(false).followSslRedirects(false).build()
    private val pending = ConcurrentHashMap<String, CompletableDeferred<JSONObject>>()
    @Volatile var ready = false
        private set
    private var socket: WebSocket? = null
    private var code = ""
    private var token = ""

    fun open(business: BusinessCode, sessionToken: String) {
        close()
        code = business.id; token = sessionToken
        val url = business.url.replaceFirst("https://", "wss://").replaceFirst("http://", "ws://") + "/ws"
        socket = client.newWebSocket(Request.Builder().url(url).build(), this)
    }
    override fun onOpen(webSocket: WebSocket, response: Response) {
        if (webSocket !== socket) { webSocket.close(1000, "Cliente inactivo"); return }
        webSocket.send(JSONObject().put("type", "auth").put("codigo", code).put("token", token).toString())
    }
    override fun onMessage(webSocket: WebSocket, text: String) {
        if (webSocket !== socket) return
        try {
            val frame = JSONObject(text)
            when (frame.optString("type")) {
                "ready" -> { ready = true; onEvent("resync") }
                "response" -> pending.remove(frame.optString("id"))?.complete(frame)
                "changed" -> onEvent(frame.optString("domain"))
                "resync" -> onEvent("resync")
                "session_invalidated" -> { ready = false; onEvent("session_invalidated") }
            }
        } catch (_: Exception) { /* Un mensaje inválido no debe cerrar la interfaz. */ }
    }
    override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) { if (webSocket === socket) lost() }
    override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
        if (webSocket !== socket) return
        if (code == 4001) {
            ready = false
            pending.values.forEach { it.completeExceptionally(ApiError(401, "La sesión expiró. Vuelve a ingresar.")) }
            pending.clear()
            onEvent("session_invalidated")
        } else lost()
    }
    override fun onClosing(webSocket: WebSocket, code: Int, reason: String) { webSocket.close(code, reason) }
    private fun lost() {
        ready = false
        pending.values.forEach { it.completeExceptionally(IOException("La conexión se interrumpió. Reintenta y revisa el historial de ventas.")) }
        pending.clear()
        onEvent("disconnected")
    }
    suspend fun request(method: String, path: String, body: JSONObject?, etag: String): JSONObject {
        val id = UUID.randomUUID().toString()
        val result = CompletableDeferred<JSONObject>()
        pending[id] = result
        try {
            if (!ready || socket?.send(JSONObject().put("type", "request").put("id", id).put("method", method)
                    .put("path", path).put("body", body ?: JSONObject()).put("etag", etag).toString()) != true) {
                throw IOException("El canal aún no está listo.")
            }
            return withTimeout(25000) { result.await() }
        } finally { pending.remove(id) }
    }
    fun close() {
        ready = false
        val old = socket; socket = null
        old?.close(1000, "Cliente inactivo")
        pending.values.forEach { it.completeExceptionally(IOException("La conexión se cerró.")) }
        pending.clear()
    }
}
