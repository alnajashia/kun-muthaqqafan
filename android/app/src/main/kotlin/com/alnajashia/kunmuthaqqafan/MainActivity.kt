package com.alnajashia.kunmuthaqqafan

import android.graphics.Bitmap
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File

/// Native PDF rendering via Android PdfRenderer (no third-party plugin):
/// open -> page count, render page -> PNG bytes at a requested width.
class MainActivity : FlutterActivity() {
    private var renderer: PdfRenderer? = null
    private var descriptor: ParcelFileDescriptor? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kun/pdf")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "open" -> {
                            closeRenderer()
                            val path = call.argument<String>("path")
                                ?: return@setMethodCallHandler result.error("ARG", "path missing", null)
                            descriptor = ParcelFileDescriptor.open(
                                File(path), ParcelFileDescriptor.MODE_READ_ONLY
                            )
                            renderer = PdfRenderer(descriptor!!)
                            result.success(renderer!!.pageCount)
                        }
                        "render" -> {
                            val r = renderer
                                ?: return@setMethodCallHandler result.error("STATE", "no document open", null)
                            val pageIndex = call.argument<Int>("page") ?: 0
                            val width = call.argument<Int>("width") ?: 1080
                            val page = r.openPage(pageIndex)
                            val height = (width * page.height / page.width).coerceAtLeast(1)
                            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                            bitmap.eraseColor(android.graphics.Color.WHITE)
                            page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                            page.close()
                            val out = ByteArrayOutputStream()
                            bitmap.compress(Bitmap.CompressFormat.PNG, 90, out)
                            bitmap.recycle()
                            result.success(out.toByteArray())
                        }
                        "close" -> {
                            closeRenderer()
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("PDF", e.message, null)
                }
            }
    }

    private fun closeRenderer() {
        try { renderer?.close() } catch (_: Exception) {}
        try { descriptor?.close() } catch (_: Exception) {}
        renderer = null
        descriptor = null
    }

    override fun onDestroy() {
        closeRenderer()
        super.onDestroy()
    }
}
