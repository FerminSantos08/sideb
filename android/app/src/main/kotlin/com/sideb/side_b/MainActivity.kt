package com.sideb.side_b

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.net.Uri
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    private var paymentChannel: MethodChannel? = null
    private var avatarResult: MethodChannel.Result? = null

    @Deprecated("Uses the system document picker without storage permissions")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 5041) return
        val result = avatarResult ?: return
        avatarResult = null
        val uri = data?.data
        if (resultCode != RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        Thread {
            try {
                val output = ByteArrayOutputStream()
                contentResolver.openInputStream(uri)?.use { input ->
                    val buffer = ByteArray(8192)
                    while (true) {
                        val count = input.read(buffer)
                        if (count < 0) break
                        if (output.size() + count > 5 * 1024 * 1024) throw IllegalArgumentException("La foto debe pesar como máximo 5 MB.")
                        output.write(buffer, 0, count)
                    }
                } ?: throw IllegalArgumentException("No pudimos leer la foto.")
                runOnUiThread { result.success(output.toByteArray()) }
            } catch (error: Exception) {
                runOnUiThread { result.error("image_unavailable", error.message, null) }
            }
        }.start()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val uri = intent.data
        if (uri?.scheme == "sideb" && uri.host == "payment" && uri.path == "/result") {
            // This is only a refresh hint. Flutter verifies payment with the API.
            paymentChannel?.invokeMethod("returned", null)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "side_b/profile").setMethodCallHandler { call, result ->
            if (call.method != "pickAvatar") {
                result.notImplemented()
            } else if (avatarResult != null) {
                result.error("picker_busy", "Ya hay una selección de foto abierta.", null)
            } else {
                avatarResult = result
                try {
                    val pick = Intent(Intent.ACTION_GET_CONTENT).apply {
                        type = "image/*"
                        addCategory(Intent.CATEGORY_OPENABLE)
                        putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("image/jpeg", "image/png", "image/webp"))
                    }
                    startActivityForResult(pick, 5041)
                } catch (error: Exception) {
                    avatarResult = null
                    result.error("picker_unavailable", "No pudimos abrir tus fotos.", null)
                }
            }
        }
        paymentChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "side_b/payment").apply {
            setMethodCallHandler { call, result ->
                if (call.method != "open") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val uri = Uri.parse(call.argument<String>("url") ?: "")
                if (uri.scheme !in listOf("http", "https") || uri.host.isNullOrBlank()) {
                    result.error("invalid_url", "Enlace de pago no válido", null)
                    return@setMethodCallHandler
                }
                try {
                    startActivity(Intent(Intent.ACTION_VIEW, uri).addCategory(Intent.CATEGORY_BROWSABLE))
                    result.success(null)
                } catch (error: Exception) {
                    result.error("browser_unavailable", "No fue posible abrir el navegador", null)
                }
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "side_b/share")
            .setMethodCallHandler { call, result ->
                if (call.method != "share") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val title = call.argument<String>("title") ?: "SIDE B"
                val url = call.argument<String>("url")
                if (url.isNullOrBlank()) {
                    result.error("invalid_url", "Falta el enlace de la publicación", null)
                    return@setMethodCallHandler
                }
                try {
                    val intent = Intent(Intent.ACTION_SEND).apply {
                        type = "text/plain"
                        putExtra(Intent.EXTRA_SUBJECT, title)
                        putExtra(Intent.EXTRA_TEXT, "$title\n$url")
                    }
                    startActivity(Intent.createChooser(intent, "Compartir publicación"))
                    result.success(null)
                } catch (error: Exception) {
                    result.error("share_failed", "No fue posible compartir", null)
                }
            }
    }
}
