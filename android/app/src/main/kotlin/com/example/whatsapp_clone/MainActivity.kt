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
             android.util.Log.d("RingtoneChannel", "🔍 Method called: ${call.method}")
             when (call.method) {
                 "playOutgoing" -> {
                     android.util.Log.i("RingtoneChannel", "📞 playOutgoing called")
                     playOutgoingTone()
                     result.success(null)
                 }
                 "playIncoming" -> {
                     val uri = call.argument<String>("uri")
                     android.util.Log.i("RingtoneChannel", "📞 playIncoming called with URI: $uri")
                     playIncomingTone(uri)
                     android.util.Log.i("RingtoneChannel", "✅ playIncoming completed")
                     result.success(null)
                 }
                 "stop" -> {
                     android.util.Log.i("RingtoneChannel", "🛑 stop called")
                     stopTone()
                     result.success(null)
                 }
                 "getSystemRingtoneUri" -> {
                     android.util.Log.i("RingtoneChannel", "🔍 getSystemRingtoneUri called")
                     val uri = android.media.RingtoneManager.getActualDefaultRingtoneUri(this, android.media.RingtoneManager.TYPE_RINGTONE)
                     android.util.Log.i("RingtoneChannel", "✅ System ringtone URI: $uri")
                     result.success(uri?.toString())
                 }
                 "pickRingtone" -> {
                     android.util.Log.i("RingtoneChannel", "🎵 pickRingtone called")
                     pendingResult = result
                     pickRingtone(call.argument<Int>("type") ?: 1) // 1 = TYPE_RINGTONE, 2 = TYPE_NOTIFICATION
                 }
                 else -> {
                     android.util.Log.w("RingtoneChannel", "⚠️ Unknown method: ${call.method}")
                     result.notImplemented()
                 }
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
    
    
    private var originalRingVolume: Int = -1
    
    private fun playIncomingTone(customUriString: String?) {
        android.util.Log.w("RingtoneService", "════════════════════════════════════")
        android.util.Log.w("RingtoneService", "🚀 playIncomingTone CALLED")
        android.util.Log.w("RingtoneService", "📥 Input URI: $customUriString")
        android.util.Log.w("RingtoneService", "════════════════════════════════════")
        
        stopTone()
        
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            try {
                var uri: Uri? = null
                var uriSource = "none"
                
                // 1. Try Custom URI if provided
                if (customUriString != null && customUriString.isNotEmpty()) {
                    try {
                        uri = Uri.parse(customUriString)
                        uriSource = "custom"
                        android.util.Log.d("RingtoneService", "🎵 Parsed Custom Ringtone URI: $uri")
                    } catch (e: Exception) {
                        android.util.Log.e("RingtoneService", "❌ Failed to parse custom URI: $customUriString", e)
                        uri = null
                    }
                }

                // 2. Fallback to System Default Ringtone
                if (uri == null) {
                    try {
                        uri = android.media.RingtoneManager.getDefaultUri(android.media.RingtoneManager.TYPE_RINGTONE)
                        uriSource = "system_default"
                        android.util.Log.d("RingtoneService", "🔔 Using System Default Ringtone: $uri")
                    } catch (e: Exception) {
                        android.util.Log.e("RingtoneService", "❌ Failed to get system ringtone", e)
                    }
                }
                
                // 3. Final Fallback to Notification Sound
                if (uri == null) {
                    try {
                        uri = android.media.RingtoneManager.getDefaultUri(android.media.RingtoneManager.TYPE_NOTIFICATION)
                        uriSource = "notification"
                        android.util.Log.w("RingtoneService", "⚠️ Using Notification Sound as fallback: $uri")
                    } catch (e: Exception) {
                        android.util.Log.e("RingtoneService", "❌ All URI fallbacks failed", e)
                    }
                }
                
                if (uri == null) {
                    android.util.Log.e("RingtoneService", "❌ CRITICAL: Could not resolve any ringtone URI")
                    return@post
                }

                android.util.Log.i("RingtoneService", "🎵 Final Ringtone URI: $uri (source: $uriSource)")

                // Get AudioManager and set volume to maximum
                val audioManager = getSystemService(Context.AUDIO_SERVICE) as android.media.AudioManager
                originalRingVolume = audioManager.getStreamVolume(android.media.AudioManager.STREAM_RING)
                val maxVolume = audioManager.getStreamMaxVolume(android.media.AudioManager.STREAM_RING)
                audioManager.setStreamVolume(android.media.AudioManager.STREAM_RING, maxVolume, 0)
                android.util.Log.d("RingtoneService", "🔊 Volume: $originalRingVolume → $maxVolume (max)")
                
                // Create and configure MediaPlayer
                mediaPlayer = android.media.MediaPlayer()
                
                try {
                    // Set data source - works with content:// URIs
                    mediaPlayer?.setDataSource(this, uri)
                    android.util.Log.d("RingtoneService", "✅ setDataSource successful")
                    
                    // Use AudioAttributes (modern approach, not deprecated)
                    val audioAttributes = android.media.AudioAttributes.Builder()
                        .setUsage(android.media.AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                        .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .setLegacyStreamType(android.media.AudioManager.STREAM_RING)
                        .build()
                    
                    mediaPlayer?.setAudioAttributes(audioAttributes)
                    android.util.Log.d("RingtoneService", "✅ AudioAttributes set (STREAM_RING)")
                    
                    // Set looping
                    mediaPlayer?.isLooping = true
                    android.util.Log.d("RingtoneService", "✅ Looping enabled")
                    
                    // Set error listener BEFORE prepare
                    mediaPlayer?.setOnErrorListener { mp, what, extra ->
                        android.util.Log.e("RingtoneService", "❌ MediaPlayer Error - What: $what, Extra: $extra")
                        android.util.Log.e("RingtoneService", "   What codes: MEDIA_ERROR_UNKNOWN=1, MEDIA_ERROR_SERVER_DIED=100")
                        android.util.Log.e("RingtoneService", "   Extra codes: MEDIA_ERROR_IO=-1004, MEDIA_ERROR_MALFORMED=-1007, etc.")
                        
                        // Try to recover
                        stopTone()
                        true // Return true = error handled
                    }
                    
                    // Set prepared listener
                    mediaPlayer?.setOnPreparedListener { mp ->
                        android.util.Log.i("RingtoneService", "✅ MediaPlayer PREPARED - Starting playback...")
                        try {
                            mp.start()
                            android.util.Log.i("RingtoneService", "🎵 RINGTONE PLAYING (looping)")
                        } catch (e: Exception) {
                            android.util.Log.e("RingtoneService", "❌ Failed to start playback", e)
                        }
                    }
                    
                    // Prepare asynchronously to avoid blocking
                    mediaPlayer?.prepareAsync()
                    android.util.Log.d("RingtoneService", "⏳ prepareAsync() called, waiting for onPrepared...")
                    
                } catch (e: java.io.IOException) {
                    android.util.Log.e("RingtoneService", "❌ IOException during MediaPlayer setup", e)
                    android.util.Log.e("RingtoneService", "   This usually means the URI is inaccessible: $uri")
                    stopTone()
                } catch (e: IllegalStateException) {
                    android.util.Log.e("RingtoneService", "❌ IllegalStateException during MediaPlayer setup", e)
                    stopTone()
                } catch (e: Exception) {
                    android.util.Log.e("RingtoneService", "❌ Unexpected exception during MediaPlayer setup", e)
                    stopTone()
                }
                
            } catch (e: Exception) {
                android.util.Log.e("RingtoneService", "❌ CRITICAL: Exception in playIncomingTone", e)
                e.printStackTrace()
            }
        }
    }

    private fun stopTone() {
        try {
            // Stop and release ToneGenerator
            toneGenerator?.stopTone()
            toneGenerator?.release()
            toneGenerator = null
            
            // Stop and release MediaPlayer with proper state checking
            mediaPlayer?.let { player ->
                try {
                    if (player.isPlaying) {
                        player.stop()
                        android.util.Log.d("RingtoneService", "🛑 MediaPlayer stopped")
                    }
                } catch (e: IllegalStateException) {
                    android.util.Log.w("RingtoneService", "MediaPlayer not in playback state", e)
                } catch (e: Exception) {
                    android.util.Log.e("RingtoneService", "Error stopping MediaPlayer", e)
                }
                
                try {
                    player.release()
                    android.util.Log.d("RingtoneService", "✅ MediaPlayer released")
                } catch (e: Exception) {
                    android.util.Log.e("RingtoneService", "Error releasing MediaPlayer", e)
                }
            }
            mediaPlayer = null
            
            // Restore original ring volume
            if (originalRingVolume != -1) {
                try {
                    val audioManager = getSystemService(Context.AUDIO_SERVICE) as android.media.AudioManager
                    audioManager.setStreamVolume(android.media.AudioManager.STREAM_RING, originalRingVolume, 0)
                    android.util.Log.d("RingtoneService", "🔊 Restored RING volume to: $originalRingVolume")
                } catch (e: Exception) {
                    android.util.Log.e("RingtoneService", "Error restoring volume", e)
                }
                originalRingVolume = -1
            }
        } catch (e: Exception) {
            android.util.Log.e("RingtoneService", "❌ Error in stopTone", e)
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
