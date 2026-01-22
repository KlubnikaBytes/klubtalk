package com.example.whatsapp_clone

import android.content.Context
import android.net.Uri
import android.os.Bundle
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream


class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.whatsapp_clone/storage"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "resolveContentUri") {
                val uriString = call.argument<String>("uri")
                if (uriString != null) {
                    val path = resolveContentUri(uriString)
                    if (path != null) {
                        result.success(path)
                    } else {
                        result.error("UNAVAILABLE", "Could not resolve URI", null)
                    }
                } else {
                    result.error("INVALID_ARGUMENT", "URI argument is null", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun resolveContentUri(uriString: String): String? {
        try {
            val uri = Uri.parse(uriString)
            val resolver = contentResolver
            val inputStream: InputStream? = resolver.openInputStream(uri)

            if (inputStream != null) {
                // Create a temporary file in the cache directory
                val tempFile = File(cacheDir, "temp_upload_" + System.currentTimeMillis())
                val outputStream = FileOutputStream(tempFile)

                val buffer = ByteArray(1024)
                var length: Int
                while (inputStream.read(buffer).also { length = it } > 0) {
                    outputStream.write(buffer, 0, length)
                }

                outputStream.close()
                inputStream.close()

                return tempFile.absolutePath
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return null
    }
}
