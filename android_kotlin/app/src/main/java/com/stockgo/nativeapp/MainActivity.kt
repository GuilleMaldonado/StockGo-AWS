package com.stockgo.nativeapp

import android.app.AlertDialog
import android.content.ClipData
import android.content.ClipboardManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.Matrix
import android.graphics.drawable.GradientDrawable
import android.media.ExifInterface
import android.os.Bundle
import android.os.Build
import android.text.Editable
import android.text.InputType
import android.text.TextWatcher
import android.util.Base64
import android.view.Gravity
import android.view.View
import android.widget.*
import androidx.activity.ComponentActivity
import androidx.activity.OnBackPressedCallback
import androidx.activity.result.contract.ActivityResultContracts
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.*
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.ByteArrayInputStream
import java.io.IOException
import java.net.URLEncoder
import java.util.Locale
import java.util.UUID
import kotlin.math.max

/** Cliente Android nativo. La autoridad es la API central de StockGo Cloud. */
class MainActivity : ComponentActivity() {
    companion object {
        // Los usuarios no escriben ni administran esta dirección. El SG1 identifica
        // el negocio y contiene esta misma URL de la nube.
        private const val CLOUD_API_URL = "https://stockgo-api-guille-618.onrender.com"
    }
    private val blue = Color.rgb(0, 115, 177)
    private val navy = Color.rgb(18, 59, 86)
    private val pale = Color.rgb(242, 248, 252)
    private val green = Color.rgb(7, 132, 92)
    private val sky = Color.rgb(56, 189, 248)
    private val yellow = Color.rgb(255, 200, 87)
    private var api: Api? = null
    private lateinit var page: LinearLayout
    private lateinit var header: LinearLayout
    private lateinit var progress: ProgressBar
    private var busy = false
    private var inventoryJob: Job? = null
    private val cart = linkedMapOf<Int, Pair<JSONObject, Int>>()
    private var saleRequest: String? = null
    private var screen = "login"
    private var imageBase64: String? = null
    private var imageLabel: TextView? = null
    private var preview: ImageView? = null
    private var imageLoading = false
    private var imageJob: Job? = null
    private var visible = false
    private var reconnectJob: Job? = null
    private var reconnectAttempt = 0
    private var eventJob: Job? = null
    private var inventoryRefresh: (() -> Unit)? = null
    private var saleClient = JSONObject()
    private val imagePicker = registerForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri != null) {
            imageLoading = true
            imageLabel?.text = "Preparando imagen…"
            imageJob = lifecycleScope.launch {
                try {
                    val encoded = withContext(Dispatchers.IO) {
                        val raw = contentResolver.openInputStream(uri)?.use { input ->
                            val output = ByteArrayOutputStream()
                            val buffer = ByteArray(8192)
                            while (true) {
                                val count = input.read(buffer)
                                if (count < 0) break
                                require(output.size() + count <= 20 * 1024 * 1024) { "La imagen original supera 20 MB." }
                                output.write(buffer, 0, count)
                            }
                            output.toByteArray()
                        } ?: throw IOException("No se pudo leer la imagen.")
                        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                        BitmapFactory.decodeByteArray(raw, 0, raw.size, bounds)
                        require(bounds.outWidth > 0 && bounds.outHeight > 0 && bounds.outWidth.toLong() * bounds.outHeight <= 150_000_000) { "Selecciona una imagen válida de tamaño moderado." }
                        var sample = 1
                        while (max(bounds.outWidth, bounds.outHeight) / sample > 2400) sample *= 2
                        val bitmap = BitmapFactory.decodeByteArray(raw, 0, raw.size, BitmapFactory.Options().apply { inSampleSize = sample })
                            ?: throw IOException("No se pudo decodificar la imagen.")
                        try {
                            // El catálogo viaja ligero: WebP y un máximo de 10 KB por imagen.
                            val scale = (800.0 / max(bitmap.width, bitmap.height)).coerceAtMost(1.0)
                            val resized = Bitmap.createScaledBitmap(bitmap, max(1, (bitmap.width * scale).toInt()), max(1, (bitmap.height * scale).toInt()), true)
                            try {
                                val orientation = try {
                                    ExifInterface(ByteArrayInputStream(raw)).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
                                } catch (_: IOException) { ExifInterface.ORIENTATION_NORMAL }
                                val matrix = Matrix().apply {
                                    when (orientation) {
                                        ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> setScale(-1f, 1f)
                                        ExifInterface.ORIENTATION_ROTATE_180 -> setRotate(180f)
                                        ExifInterface.ORIENTATION_FLIP_VERTICAL -> setScale(1f, -1f)
                                        ExifInterface.ORIENTATION_TRANSPOSE -> { setRotate(90f); postScale(-1f, 1f) }
                                        ExifInterface.ORIENTATION_ROTATE_90 -> setRotate(90f)
                                        ExifInterface.ORIENTATION_TRANSVERSE -> { setRotate(270f); postScale(-1f, 1f) }
                                        ExifInterface.ORIENTATION_ROTATE_270 -> setRotate(270f)
                                    }
                                }
                                val oriented = Bitmap.createBitmap(resized, 0, 0, resized.width, resized.height, matrix, true)
                                try {
                                    var candidate = oriented
                                    var ownsCandidate = false
                                    val output = ByteArrayOutputStream()
                                    var quality = 78
                                    while (true) {
                                        output.reset()
                                        @Suppress("DEPRECATION")
                                        candidate.compress(Bitmap.CompressFormat.WEBP, quality, output)
                                        if (output.size() <= 10 * 1024 || (candidate.width <= 128 && candidate.height <= 128)) break
                                        val next = Bitmap.createScaledBitmap(candidate, max(128, (candidate.width * 0.75).toInt()), max(128, (candidate.height * 0.75).toInt()), true)
                                        if (ownsCandidate) candidate.recycle()
                                        candidate = next; ownsCandidate = true; quality = max(40, quality - 8)
                                    }
                                    if (ownsCandidate) candidate.recycle()
                                    require(output.size() <= 10 * 1024) { "No fue posible reducir la imagen a 10 KB. Elige una fotografía más simple." }
                                    Base64.encodeToString(output.toByteArray(), Base64.NO_WRAP)
                                } finally { if (oriented !== resized) oriented.recycle() }
                            } finally { if (resized !== bitmap) resized.recycle() }
                        } finally { bitmap.recycle() }
                    }
                    imageBase64 = encoded
                    imageLabel?.text = "Imagen WebP lista (${encoded.length * 3 / 4 / 1024} KB)"
                    preview?.let { showImage(it, encoded) }
                } catch (e: CancellationException) { throw e
                } catch (e: Exception) {
                    imageLabel?.text = if (imageBase64 == null) "Sin imagen" else "Se conserva la imagen anterior"
                    message(e.message ?: "No se pudo cargar la imagen.")
                } finally { imageLoading = false }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                if (busy || imageLoading) return
                if (api?.token?.isNotEmpty() == true) {
                    if (api!!.mustChange) logout() else if (screen == "home") logout() else home()
                } else login()
            }
        })
        login()
    }
    override fun onStart() {
        super.onStart(); visible = true
        if (api?.token?.isNotEmpty() == true) setupRealtime()
    }
    override fun onStop() {
        visible = false; reconnectJob?.cancel(); eventJob?.cancel(); api?.pauseRealtime()
        super.onStop()
    }
    private fun setupRealtime() {
        api?.onChange = { domain -> runOnUiThread {
            if (visible) {
                if (domain == "disconnected") {
                    if (reconnectJob?.isActive != true) reconnectJob = lifecycleScope.launch {
                        delay(((1L shl reconnectAttempt.coerceAtMost(5)).coerceAtMost(30) * 1000) + (0..1000).random())
                        reconnectAttempt++; api?.resumeRealtime()
                    }
                } else if (domain == "session_invalidated") {
                    api?.pauseRealtime(); api?.token = ""; cart.clear(); saleRequest = null; saleClient = JSONObject(); login()
                    message("Tu sesión cambió. Vuelve a ingresar.")
                } else {
                    reconnectAttempt = 0
                    eventJob?.cancel()
                    eventJob = lifecycleScope.launch {
                        delay(750) // Agrupa los avisos de inventario y ventas de una misma transacción.
                        if (!busy && visible) when (screen) {
                            "inventory" -> inventoryRefresh?.invoke()
                            "reports" -> if (domain in listOf("sales", "resync")) reports()
                            "team" -> if (domain in listOf("users", "resync")) team()
                        }
                    }
                }
            }
        } }
        if (visible) api?.resumeRealtime()
    }

    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()
    private fun shape(color: Int, radius: Int = 24) = GradientDrawable().apply {
        setColor(color); cornerRadius = dp(radius).toFloat()
        setStroke(dp(1), Color.rgb(215, 231, 241))
    }
    private fun text(value: String, size: Float = 16f, bold: Boolean = false) = TextView(this).apply {
        text = value; textSize = size; setTextColor(navy)
        if (bold) setTypeface(typeface, Typeface.BOLD)
        setPadding(0, dp(5), 0, dp(5))
    }
    private fun reset(title: String, subtitle: String = "", module: String = "") {
        inventoryJob?.cancel()
        screen = module
        val root = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setBackgroundColor(pale) }
        root.setOnApplyWindowInsetsListener { v, insets ->
            @Suppress("DEPRECATION")
            v.setPadding(insets.systemWindowInsetLeft, insets.systemWindowInsetTop, insets.systemWindowInsetRight, insets.systemWindowInsetBottom)
            insets
        }
        header = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL; setPadding(dp(22), dp(18), dp(22), dp(15))
            background = GradientDrawable(GradientDrawable.Orientation.TL_BR, intArrayOf(navy, blue))
        }
        header.addView(text(title, 26f, true).apply { setTextColor(Color.WHITE) })
        if (subtitle.isNotEmpty()) header.addView(text(subtitle, 14f).apply { setTextColor(Color.rgb(216, 239, 255)) })
        root.addView(header)
        progress = ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply { isIndeterminate = true; visibility = View.GONE }
        root.addView(progress, LinearLayout.LayoutParams(-1, dp(4)))
        val scroll = ScrollView(this).apply { isFillViewport = true }
        page = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(dp(18), dp(16), dp(18), dp(28)) }
        scroll.addView(page)
        root.addView(scroll, LinearLayout.LayoutParams(-1, 0, 1f))
        setContentView(root)
        root.requestApplyInsets()
        page.alpha = 0f
        page.animate().alpha(1f).setDuration(180).start()
        if (api?.token?.isNotEmpty() == true && api?.mustChange == false) {
            val menu = text("Módulos  ▾", 15f, true).apply { setTextColor(Color.WHITE); gravity = Gravity.END }
            header.addView(menu)
            menu.setOnClickListener {
                if (!busy && !imageLoading) {
                    val popup = PopupMenu(this, menu)
                    val modules = mutableListOf("Inicio", "Inventario")
                    if (api!!.seller) modules.addAll(listOf("Nueva venta", "Cuenta actual", "Historial y estadísticas", "Mi perfil", "Cambiar contraseña"))
                    if (api!!.admin) modules.addAll(listOf("Vendedores y equipo", "Invitar al negocio", "Historial de seguridad"))
                    modules.add("Cerrar sesión")
                    modules.forEach { popup.menu.add(it) }
                    popup.setOnMenuItemClickListener { item ->
                        when (item.title.toString()) {
                            "Inicio" -> home()
                            "Inventario" -> inventory()
                            "Nueva venta" -> inventory()
                            "Cuenta actual" -> cartScreen()
                            "Historial y estadísticas" -> reports()
                            "Mi perfil" -> profile()
                            "Cambiar contraseña" -> passwordScreen()
                            "Vendedores y equipo" -> team()
                            "Invitar al negocio" -> invite()
                            "Historial de seguridad" -> audit()
                            "Cerrar sesión" -> logout()
                        }; true
                    }
                    popup.show()
                }
            }
        }
    }
    private fun section(parent: LinearLayout = page, title: String, subtitle: String = ""): LinearLayout {
        val box = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL; setPadding(dp(16), dp(14), dp(16), dp(16))
            background = shape(Color.WHITE); elevation = dp(2).toFloat()
        }
        parent.addView(box, LinearLayout.LayoutParams(-1, -2).apply { bottomMargin = dp(16) })
        box.addView(text(title, 20f, true))
        if (subtitle.isNotEmpty()) box.addView(text(subtitle, 14f))
        return box
    }
    private fun gradientSection(parent: LinearLayout, title: String, subtitle: String): LinearLayout {
        val box = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL; setPadding(dp(24), dp(24), dp(24), dp(24))
            background = GradientDrawable(GradientDrawable.Orientation.TL_BR, intArrayOf(navy, blue, sky)).apply { cornerRadius = dp(26).toFloat() }
            elevation = dp(5).toFloat()
        }
        parent.addView(box, LinearLayout.LayoutParams(-1, -2).apply { bottomMargin = dp(20) })
        box.addView(text("STOCKGO · TU NEGOCIO", 11f, true).apply { setTextColor(Color.rgb(186, 230, 253)); letterSpacing = .12f })
        box.addView(text(title, 27f, true).apply { setTextColor(Color.WHITE); setPadding(0, dp(12), 0, dp(4)) })
        box.addView(text(subtitle, 15f).apply { setTextColor(Color.rgb(221, 243, 255)); setPadding(0, 0, 0, dp(10)) })
        return box
    }
    private fun metric(parent: LinearLayout, symbol: String, value: String, label: String, color: Int) {
        val card = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(dp(13), dp(13), dp(13), dp(13)); background = shape(Color.WHITE) }
        parent.addView(card, LinearLayout.LayoutParams(0, -2, 1f).apply { marginEnd = dp(7) })
        val icon = TextView(this).apply { text = symbol; textSize = 20f; gravity = Gravity.CENTER; setTextColor(Color.WHITE); background = shape(color, 13); setPadding(dp(7), dp(5), dp(7), dp(5)) }
        card.addView(icon, LinearLayout.LayoutParams(dp(40), dp(40)))
        card.addView(text(value, 23f, true).apply { setPadding(0, dp(9), 0, 0) })
        card.addView(text(label, 11f).apply { setTextColor(Color.rgb(84, 112, 132)); setPadding(0, 0, 0, 0) })
    }
    private fun moduleCard(parent: LinearLayout, symbol: String, title: String, subtitle: String, color: Int, action: () -> Unit) {
        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL; gravity = Gravity.CENTER; setPadding(dp(16), dp(18), dp(16), dp(16)); background = shape(Color.WHITE)
            isClickable = true; isFocusable = true; setOnClickListener { if (!busy && !imageLoading) action() }
        }
        parent.addView(card, LinearLayout.LayoutParams(0, dp(184), 1f).apply { marginEnd = dp(8); bottomMargin = dp(16) })
        val badge = TextView(this).apply { text = symbol; textSize = 25f; gravity = Gravity.CENTER; setTextColor(Color.WHITE); background = shape(color, 17) }
        card.addView(badge, LinearLayout.LayoutParams(dp(58), dp(58)))
        card.addView(text(title, 16f, true).apply { gravity = Gravity.CENTER; setPadding(0, dp(14), 0, dp(2)) })
        card.addView(text(subtitle, 12f).apply { gravity = Gravity.CENTER; setTextColor(Color.rgb(84, 112, 132)); setPadding(0, 0, 0, 0) })
    }
    private fun button(parent: LinearLayout, label: String, color: Int = blue, onClick: () -> Unit): Button {
        val button = Button(this).apply {
            text = label; isAllCaps = false; textSize = 15f; setTextColor(Color.WHITE)
            background = shape(color, 14); minHeight = dp(48)
            setPadding(dp(12), dp(10), dp(12), dp(10))
            setOnClickListener { if (!busy && !imageLoading) onClick() }
        }
        parent.addView(button, LinearLayout.LayoutParams(-1, -2).apply { topMargin = dp(10) })
        return button
    }
    private fun field(parent: LinearLayout, label: String, initial: String = "", password: Boolean = false, numeric: Boolean = false, options: List<String> = emptyList()): EditText {
        parent.addView(text(label, 14f, true))
        val input = if (options.isEmpty()) EditText(this) else AutoCompleteTextView(this).apply {
            setAdapter(ArrayAdapter(this@MainActivity, android.R.layout.simple_dropdown_item_1line, options))
            threshold = 0
            setOnClickListener { showDropDown() }
        }
        input.apply {
            setText(initial); textSize = 16f; setTextColor(navy)
            inputType = when {
                password -> InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD
                numeric -> InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_FLAG_DECIMAL
                else -> InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_CAP_SENTENCES
            }
            maxLines = if (label.contains("Descripción") || label.contains("compatibles")) 5 else 2
            background = shape(Color.rgb(239, 247, 253), 14)
            setPadding(dp(14), dp(12), dp(14), dp(12))
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                importantForAutofill = if (password) View.IMPORTANT_FOR_AUTOFILL_NO else View.IMPORTANT_FOR_AUTOFILL_AUTO
            }
        }
        parent.addView(input, LinearLayout.LayoutParams(-1, -2).apply { bottomMargin = dp(12) })
        return input
    }
    private fun message(value: String) { AlertDialog.Builder(this).setTitle("StockGo").setMessage(value).setPositiveButton("Entendido", null).show() }
    private fun copy(value: String) {
        (getSystemService(CLIPBOARD_SERVICE) as ClipboardManager).setPrimaryClip(ClipData.newPlainText("StockGo", value))
        Toast.makeText(this, "Copiado", Toast.LENGTH_SHORT).show()
    }
    private fun money(cents: Long) = String.format(Locale.US, "%.2f", cents / 100.0)
    private fun action(block: suspend () -> Unit) {
        if (busy) return
        busy = true; progress.visibility = View.VISIBLE
        lifecycleScope.launch {
            try { block()
            } catch (e: CancellationException) { throw e
            } catch (e: ApiError) {
                if (e.status == 401) {
                    api?.token = ""; cart.clear(); saleRequest = null; login()
                }
                message(e.message ?: "No se pudo completar la operación.")
            } catch (e: Exception) {
                message(e.message ?: "No hay conexión con StockGo Cloud. Comprueba tu acceso a internet e inténtalo de nuevo.")
            } finally { busy = false; progress.visibility = View.GONE }
        }
    }

    private fun login() {
        reset("StockGo", "Inventario y ventas · Android nativo", "login")
        val preferences = getSharedPreferences("stockgo", MODE_PRIVATE)
        val hero = gradientSection(page, "Menos pendientes.\nMás control.", "Todo tu inventario en un solo lugar, simple, ordenado y siempre contigo.")
        listOf("✓  Productos organizados", "✓  Acceso según tu rol", "✓  Información protegida en la nube").forEach { hero.addView(text(it, 14f).apply { setTextColor(Color.WHITE) }) }
        val box = section(title = "Bienvenido de nuevo", subtitle = "El administrador entra con su negocio. El vendedor entra solo con su usuario y contraseña.")
        val roles = RadioGroup(this).apply { orientation = RadioGroup.HORIZONTAL }
        val administrator = RadioButton(this).apply { id = View.generateViewId(); text = "Administrador"; isChecked = true }
        val seller = RadioButton(this).apply { id = View.generateViewId(); text = "Vendedor" }
        roles.addView(administrator, LinearLayout.LayoutParams(0, -2, 1f)); roles.addView(seller, LinearLayout.LayoutParams(0, -2, 1f)); box.addView(roles)
        val businessArea = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }; box.addView(businessArea)
        val business = field(businessArea, "Nombre del negocio")
        val username = field(box, "Usuario")
        val password = field(box, "Contraseña", password = true)
        fun updateRole() {
            businessArea.visibility = if (administrator.isChecked) View.VISIBLE else View.GONE
        }
        roles.setOnCheckedChangeListener { _, _ -> updateRole() }; updateRole()
        button(box, "Iniciar sesión  →") {
            action {
                if (administrator.isChecked) {
                    val bootstrap = Api(BusinessCode(CLOUD_API_URL, "00000000000000000000000000000000", false))
                    val result = bootstrap.request("POST", "auth/admin-login", JSONObject().put("negocio", business.text.toString().trim()).put("usuario", username.text.toString().trim()).put("password", password.text.toString()))
                    val sg1 = result.getString("sg1")
                    val client = Api(BusinessCode.parse(sg1)).apply {
                        token = result.getString("token"); user = result.getJSONObject("usuario"); name = result.getString("nombreNegocio")
                    }
                    preferences.edit().putString("codigo", sg1).apply(); api = client
                } else {
                    val bootstrap = Api(BusinessCode(CLOUD_API_URL, "00000000000000000000000000000000", false))
                    val result = bootstrap.request("POST", "auth/user-login", JSONObject().put("usuario", username.text.toString().trim()).put("password", password.text.toString()))
                    val sg1 = result.getString("sg1")
                    val client = Api(BusinessCode.parse(sg1)).apply {
                        token = result.getString("token"); user = result.getJSONObject("usuario"); name = result.getString("nombreNegocio")
                    }
                    preferences.edit().putString("codigo", sg1).apply(); api = client
                }
                afterLogin()
            }
        }
        button(box, "Continuar como invitado", green) {
            guestLogin()
        }
        page.addView(text("Los datos y permisos se guardan en StockGo Cloud. Tu teléfono nunca funciona como servidor.", 14f))
        button(page, "Recuperar contraseña", navy) { recovery() }
        button(page, "¿Nuevo por aquí? Crear cuenta", navy) { registration() }
    }

    private fun guestLogin() {
        val code = EditText(this).apply { hint = "Código completo SG1"; inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_MULTI_LINE }
        AlertDialog.Builder(this).setTitle("Entrar como invitado").setMessage("El acceso de invitado necesita el código SG1 del negocio.")
            .setView(code).setNegativeButton("Cancelar", null).setPositiveButton("Entrar") { _, _ -> action {
                val client = Api(BusinessCode.parse(code.text.toString())); client.connect(); client.login("", "", true); api = client; afterLogin()
            } }.show()
    }

    /** Mismo flujo de la versión StockGo original, ahora respaldado por Render. */
    private fun registration() {
        reset("Crear cuenta", "Elige si crearás el negocio o si te unirás como vendedor.", "register")
        val box = section(title = "Empieza con StockGo", subtitle = "Cada persona usa su propia cuenta; el código SG1 solo identifica el negocio.")
        val choices = RadioGroup(this).apply { orientation = RadioGroup.HORIZONTAL }
        val vendorChoice = RadioButton(this).apply { text = "Soy vendedor"; id = View.generateViewId(); isChecked = true }
        val ownerChoice = RadioButton(this).apply { text = "Crear mi negocio"; id = View.generateViewId() }
        choices.addView(vendorChoice, LinearLayout.LayoutParams(0, -2, 1f)); choices.addView(ownerChoice, LinearLayout.LayoutParams(0, -2, 1f)); box.addView(choices)
        val explanation = text("Pega el código SG1 compartido por el administrador para crear tu cuenta de vendedor.", 13f).apply { setTextColor(Color.rgb(84, 112, 132)); setPadding(0, dp(6), 0, dp(16)) }
        box.addView(explanation)
        val ownerArea = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        box.addView(ownerArea)
        val business = field(ownerArea, "Nombre único de la empresa")
        val vendorArea = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        box.addView(vendorArea)
        val code = field(vendorArea, "Código de negocio SG1", getSharedPreferences("stockgo", MODE_PRIVATE).getString("codigo", "").orEmpty())
        code.inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_MULTI_LINE
        val first = field(box, "Nombres")
        val last = field(box, "Apellidos")
        val user = field(box, "Usuario (sin números)")
        val pass = field(box, "Contraseña (8 a 128 caracteres)", password = true)
        val confirm = field(box, "Repite la contraseña", password = true)
        fun updateChoice(owner: Boolean) {
            ownerArea.visibility = if (owner) View.VISIBLE else View.GONE
            vendorArea.visibility = if (owner) View.GONE else View.VISIBLE
            explanation.text = if (owner) "Serás el administrador y recibirás el código SG1 para compartir con tus vendedores." else "Pega el código SG1 compartido por el administrador para crear tu cuenta de vendedor."
        }
        choices.setOnCheckedChangeListener { _, checked -> updateChoice(checked == ownerChoice.id) }
        updateChoice(false)
        button(box, "Crear cuenta", green) {
            action {
                require(pass.text.toString() == confirm.text.toString()) { "Las contraseñas no coinciden." }
                val payload = JSONObject().put("nombres", first.text.toString()).put("apellidos", last.text.toString())
                    .put("usuario", user.text.toString()).put("password", pass.text.toString())
                if (ownerChoice.isChecked) {
                    payload.put("negocio", business.text.toString())
                    val bootstrap = Api(BusinessCode(CLOUD_API_URL, "00000000000000000000000000000000", false))
                    val result = bootstrap.request("POST", "businesses", payload)
                    val sg1 = result.getString("sg1")
                    getSharedPreferences("stockgo", MODE_PRIVATE).edit().putString("codigo", sg1).apply()
                    api = Api(BusinessCode.parse(sg1)); api!!.connect()
                    showNewBusinessCode(result.getString("nombreNegocio"), sg1)
                } else {
                    val client = Api(BusinessCode.parse(code.text.toString()))
                    client.connect(); client.request("POST", "auth/register", payload)
                    getSharedPreferences("stockgo", MODE_PRIVATE).edit().putString("codigo", code.text.toString().trim()).apply()
                    api = client
                    message("Cuenta creada. Ahora inicia sesión con tu usuario y contraseña.")
                    login()
                }
            }
        }
        button(page, "Volver", navy) { login() }
    }
    private fun createBusiness() {
        reset("Crear negocio", "Registra tu negocio en StockGo Cloud y recibe su código SG1.", "business")
        val box = section(title = "Datos del administrador inicial")
        val business = field(box, "Nombre único del negocio")
        val first = field(box, "Nombres")
        val last = field(box, "Apellidos")
        val user = field(box, "Usuario (sin números)")
        val password = field(box, "Contraseña (8 a 128 caracteres)", password = true)
        val confirm = field(box, "Repite la contraseña", password = true)
        button(box, "Crear negocio y conectar", green) {
            action {
                require(password.text.toString() == confirm.text.toString()) { "Las contraseñas no coinciden." }
                val bootstrap = Api(BusinessCode(CLOUD_API_URL, "00000000000000000000000000000000", false))
                val payload = JSONObject().put("negocio", business.text.toString()).put("nombres", first.text.toString())
                    .put("apellidos", last.text.toString()).put("usuario", user.text.toString()).put("password", password.text.toString())
                val result = bootstrap.request("POST", "businesses", payload)
                val sg1 = result.getString("sg1")
                getSharedPreferences("stockgo", MODE_PRIVATE).edit().putString("codigo", sg1).apply()
                api = Api(BusinessCode.parse(sg1)); api!!.connect()
                showNewBusinessCode(result.getString("nombreNegocio"), sg1)
            }
        }
        button(page, "Volver", navy) { login() }
    }
    private fun showNewBusinessCode(name: String, sg1: String) {
        val code = TextView(this).apply {
            text = sg1; textSize = 14f; setTextColor(navy); setTextIsSelectable(true)
            setPadding(dp(18), dp(12), dp(18), dp(12)); background = shape(Color.rgb(232, 244, 253), 14)
        }
        AlertDialog.Builder(this).setTitle("Negocio creado · $name")
            .setMessage("Guarda este código SG1. Identifica tu negocio para iniciar sesión y conectar vendedores.")
            .setView(code).setNegativeButton("Copiar") { _, _ -> copy(sg1) }
            .setPositiveButton("Ir al acceso principal") { _, _ -> login() }.show()
    }
    private fun credentials() {
        reset(api!!.name, "Conexión establecida · elige tu acceso", "login")
        val box = section(title = "Bienvenido de nuevo")
        val username = field(box, "Usuario")
        username.inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD
        val password = field(box, "Contraseña", password = true)
        button(box, "Iniciar sesión →") {
            action { api!!.login(username.text.toString().trim(), password.text.toString()); afterLogin() }
        }
        button(box, "Crear mi cuenta de vendedor", navy) { register() }
        button(box, "Continuar como invitado", green) { action { api!!.login("", "", true); afterLogin() } }
        button(page, "Recuperar contraseña", navy) { recovery() }
        button(page, "Cambiar de negocio", navy) { api = null; login() }
    }
    private fun recovery() {
        reset("Recuperar contraseña", "Solicita ayuda al administrador del negocio", "recovery")
        val box = section(title = "Solicitar recuperación", subtitle = "Por seguridad no confirmamos si una cuenta existe. El administrador genera una clave temporal.")
        val code = field(box, "Código completo SG1", getSharedPreferences("stockgo", MODE_PRIVATE).getString("codigo", "").orEmpty())
        code.inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_MULTI_LINE
        val username = field(box, "Usuario")
        button(box, "Enviar solicitud", green) {
            action {
                val client = Api(BusinessCode.parse(code.text.toString()))
                client.request("POST", "auth/recovery-request", JSONObject().put("usuario", username.text.toString().trim()))
                getSharedPreferences("stockgo", MODE_PRIVATE).edit().putString("codigo", code.text.toString().trim()).apply()
                message("Solicitud enviada. Contacta al administrador para recibir una clave temporal.")
                login()
            }
        }
        button(page, "Volver", navy) { if (api == null) login() else credentials() }
    }
    private fun pendingKey() = "${api!!.business.id}_${api!!.user.optInt("id") }"
    private fun restorePending() {
        val raw = getSharedPreferences("ventas_pendientes", MODE_PRIVATE).getString(pendingKey(), null) ?: return
        try {
            val saved = JSONObject(raw)
            saleRequest = saved.getString("solicitud")
            saleClient = saved.optJSONObject("cliente") ?: JSONObject()
            cart.clear()
            val lines = saved.getJSONArray("productos")
            for (i in 0 until lines.length()) {
                val entry = lines.getJSONObject(i)
                val product = entry.getJSONObject("producto")
                cart[product.getInt("id")] = product to entry.getInt("cantidad")
            }
        } catch (_: Exception) {
            message("No se pudo recuperar la cuenta pendiente. Consulta el historial antes de repetir una venta.")
        }
    }
    private suspend fun persistPending() {
        val products = JSONArray()
        cart.values.forEach { (product, quantity) ->
            // Solo el resumen de la cuenta, sin fotografías ni datos de compra.
            val snapshot = JSONObject()
            listOf("id", "nombre", "codigo", "precio", "lote", "unidadVenta").forEach { key -> snapshot.put(key, product.opt(key)) }
            products.put(JSONObject().put("producto", snapshot).put("cantidad", quantity))
        }
        val raw = JSONObject().put("solicitud", saleRequest).put("productos", products).put("cliente", saleClient).toString()
        val key = pendingKey()
        withContext(Dispatchers.IO) {
            check(getSharedPreferences("ventas_pendientes", MODE_PRIVATE).edit().putString(key, raw).commit()) {
                "No se pudo guardar el comprobante de reintento. Libera espacio antes de vender."
            }
        }
    }
    private fun clearPending() {
        getSharedPreferences("ventas_pendientes", MODE_PRIVATE).edit().remove(pendingKey()).apply()
        saleRequest = null
    }
    private fun afterLogin() {
        setupRealtime()
        if (api!!.mustChange) passwordScreen()
        else { restorePending(); home() }
    }
    private fun register(adminCreate: Boolean = false) {
        reset(if (adminCreate) "Crear integrante" else "Crear cuenta", api!!.name, "register")
        val box = section(title = if (adminCreate) "Equipo del negocio" else "Registro de vendedor")
        val first = field(box, "Nombres")
        val last = field(box, "Apellidos")
        val user = field(box, "Usuario (letras, puntos y guiones; sin números)")
        val pass = field(box, "Contraseña (8 a 128 caracteres)", password = true)
        val confirm = field(box, "Repite la contraseña", password = true)
        var role = "vendedor"
        if (adminCreate) {
            val spinner = Spinner(this)
            spinner.adapter = ArrayAdapter(this, android.R.layout.simple_spinner_dropdown_item, listOf("Vendedor", "Administrador"))
            spinner.onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
                override fun onItemSelected(p: AdapterView<*>?, v: View?, pos: Int, id: Long) { role = if (pos == 0) "vendedor" else "administrador" }
                override fun onNothingSelected(p: AdapterView<*>?) = Unit
            }
            box.addView(spinner)
        }
        button(box, "Crear cuenta", green) {
            if (pass.text.toString() != confirm.text.toString()) message("Las contraseñas no coinciden.")
            else action {
                api!!.request("POST", if (adminCreate) "users" else "auth/register", JSONObject()
                    .put("usuario", user.text.toString().trim()).put("password", pass.text.toString())
                    .put("nombres", first.text.toString().trim()).put("apellidos", last.text.toString().trim()).put("rol", role))
                if (adminCreate) page.post { team() } else credentials()
                Toast.makeText(this, "Cuenta creada", Toast.LENGTH_LONG).show()
            }
        }
        button(page, "Volver", navy) { if (adminCreate) team() else credentials() }
    }

    private fun home() {
        reset(api!!.name, "${api!!.user.optString("nombres")} ${api!!.user.optString("apellidos")} · ${api!!.user.optString("rol")}", "home")
        val hero = gradientSection(page, "Todo tu negocio,\nen un solo lugar.", "Consulta productos, controla existencias y trabaja con tu equipo desde cualquier dispositivo.")
        button(hero, "Ver catálogo", Color.WHITE) { inventory() }.apply { setTextColor(blue) }
        val metrics = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        page.addView(metrics, LinearLayout.LayoutParams(-1, -2).apply { bottomMargin = dp(20) })
        metric(metrics, "▣", "${cart.size}", "En cuenta", blue)
        metric(metrics, "◈", if (api!!.seller) "Ventas" else "Stock", if (api!!.seller) "Tu operación" else "Inventario", green)
        metric(metrics, "⌁", if (api!!.admin) "SG1" else "Vista", if (api!!.admin) "Equipo conectado" else "Consulta", yellow)
        page.addView(text("Tu espacio de trabajo", 21f, true))
        page.addView(text("Elige lo que necesitas hacer hoy.", 13f).apply { setTextColor(Color.rgb(84, 112, 132)); setPadding(0, 0, 0, dp(14)) })
        fun row() = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }.also { page.addView(it) }
        var current = row()
        moduleCard(current, "▣", if (api!!.admin) "Gestionar productos" else "Consultar productos", "Catálogo, fotos y existencias.", blue) { inventory() }
        if (api!!.seller) moduleCard(current, "＋", "Nueva venta", "Elige productos, arma la cuenta y confirma la venta.", green) { inventory() }
        else { val empty = Space(this); current.addView(empty, LinearLayout.LayoutParams(0, 1, 1f)) }
        if (api!!.seller) {
            current = row()
            moduleCard(current, "▤", "Cuenta actual", "${cart.size} productos listos para vender.", blue) { cartScreen() }
            moduleCard(current, "◈", "Historial y estadísticas", "Ventas y productividad.", sky) { reports() }
        }
        if (api!!.admin) {
            current = row()
            moduleCard(current, "♟", "Vendedores y equipo", "Gestiona cuentas y permisos.", blue) { team() }
            moduleCard(current, "⌁", "Compartir código SG1", "Conecta vendedores a este negocio.", green) { invite() }
        }
        if (saleRequest != null) page.addView(text("Hay una venta pendiente. Abre Cuenta actual para reintentar.", 14f, true))
        button(page, "Cerrar sesión", navy) { logout() }
    }
    private fun inventory() {
        reset("Inventario", api!!.name, "inventory")
        val search = field(page, "Buscar nombre, código, marca o número de parte")
        val inactive = CheckBox(this).apply { text = "Mostrar productos desactivados" }
        if (api!!.admin) {
            page.addView(inactive)
            button(page, "+ Agregar producto", green) { productForm(null) }
        }
        val list = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        page.addView(list, LinearLayout.LayoutParams(-1, -2).apply { topMargin = dp(16) })
        var nextCursor: Int? = null
        val more = Button(this).apply { text = "Cargar más productos"; isAllCaps = false; visibility = View.GONE }
        fun reload(append: Boolean = false) {
            inventoryJob?.cancel()
            inventoryJob = lifecycleScope.launch {
                delay(if (append) 0 else 600)
                try {
                    val cursor = if (append) nextCursor ?: 0 else 0
                    val result = api!!.request("GET", "products?q=${URLEncoder.encode(search.text.toString().trim(), "UTF-8")}&inactivos=${inactive.isChecked}&limit=50&cursor=$cursor")
                    if (!append) list.removeAllViews()
                    nextCursor = if (result.isNull("nextCursor")) null else result.optInt("nextCursor")
                    more.visibility = if (nextCursor == null) View.GONE else View.VISIBLE
                    val products = result.getJSONArray("productos")
                    if (products.length() == 0) list.addView(text("No hay productos. ${if (api!!.admin) "Agrega el primero para comenzar." else "Consulta al administrador."}"))
                    for (i in 0 until products.length()) {
                        val p = products.getJSONObject(i)
                        val card = section(list, p.getString("nombre"), "${p.getString("codigo")} · ${p.optString("categoria")} · ${if (active(p)) "Activo" else "Desactivado"}")
                        if (!p.isNull("imagen")) {
                            val image = ImageView(this@MainActivity).apply { scaleType = ImageView.ScaleType.CENTER_CROP; contentDescription = "Imagen del producto" }
                            card.addView(image, LinearLayout.LayoutParams(-1, dp(150)))
                            showImage(image, p.getString("imagen"))
                        }
                        card.addView(text("Precio ${money(price(p))}  ·  Disponibles ${p.getInt("cantidad")}", 17f, true))
                        card.addView(text("${p.optString("marca")}  ${p.optString("lote").let { if (it.isEmpty()) "" else "Lote $it" }}", 14f))
                        button(card, "Ver ficha") { productDetail(p) }
                        if (api!!.seller && active(p)) button(card, "Agregar a la cuenta", green) { addToCart(p) }
                    }
                } catch (e: CancellationException) { throw e
                } catch (e: ApiError) {
                    if (e.status == 401) { api?.token = ""; cart.clear(); saleRequest = null; login() }
                    else { list.removeAllViews(); list.addView(text(e.message.orEmpty())) }
                } catch (_: Exception) { list.removeAllViews(); list.addView(text("No se pudo cargar el inventario desde StockGo Cloud.")) }
            }
        }
        inventoryRefresh = { api?.clearCache(); reload() }
        search.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) = Unit
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) { reload() }
            override fun afterTextChanged(s: Editable?) = Unit
        })
        inactive.setOnCheckedChangeListener { _, _ -> reload() }
        page.addView(more)
        more.setOnClickListener { if (!busy) reload(true) }
        button(page, "Actualizar inventario") { api?.clearCache(); reload() }
        if (api!!.seller) button(page, "Ver cuenta (${cart.size} productos)", navy) { cartScreen() }
        reload()
    }
    private fun active(p: JSONObject) = p.opt("activo") == true || p.optInt("activo") == 1
    private fun price(p: JSONObject) = Math.round(p.getDouble("precio") * 100)
    private fun showImage(view: ImageView, data: String) {
        lifecycleScope.launch {
            val bitmap = withContext(Dispatchers.IO) {
                try {
                    val bytes = Base64.decode(data, Base64.DEFAULT)
                    BitmapFactory.decodeByteArray(bytes, 0, bytes.size, BitmapFactory.Options().apply { inSampleSize = 2 })
                } catch (_: Exception) { null }
            }
            view.setImageBitmap(bitmap)
        }
    }
    private fun productDetail(p: JSONObject) {
        action {
            val detail = api!!.request("GET", "products/${p.getInt("id")}").optJSONObject("producto")
                ?: throw IllegalArgumentException("El producto ya no está disponible.")
            showProductDetail(detail)
        }
    }
    private fun showProductDetail(p: JSONObject) {
        reset(p.getString("nombre"), p.getString("codigo"), "detail")
        val box = section(title = "Ficha de ${p.optString("categoria").lowercase()}", subtitle = "Precio ${money(price(p))} · Disponible ${p.getInt("cantidad")}")
        if (!p.isNull("imagen")) {
            val image = ImageView(this).apply { scaleType = ImageView.ScaleType.FIT_CENTER; contentDescription = "Imagen del producto" }
            box.addView(image, LinearLayout.LayoutParams(-1, dp(190)).apply { gravity = Gravity.CENTER_HORIZONTAL })
            showImage(image, p.getString("imagen"))
        }
        ProductFields.fields(p.optString("categoria"), p.optString("tipo")).forEach {
            if (it.key != "proveedor" || api!!.admin) {
                val value = p.optString(it.key)
                if (value.isNotEmpty()) box.addView(text("${it.label}: $value"))
            }
        }
        if (api!!.admin && active(p)) {
            button(page, "Editar producto") { productForm(p) }
            button(page, "Eliminar / desactivar producto", Color.rgb(164, 55, 55)) {
                AlertDialog.Builder(this).setTitle("¿Desactivar producto?").setMessage("Se conservarán su ficha y el historial de ventas.")
                    .setNegativeButton("Cancelar", null).setPositiveButton("Desactivar") { _, _ -> action {
                        api!!.request("POST", "products/${p.getInt("id")}/deactivate", JSONObject()); inventory()
                    } }.show()
            }
        }
        if (api!!.seller && active(p)) button(page, "Agregar a la cuenta", green) { addToCart(p) }
    }

    private fun productForm(original: JSONObject?) {
        reset(if (original == null) "Agregar producto" else "Editar producto", api!!.name, "form")
        imageBase64 = if (original == null || original.isNull("imagen")) null else original.getString("imagen")
        val basics = section(title = "1. Identifica el producto")
        val name = field(basics, "Nombre del producto", original?.optString("nombre").orEmpty())
        val code = field(basics, "Código de inventario (uno por lote)", original?.optString("codigo").orEmpty())
        val category = Spinner(this).apply { adapter = ArrayAdapter(this@MainActivity, android.R.layout.simple_spinner_dropdown_item, ProductFields.categories) }
        basics.addView(text("Categoría", 14f, true)); basics.addView(category)
        val prices = section(title = "2. Precios y existencias", subtitle = "Venta ≥ compra. Máximo dos decimales; cantidad en unidades de venta enteras.")
        val cost = field(prices, "Precio de compra", original?.optString("costo") ?: "0", numeric = true)
        val price = field(prices, "Precio de venta", original?.optString("precio").orEmpty(), numeric = true)
        val qty = field(prices, "Cantidad disponible", original?.optString("cantidad") ?: "0", numeric = true)
        val minimum = field(prices, "Stock mínimo", original?.optString("stockMinimo") ?: "0", numeric = true)
        val photo = section(title = "3. Imagen del producto")
        preview = ImageView(this).apply { scaleType = ImageView.ScaleType.FIT_CENTER; contentDescription = "Vista previa de la imagen" }
        photo.addView(preview, LinearLayout.LayoutParams(-1, dp(160)))
        imageBase64?.let { showImage(preview!!, it) }
        imageLabel = text(if (imageBase64 == null) "Sin imagen" else "Imagen actual")
        photo.addView(imageLabel)
        button(photo, "Elegir imagen (WebP ≤ 10 KB)") { imagePicker.launch("image/*") }
        button(photo, "Quitar imagen", navy) { imageBase64 = null; preview?.setImageDrawable(null); imageLabel?.text = "Sin imagen" }
        val technical = section(title = "4. Ficha técnica", subtitle = "Las listas permiten elegir una opción o escribir otra del fabricante. No se deduce compatibilidad automáticamente.")
        val technicalInputs = linkedMapOf<String, EditText>()
        val draft = mutableMapOf<String, String>()
        fun renderFields() {
            technicalInputs.forEach { (k, v) -> draft[k] = v.text.toString() }
            technical.removeAllViews(); technical.addView(text("4. Ficha de ${category.selectedItem}", 20f, true))
            technical.addView(text("Lote obligatorio para lubricantes y aditivos. Fecha en AAAA-MM-DD. Puedes escribir una opción del fabricante.", 14f))
            technicalInputs.clear()
            val cat = category.selectedItem.toString()
            ProductFields.fields(cat, draft["tipo"] ?: original?.optString("tipo").orEmpty()).forEach { f ->
                val entry = field(technical, f.label, draft[f.key] ?: original?.optString(f.key).orEmpty(), options = f.options)
                technicalInputs[f.key] = entry
                if (f.key == "tipo" && entry is AutoCompleteTextView) entry.setOnItemClickListener { _, _, _, _ -> renderFields() }
            }
        }
        category.setSelection(ProductFields.categories.indexOf(original?.optString("categoria") ?: "Repuesto").coerceAtLeast(0))
        category.onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
            override fun onItemSelected(p: AdapterView<*>?, v: View?, pos: Int, id: Long) { renderFields() }
            override fun onNothingSelected(p: AdapterView<*>?) = Unit
        }
        renderFields()
        button(page, "Guardar producto", green) {
            action {
                val data = JSONObject().put("nombre", name.text.toString().trim()).put("codigo", code.text.toString().trim())
                    .put("categoria", category.selectedItem.toString()).put("costo", cost.text.toString().replace(',', '.').toDoubleOrNull() ?: throw IllegalArgumentException("Revisa el precio de compra."))
                    .put("precio", price.text.toString().replace(',', '.').toDoubleOrNull() ?: throw IllegalArgumentException("Revisa el precio de venta."))
                    .put("cantidad", qty.text.toString().toIntOrNull() ?: throw IllegalArgumentException("La cantidad debe ser un entero."))
                    .put("stockMinimo", minimum.text.toString().toIntOrNull() ?: throw IllegalArgumentException("El stock mínimo debe ser un entero."))
                    .put("imagen", imageBase64 ?: JSONObject.NULL)
                technicalInputs.forEach { (key, entry) -> data.put(key, entry.text.toString().trim()) }
                api!!.request(if (original == null) "POST" else "PUT", if (original == null) "products" else "products/${original.getInt("id")}", data)
                inventory()
                Toast.makeText(this, "Producto guardado", Toast.LENGTH_SHORT).show()
            }
        }
    }

    private fun addToCart(p: JSONObject) {
        if (saleRequest != null) { message("Hay una venta pendiente de respuesta. Reinténtala desde la cuenta antes de cambiar productos."); return }
        val input = EditText(this).apply { inputType = InputType.TYPE_CLASS_NUMBER; setText("1") }
        val dialog = AlertDialog.Builder(this).setTitle(p.getString("nombre"))
            .setMessage("Disponibles: ${p.getInt("cantidad")} ${p.optString("unidadVenta")} · Lote ${p.optString("lote")}\nCantidad de unidades de venta:")
            .setView(input).setNegativeButton("Cancelar", null).setPositiveButton("Agregar", null).create()
        dialog.setOnShowListener { dialog.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener {
            val amount = input.text.toString().toIntOrNull()
            val id = p.getInt("id")
            val total = (cart[id]?.second ?: 0).toLong() + (amount ?: 0)
            if (amount == null || amount <= 0 || total > p.getInt("cantidad")) input.error = "Revisa la cantidad disponible."
            else { cart[id] = p to total.toInt(); dialog.dismiss(); cartScreen() }
        } }
        dialog.show()
    }
    private fun cartScreen() {
        reset("Cuenta / venta", "${cart.size} productos · ${api!!.name}", "cart")
        if (cart.isEmpty()) page.addView(text("Tu cuenta está vacía. Agrega productos desde Inventario."))
        var total = 0L
        cart.forEach { (id, line) ->
            val (product, qty) = line
            total += price(product) * qty
            val box = section(title = product.getString("nombre"), subtitle = "${product.getString("codigo")} · Lote ${product.optString("lote")}\n$qty × ${money(price(product))} = ${money(price(product) * qty)}")
            if (saleRequest == null) button(box, "Quitar de la cuenta", navy) { cart.remove(id); cartScreen() }
        }
        val clientBox = section(title = "Cliente de esta venta", subtitle = "Solo se guarda con el comprobante; no se crea un catálogo de clientes.")
        val clientName = field(clientBox, "Nombre del cliente", saleClient.optString("nombre"))
        val clientDescription = field(clientBox, "Descripción del cliente", saleClient.optString("descripcion"))
        if (saleRequest != null) { clientName.isEnabled = false; clientDescription.isEnabled = false }
        val summary = section(title = "Total ${money(total)}", subtitle = "Se descontarán existencias al confirmar. Una caja o juego equivale a la unidad de venta registrada; no se convierte automáticamente a piezas.")
        if (saleRequest == null) button(summary, "Agregar más productos") { inventory() }
        else summary.addView(text("Respuesta pendiente: reintenta la misma venta. El servidor evita registrarla dos veces."))
        if (cart.isNotEmpty()) button(summary, if (saleRequest == null) "Confirmar venta" else "Reintentar venta", green) {
            if (saleRequest == null) {
                if (clientName.text.toString().trim().length < 2) {
                    clientName.error = "Ingresa el nombre del cliente."; return@button
                }
                saleClient = JSONObject().put("nombre", clientName.text.toString().trim()).put("descripcion", clientDescription.text.toString().trim())
            }
            AlertDialog.Builder(this).setTitle("Confirmar venta").setMessage("Total ${money(total)}. ¿Registrar a nombre de ${api!!.user.optString("nombres")}?")
                .setNegativeButton("Cancelar", null).setPositiveButton("Registrar") { _, _ -> action {
                    if (saleRequest == null) saleRequest = UUID.randomUUID().toString()
                    val lines = JSONArray()
                    cart.forEach { (id, line) -> lines.put(JSONObject().put("productoId", id).put("cantidad", line.second).put("precioEsperadoCentavos", price(line.first))) }
                    try {
                        persistPending()
                        val result = api!!.request("POST", "sales", JSONObject().put("solicitud", saleRequest).put("lineas", lines).put("cliente", saleClient)).getJSONObject("venta")
                        cart.clear(); clearPending(); saleClient = JSONObject(); home()
                        message("Venta #${result.getInt("id")} registrada. Total ${money(result.getLong("totalCentavos"))}.")
                    } catch (e: ApiError) {
                        if (e.status in listOf(400, 403, 404, 409, 429)) clearPending()
                        throw e
                    } finally { if (screen == "cart") cartScreen() }
                } }.show()
        }
    }

    private fun reports() {
        reset("Ventas y productividad", if (api!!.admin) "Todas las ventas del negocio" else "Tus ventas", "reports")
        action {
            val sales = api!!.request("GET", "sales").getJSONArray("ventas")
            val filters = section(title = "Periodo del informe")
            val period = Spinner(this)
            val options = listOf("Todo el historial", "Últimos 7 días", "Últimos 30 días", "Hoy")
            period.adapter = ArrayAdapter(this, android.R.layout.simple_spinner_dropdown_item, options)
            filters.addView(period)
            val sellerFilter = Spinner(this)
            val sellerNames = listOf("Todos los vendedores") + (0 until sales.length()).map {
                val sale = sales.getJSONObject(it)
                "${sale.getString("vendedor")} · ${sale.optString("codigoVendedor")}"
            }.distinct().sorted()
            sellerFilter.adapter = ArrayAdapter(this, android.R.layout.simple_spinner_dropdown_item, sellerNames)
            if (api!!.admin) filters.addView(sellerFilter)
            val output = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
            page.addView(output)
            fun render() {
                output.removeAllViews()
                val cutoff = when (period.selectedItemPosition) { 1 -> System.currentTimeMillis() - 7L * 86400000; 2 -> System.currentTimeMillis() - 30L * 86400000; 3 -> {
                    val cal = java.util.Calendar.getInstance(); cal.set(java.util.Calendar.HOUR_OF_DAY, 0); cal.set(java.util.Calendar.MINUTE, 0); cal.set(java.util.Calendar.SECOND, 0); cal.set(java.util.Calendar.MILLISECOND, 0); cal.timeInMillis
                }; else -> 0L }
                val historyRows = (0 until sales.length()).map { sales.getJSONObject(it) }.filter { sale ->
                    val who = "${sale.getString("vendedor")} · ${sale.optString("codigoVendedor")}"
                    val correctSeller = !api!!.admin || sellerFilter.selectedItemPosition <= 0 || who == sellerFilter.selectedItem.toString()
                    correctSeller && try { java.time.Instant.parse(sale.getString("fecha")).toEpochMilli() >= cutoff } catch (_: Exception) { cutoff == 0L }
                }
                val rows = historyRows.filter { it.optString("estado", "confirmada") != "anulada" }
                var units = 0L; var income = 0L; var cost = 0L
                val sellers = linkedMapOf<String, LongArray>()
                val products = linkedMapOf<String, LongArray>()
                rows.forEach { sale ->
                    val total = sale.getLong("totalCentavos"); income += total
                    val who = "${sale.getString("vendedor")} · ${sale.optString("codigoVendedor")}"
                    val metric = sellers.getOrPut(who) { LongArray(3) }; metric[0]++; metric[2] += total
                    val details = sale.getJSONArray("detalles")
                    for (j in 0 until details.length()) {
                        val d = details.getJSONObject(j); val q = d.getLong("cantidad"); units += q; metric[1] += q
                        cost += d.optLong("costoCentavos") * q
                        val product = products.getOrPut("${d.getString("nombre")} · ${d.getString("codigo")}") { LongArray(2) }
                        product[0] += q; product[1] += q * d.getLong("precioCentavos")
                    }
                }
                section(output, "Resumen del periodo", "${rows.size} ventas · $units unidades\nIngresos ${money(income)}\nTicket promedio ${money(if (rows.isEmpty()) 0 else income / rows.size)}${if (api!!.admin) "\nMargen bruto estimado ${money(income - cost)}" else ""}")
                sellers.entries.sortedByDescending { it.value[2] }.forEach { (who, values) -> section(output, who, "${values[0]} ventas · ${values[1]} unidades · ${money(values[2])}") }
                if (products.isNotEmpty()) {
                    val top = section(output, "Productos más vendidos")
                    val maximum = products.values.maxOf { it[0] }.coerceAtLeast(1)
                    products.entries.sortedByDescending { it.value[0] }.take(10).forEach { (name, values) ->
                        top.addView(text("$name\n${values[0]} unidades · ${money(values[1])}", 14f))
                        top.addView(ProgressBar(this@MainActivity, null, android.R.attr.progressBarStyleHorizontal).apply {
                            max = 100; progress = (values[0] * 100 / maximum).toInt(); contentDescription = "$name: ${values[0]} unidades"
                        }, LinearLayout.LayoutParams(-1, dp(8)))
                    }
                }
                historyRows.forEach { sale ->
                    val card = section(output, "Venta #${sale.getInt("id")} · ${money(sale.getLong("totalCentavos"))}", "${sale.getString("fecha")}\n${sale.getString("vendedor")} · ${sale.optString("codigoVendedor")}")
                    val customer = sale.optJSONObject("cliente") ?: JSONObject()
                    card.addView(text("Cliente: ${customer.optString("nombre")}\n${customer.optString("descripcion")}\nEstado: ${sale.optString("estado", "confirmada")}", 14f))
                    button(card, "Ver productos vendidos") {
                        val details = sale.getJSONArray("detalles")
                        message((0 until details.length()).joinToString("\n\n") { j ->
                            val d = details.getJSONObject(j)
                            "${d.getString("nombre")} (${d.getString("codigo")})\n${d.getInt("cantidad")} × ${money(d.getLong("precioCentavos"))} · Lote ${d.optString("lote")}"
                        })
                    }
                    if (api!!.admin && sale.optString("estado") != "anulada") button(card, "Eliminar / anular venta", Color.rgb(164, 55, 55)) {
                        val reason = EditText(this@MainActivity).apply { hint = "Motivo de anulación" }
                        AlertDialog.Builder(this@MainActivity).setTitle("¿Anular venta #${sale.getInt("id")}?")
                            .setMessage("Se devolverán las existencias una sola vez y se conservará el comprobante en el historial.")
                            .setView(reason).setNegativeButton("Cancelar", null).setPositiveButton("Anular y devolver stock") { _, _ -> action {
                                api!!.request("POST", "sales/${sale.getInt("id")}/cancel", JSONObject().put("motivo", reason.text.toString()))
                                page.post { reports() }
                            } }.show()
                    }
                }
            }
            period.onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
                override fun onItemSelected(p: AdapterView<*>?, v: View?, pos: Int, id: Long) { render() }
                override fun onNothingSelected(p: AdapterView<*>?) = Unit
            }
            sellerFilter.onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
                override fun onItemSelected(p: AdapterView<*>?, v: View?, pos: Int, id: Long) { render() }
                override fun onNothingSelected(p: AdapterView<*>?) = Unit
            }
            render()
        }
    }
    private fun team() {
        reset("Vendedores y equipo", api!!.name, "team")
        button(page, "+ Crear integrante", green) { register(true) }
        button(page, "Invitar con código") { invite() }
        action {
            val users = api!!.request("GET", "users").getJSONArray("usuarios")
            page.addView(text("${users.length()} cuentas registradas en este negocio", 16f, true))
            for (i in 0 until users.length()) {
                val u = users.getJSONObject(i)
                val box = section(title = "${u.optString("nombres")} ${u.optString("apellidos")}", subtitle = "${u.getString("nombre")} · ${u.getString("rol")}\nCódigo interno ${u.optString("codigoInterno")}")
                if (u.getInt("id") != api!!.user.getInt("id")) button(box, "Restablecer contraseña", navy) { resetPassword(u) }
            }
        }
    }
    private fun invite() {
        reset("Invitar al negocio", api!!.name, "invite")
        val box = section(title = "Código de acceso del negocio", subtitle = "El destinatario pega este código e inicia sesión con su cuenta. El código no concede permisos de administrador ni convierte su teléfono en servidor.")
        val data = JSONObject().put("url", api!!.business.url).put("negocio", api!!.business.id)
        if (api!!.business.vpn) data.put("vpn", true)
        val code = "SG1-" + Base64.encodeToString(data.toString().toByteArray(Charsets.UTF_8), Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)
        box.addView(text(code, 14f).apply { setTextIsSelectable(true) })
        button(box, "Copiar código") { copy(code) }
        page.addView(text("Este código usa la API central segura ${api!!.business.url}. Todos los equipos consultan la misma nube.", 14f))
    }
    private fun resetPassword(user: JSONObject) {
        val password = EditText(this).apply { inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD }
        val dialog = AlertDialog.Builder(this).setTitle("Restablecer ${user.getString("nombre")}")
            .setMessage("Confirma tu contraseña Administrador. La clave temporal vence en 30 minutos y obliga a cambiarla.")
            .setView(password).setNegativeButton("Cancelar", null).setPositiveButton("Restablecer", null).create()
        dialog.setOnShowListener { dialog.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener {
            if (!busy) action {
                val result = api!!.request("POST", "users/reset-password", JSONObject().put("usuarioId", user.getInt("id")).put("passwordAdmin", password.text.toString()))
                dialog.dismiss()
                val temporary = result.getString("temporal")
                AlertDialog.Builder(this).setTitle("Clave temporal · 30 minutos").setMessage(temporary)
                    .setPositiveButton("Copiar") { _, _ -> copy(temporary) }.setNegativeButton("Cerrar", null).show()
            }
        } }
        dialog.show()
    }
    private fun passwordScreen() {
        reset("Cambiar contraseña", if (api!!.mustChange) "Cambio obligatorio para continuar" else api!!.name, "password")
        val box = section(title = "Protege tu cuenta")
        val current = field(box, "Contraseña actual / temporal", password = true)
        val new = field(box, "Nueva contraseña (8–128 caracteres)", password = true)
        val confirm = field(box, "Repite la nueva contraseña", password = true)
        button(box, "Guardar contraseña", green) {
            if (new.text.toString() != confirm.text.toString()) message("Las contraseñas no coinciden.")
            else action {
                api!!.user = api!!.request("POST", "auth/password", JSONObject().put("actual", current.text.toString()).put("nueva", new.text.toString())).getJSONObject("usuario")
                afterLogin()
            }
        }
        button(page, "Cerrar sesión", navy) { logout() }
    }
    private fun profile() {
        reset("Mi perfil", api!!.name, "profile")
        val box = section(title = "Responsable de las ventas")
        val first = field(box, "Nombres", api!!.user.optString("nombres"))
        val last = field(box, "Apellidos", api!!.user.optString("apellidos"))
        button(box, "Guardar perfil") { action {
            api!!.user = api!!.request("PUT", "auth/profile", JSONObject().put("nombres", first.text.toString()).put("apellidos", last.text.toString())).getJSONObject("usuario")
            home()
        } }
    }
    private fun audit() {
        reset("Historial de seguridad", api!!.name, "audit")
        action {
            val events = api!!.request("GET", "security/audit").getJSONArray("eventos")
            if (events.length() == 0) page.addView(text("Todavía no hay cambios de contraseña registrados."))
            for (i in 0 until events.length()) {
                val e = events.getJSONObject(i)
                section(title = e.getString("accion"), subtitle = "${e.getString("fecha")}\n${e.getString("actor")} → ${e.getString("objetivo")}")
            }
        }
    }
    private fun logout() {
        if (saleRequest != null) {
            message("Hay una venta pendiente de confirmar. Reintenta desde la cuenta y consulta el historial antes de salir.")
            return
        }
        action {
            api?.pauseRealtime(); reconnectJob?.cancel(); api?.clearCache()
            try { api?.request("POST", "auth/logout", JSONObject()) } catch (_: IOException) { /* Sesión local se limpia igualmente. */ }
            finally {
                api?.token = ""; api?.user = JSONObject(); cart.clear(); saleRequest = null
                imageJob?.cancel(); imageBase64 = null; credentials()
            }
        }
    }
}
