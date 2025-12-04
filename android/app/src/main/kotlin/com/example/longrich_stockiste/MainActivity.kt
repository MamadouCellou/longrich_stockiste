package com.example.longrich_stockiste

import android.content.ContentResolver
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.*

class MainActivity : FlutterActivity() {

    private val CHANNEL = "shared_channel"
    private var methodChannel: MethodChannel? = null

    private var sharedText: String? = null
    private var sharedImagePaths: ArrayList<String> = arrayListOf()

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        methodChannel?.setMethodCallHandler { call, result ->
            if (call.method == "getSharedData") {
                val data = mapOf(
                    "text" to sharedText,
                    "images" to sharedImagePaths
                )
                result.success(data)
                sharedText = null
                sharedImagePaths.clear()
            } else {
                result.notImplemented()
            }
        }

        handleShareIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleShareIntent(intent)

        methodChannel?.invokeMethod("onShared", mapOf(
            "text" to sharedText,
            "images" to sharedImagePaths
        ))

        sharedText = null
        sharedImagePaths.clear()
    }

    private fun handleShareIntent(intent: Intent?) {
        if (intent == null) return

        sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)

        when (intent.action) {
            Intent.ACTION_SEND -> {
                val type = intent.type ?: return

                if (type.startsWith("image/")) {
                    val uri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                    uri?.let {
                        copyUriToCache(it)?.let { path ->
                            sharedImagePaths.add(path)
                        }
                    }
                }
            }

            Intent.ACTION_SEND_MULTIPLE -> {
                val uris = intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
                uris?.forEach { uri ->
                    copyUriToCache(uri)?.let { path ->
                        sharedImagePaths.add(path)
                    }
                }
            }
        }
    }

    private fun copyUriToCache(uri: Uri): String? {
        return try {
            val fileName = getFileName(uri) ?: "shared_image.jpg"
            val inputStream = contentResolver.openInputStream(uri) ?: return null
            val outputFile = File(cacheDir, fileName)
            val outputStream = FileOutputStream(outputFile)

            inputStream.copyTo(outputStream)
            inputStream.close()
            outputStream.close()

            outputFile.absolutePath
        } catch (e: Exception) {
            Log.e("SHARE", "Erreur lors de la copie de l'image", e)
            null
        }
    }

    private fun getFileName(uri: Uri): String? {
        var name: String? = null
        if (uri.scheme == ContentResolver.SCHEME_CONTENT) {
            val cursor = contentResolver.query(uri, null, null, null, null)
            cursor?.use {
                if (it.moveToFirst()) {
                    name = it.getString(it.getColumnIndex(OpenableColumns.DISPLAY_NAME))
                }
            }
        }
        return name ?: uri.path?.substringAfterLast('/')
    }
}
