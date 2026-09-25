package com.caterpro.caterpro

import android.content.ContentValues
import android.content.ClipData
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val channelName = "caterpro/downloads"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveFile" -> saveFile(
                        call.argument<String>("fileName"),
                        call.argument<String>("mimeType"),
                        call.argument<ByteArray>("bytes"),
                        result
                    )
                    "openFile" -> openFile(
                        call.argument<String>("uri"),
                        call.argument<String>("mimeType"),
                        result
                    )
                    "shareFile" -> shareFile(
                        call.argument<String>("uri"),
                        call.argument<String>("mimeType"),
                        call.argument<String>("title"),
                        call.argument<String>("text"),
                        result
                    )
                    "shareText" -> shareText(
                        call.argument<String>("title"),
                        call.argument<String>("text"),
                        result
                    )
                    else -> result.notImplemented()
                }
            }
    }

    private fun saveFile(
        fileName: String?,
        mimeType: String?,
        bytes: ByteArray?,
        result: MethodChannel.Result
    ) {
        if (fileName.isNullOrBlank() || mimeType.isNullOrBlank() || bytes == null) {
            result.error("invalid_args", "Missing file data", null)
            return
        }
        try {
            val resolver = applicationContext.contentResolver
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    put(MediaStore.MediaColumns.RELATIVE_PATH, "${Environment.DIRECTORY_DOWNLOADS}/CaterPro")
                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                }
            }
            val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            } else {
                MediaStore.Files.getContentUri("external")
            }
            val uri = resolver.insert(collection, values)
                ?: throw IllegalStateException("Unable to create download")
            resolver.openOutputStream(uri)?.use { stream ->
                stream.write(bytes)
            } ?: throw IllegalStateException("Unable to write download")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val complete = ContentValues().apply {
                    put(MediaStore.MediaColumns.IS_PENDING, 0)
                }
                resolver.update(uri, complete, null, null)
            }
            result.success(mapOf("uri" to uri.toString(), "name" to fileName))
        } catch (error: Exception) {
            result.error("save_failed", error.message ?: "Unable to save file", null)
        }
    }

    private fun openFile(uriText: String?, mimeType: String?, result: MethodChannel.Result) {
        if (uriText.isNullOrBlank()) {
            result.success(false)
            return
        }
        try {
            val uri = Uri.parse(uriText)
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, mimeType ?: "*/*")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(Intent.createChooser(intent, "Open with"))
            result.success(true)
        } catch (_: Exception) {
            result.success(false)
        }
    }

    private fun shareFile(uriText: String?, mimeType: String?, title: String?, text: String?, result: MethodChannel.Result) {
        if (uriText.isNullOrBlank()) {
            result.success(false)
            return
        }
        try {
            val uri = Uri.parse(uriText)
            val safeMimeType = mimeType ?: "*/*"
            val intent = if (!text.isNullOrBlank()) {
                Intent(Intent.ACTION_SEND_MULTIPLE).apply {
                    type = "*/*"
                    putParcelableArrayListExtra(Intent.EXTRA_STREAM, arrayListOf(uri))
                    putExtra(Intent.EXTRA_TEXT, text)
                    putExtra(Intent.EXTRA_SUBJECT, title ?: "CaterPro invoice")
                    putExtra(Intent.EXTRA_TITLE, title ?: "CaterPro invoice")
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
                        putExtra(Intent.EXTRA_MIME_TYPES, arrayOf(safeMimeType, "text/plain"))
                    }
                    clipData = ClipData.newUri(contentResolver, title ?: "CaterPro invoice", uri)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
            } else {
                Intent(Intent.ACTION_SEND).apply {
                    type = safeMimeType
                    putExtra(Intent.EXTRA_STREAM, uri)
                    putExtra(Intent.EXTRA_TITLE, title ?: "Share PDF")
                    clipData = ClipData.newUri(contentResolver, title ?: "Share PDF", uri)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
            }
            startActivity(Intent.createChooser(intent, title ?: "Share PDF"))
            result.success(true)
        } catch (_: Exception) {
            result.success(false)
        }
    }

    private fun shareText(title: String?, text: String?, result: MethodChannel.Result) {
        if (text.isNullOrBlank()) {
            result.success(false)
            return
        }
        try {
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_TEXT, text)
            }
            startActivity(Intent.createChooser(intent, title ?: "Share"))
            result.success(true)
        } catch (_: Exception) {
            result.success(false)
        }
    }
}
