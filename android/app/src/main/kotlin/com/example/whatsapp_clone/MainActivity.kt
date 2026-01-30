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

    private var pendingResult: MethodChannel.Result? = null
    private val RINGTONE_PICKER_REQUEST_CODE = 999

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Storage Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "resolveContentUri") {
                 // ... existing logic redirected below ...
                 handleResolveContentUri(call, result)
            } else {
                result.notImplemented()
            }
        }

        // Ringtone Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.whatsapp_clone/ringtone").setMethodCallHandler { call, result ->
             when (call.method) {
                 "playOutgoing" -> {
                     playOutgoingTone()
                     result.success(null)
                 }
                 "playIncoming" -> {
                     val uri = call.argument<String>("uri")
                     playIncomingTone(uri)
                     result.success(null)
                 }
                 "stop" -> {
                     stopTone()
                     result.success(null)
                 }
                 "getSystemRingtoneUri" -> {
                     val uri = android.media.RingtoneManager.getActualDefaultRingtoneUri(this, android.media.RingtoneManager.TYPE_RINGTONE)
                     result.success(uri?.toString())
                 }
                 "pickRingtone" -> {
                     pendingResult = result
                     pickRingtone(call.argument<Int>("type") ?: 1) // 1 = TYPE_RINGTONE, 2 = TYPE_NOTIFICATION
                 }
                 else -> result.notImplemented()
             }
        }
    }

    private fun pickRingtone(type: Int) {
        val intent = android.content.Intent(android.media.RingtoneManager.ACTION_RINGTONE_PICKER)
        intent.putExtra(android.media.RingtoneManager.EXTRA_RINGTONE_TYPE, type)
        intent.putExtra(android.media.RingtoneManager.EXTRA_RINGTONE_TITLE, "Select Tone")
        intent.putExtra(android.media.RingtoneManager.EXTRA_RINGTONE_EXISTING_URI, null as Uri?)
        startActivityForResult(intent, RINGTONE_PICKER_REQUEST_CODE)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == RINGTONE_PICKER_REQUEST_CODE) {
            if (resultCode == android.app.Activity.RESULT_OK && data != null) {
                val uri: Uri? = data.getParcelableExtra(android.media.RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
                pendingResult?.success(uri?.toString())
            } else {
                pendingResult?.success(null)
            }
            pendingResult = null
        }
    }

    private var toneGenerator: android.media.ToneGenerator? = null
    private var mediaPlayer: android.media.MediaPlayer? = null

    private fun playOutgoingTone() {
        stopTone() // Ensure cleanup
        try {
            // TONE_SUP_RINGTONE is the standard "trrr... trrr..."
            toneGenerator = android.media.ToneGenerator(android.media.AudioManager.STREAM_VOICE_CALL, 80)
            toneGenerator?.startTone(android.media.ToneGenerator.TONE_SUP_RINGTONE) 
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
    
    private fun playIncomingTone(customUriString: String?) {
        stopTone()
        try {
            var uri: Uri? = null
            
            // 1. Try Custom URI if provided
            if (customUriString != null && customUriString.isNotEmpty()) {
                try {
                    uri = Uri.parse(customUriString)
                    println("🎵 Using Custom Ringtone URI: $uri")
                } catch (e: Exception) {
                    println("❌ Invalid Custom URI: $customUriString")
                }
            }

            // 2. Fallback to System Default Ringtone
            if (uri == null) {
                uri = android.media.RingtoneManager.getActualDefaultRingtoneUri(this, android.media.RingtoneManager.TYPE_RINGTONE)
            }
            
            // 3. Fallback to Notification Sound
            if (uri == null) {
                 println("⚠️ System Ringtone is NULL, falling back to Notification Sound")
                 uri = android.media.RingtoneManager.getActualDefaultRingtoneUri(this, android.media.RingtoneManager.TYPE_NOTIFICATION)
            }
            
            println("🎵 Attempting to play Native Ringtone from URI: $uri")

            if (uri != null) {
                mediaPlayer = android.media.MediaPlayer().apply {
                    setDataSource(this@MainActivity, uri)
                    setAudioAttributes(
                        android.media.AudioAttributes.Builder()
                            .setUsage(android.media.AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                            .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build()
                    )
                    isLooping = true
                    setOnPreparedListener { 
                        println("✅ MediaPlayer Prepared. Starting...")
                        it.start() 
                    }
                    setOnErrorListener { mp, what, extra ->
                        println("❌ MediaPlayer Error: What=$what, Extra=$extra")
                        false
                    }
                    prepareAsync() // Use Async to prevent UI blocking
                }
            } else {
                println("❌ Could not resolve any Ringtone URI")
            }
        } catch (e: Exception) {
            println("❌ Exception in playIncomingTone: $e")
            e.printStackTrace()
        }
    }

    private fun stopTone() {
        try {
            toneGenerator?.stopTone()
            toneGenerator?.release()
            toneGenerator = null
            
            mediaPlayer?.stop()
            mediaPlayer?.release()
            mediaPlayer = null
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
    
    private fun handleResolveContentUri(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
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
