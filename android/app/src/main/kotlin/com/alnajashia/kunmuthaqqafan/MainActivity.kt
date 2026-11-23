package com.alnajashia.kunmuthaqqafan

import android.content.Intent
import android.graphics.Bitmap
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.ParcelFileDescriptor
import android.provider.MediaStore
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File

/// Native helpers:
/// - "kun/pdf": PDF rendering via Android PdfRenderer.
/// - "kun/scan": automatic discovery of book files on the device
///   (MediaStore query + folder walk when All-files access is granted).
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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kun/scan")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "hasAllFilesAccess" -> result.success(hasAllFilesAccess())
                        "requestAllFilesAccess" -> {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                                val intent = Intent(
                                    Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                                    Uri.parse("package:$packageName")
                                )
                                startActivity(intent)
                            }
                            result.success(null)
                        }
                        "scan" -> {
                            val found = LinkedHashMap<String, Map<String, Any>>()
                            scanMediaStore(found)
                            if (hasAllFilesAccess()) scanFolders(found)
                            result.success(found.values.toList())
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("SCAN", e.message, null)
                }
            }
    }

    private fun hasAllFilesAccess(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.R || Environment.isExternalStorageManager()

    private fun isBookFile(name: String): Boolean {
        val lower = name.lowercase()
        return lower.endsWith(".pdf") || lower.endsWith(".epub") || lower.endsWith(".txt")
    }

    private fun scanMediaStore(found: LinkedHashMap<String, Map<String, Any>>) {
        val uri = MediaStore.Files.getContentUri("external")
        val projection = arrayOf(
            MediaStore.Files.FileColumns.DATA,
            MediaStore.Files.FileColumns.DISPLAY_NAME,
            MediaStore.Files.FileColumns.SIZE,
            MediaStore.Files.FileColumns.DATE_MODIFIED
        )
        val selection =
            "${MediaStore.Files.FileColumns.MIME_TYPE} IN (?, ?, ?) OR " +
                "${MediaStore.Files.FileColumns.DISPLAY_NAME} LIKE ? OR " +
                "${MediaStore.Files.FileColumns.DISPLAY_NAME} LIKE ?"
        val args = arrayOf(
            "application/pdf", "application/epub+zip", "text/plain", "%.epub", "%.pdf"
        )
        contentResolver.query(uri, projection, selection, args, null)?.use { cursor ->
            val dataIdx = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DATA)
            val nameIdx = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DISPLAY_NAME)
            val sizeIdx = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.SIZE)
            val modIdx = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DATE_MODIFIED)
            while (cursor.moveToNext()) {
                val path = cursor.getString(dataIdx) ?: continue
                val name = cursor.getString(nameIdx) ?: File(path).name
                if (!isBookFile(name)) continue
                if (!File(path).exists()) continue
                found[path] = mapOf(
                    "path" to path,
                    "name" to name,
                    "size" to cursor.getLong(sizeIdx),
                    "modified" to cursor.getLong(modIdx) * 1000L
                )
            }
        }
    }

    private fun scanFolders(found: LinkedHashMap<String, Map<String, Any>>) {
        val roots = listOf(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOCUMENTS),
            File(Environment.getExternalStorageDirectory(), "Books"),
            File(Environment.getExternalStorageDirectory(), "Download"),
            File(Environment.getExternalStorageDirectory(), "Documents")
        )
        var visited = 0
        for (root in roots) {
            if (!root.exists()) continue
            root.walkTopDown().maxDepth(4).forEach { file ->
                if (++visited > 20000) return@forEach
                if (file.isFile && isBookFile(file.name) && !found.containsKey(file.absolutePath)) {
                    found[file.absolutePath] = mapOf(
                        "path" to file.absolutePath,
                        "name" to file.name,
                        "size" to file.length(),
                        "modified" to file.lastModified()
                    )
                }
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
