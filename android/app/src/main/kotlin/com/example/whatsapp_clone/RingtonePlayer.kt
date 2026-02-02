package com.example.whatsapp_clone

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.util.Log

object RingtonePlayer {
    private var mediaPlayer: MediaPlayer? = null
    private var originalRingVolume: Int = -1
    
    @Synchronized
    fun playIncoming(context: Context, customUriString: String?) {
        Log.w("RingtonePlayer", "════════════════════════════════════")
        Log.w("RingtonePlayer", "🚀 playIncoming CALLED")
        Log.w("RingtonePlayer", "📥 Input URI: $customUriString")
        Log.w("RingtonePlayer", "════════════════════════════════════")
        
        stop()
        
        try {
            var uri: Uri? = null
            var uriSource = "none"
            
            // 1. Try Custom URI if provided
            if (customUriString != null && customUriString.isNotEmpty()) {
                try {
                    uri = Uri.parse(customUriString)
                    uriSource = "custom"
                    Log.d("RingtonePlayer", "🎵 Parsed Custom Ringtone URI: $uri")
                } catch (e: Exception) {
                    Log.e("RingtonePlayer", "❌ Failed to parse custom URI: $customUriString", e)
                    uri = null
                }
            }

            // 2. Fallback to System Default Ringtone
            if (uri == null) {
                try {
                    uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
                    uriSource = "system_default"
                    Log.d("RingtonePlayer", "🔔 Using System Default Ringtone: $uri")
                } catch (e: Exception) {
                    Log.e("RingtonePlayer", "❌ Failed to get system ringtone", e)
                }
            }
            
            // 3. Final Fallback to Notification Sound
            if (uri == null) {
                try {
                    uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                    uriSource = "notification"
                    Log.w("RingtonePlayer", "⚠️ Using Notification Sound as fallback: $uri")
                } catch (e: Exception) {
                    Log.e("RingtonePlayer", "❌ All URI fallbacks failed", e)
                }
            }
            
            if (uri == null) {
                Log.e("RingtonePlayer", "❌ CRITICAL: Could not resolve any ringtone URI")
                return
            }

            Log.i("RingtonePlayer", "🎵 Final Ringtone URI: $uri (source: $uriSource)")

            // Get AudioManager and set volume to maximum
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            originalRingVolume = audioManager.getStreamVolume(AudioManager.STREAM_RING)
            val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_RING)
            audioManager.setStreamVolume(AudioManager.STREAM_RING, maxVolume, 0)
            Log.d("RingtonePlayer", "🔊 Volume: $originalRingVolume → $maxVolume (max)")
            
            // Create and configure MediaPlayer
            mediaPlayer = MediaPlayer()
            
            try {
                // Set data source - works with content:// URIs
                mediaPlayer?.setDataSource(context, uri)
                Log.d("RingtonePlayer", "✅ setDataSource successful")
                
                // Use AudioAttributes (modern approach, not deprecated)
                val audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .setLegacyStreamType(AudioManager.STREAM_RING)
                    .build()
                
                mediaPlayer?.setAudioAttributes(audioAttributes)
                Log.d("RingtonePlayer", "✅ AudioAttributes set (STREAM_RING)")
                
                // Set looping
                mediaPlayer?.isLooping = true
                Log.d("RingtonePlayer", "✅ Looping enabled")
                
                // Set error listener BEFORE prepare
                mediaPlayer?.setOnErrorListener { mp, what, extra ->
                    Log.e("RingtonePlayer", "❌ MediaPlayer Error - What: $what, Extra: $extra")
                    Log.e("RingtonePlayer", "   What codes: MEDIA_ERROR_UNKNOWN=1, MEDIA_ERROR_SERVER_DIED=100")
                    Log.e("RingtonePlayer", "   Extra codes: MEDIA_ERROR_IO=-1004, MEDIA_ERROR_MALFORMED=-1007, etc.")
                    
                    // Try to recover
                    stop()
                    true // Return true = error handled
                }
                
                // Set prepared listener
                mediaPlayer?.setOnPreparedListener { mp ->
                    Log.i("RingtonePlayer", "✅ MediaPlayer PREPARED - Starting playback...")
                    try {
                        mp.start()
                        Log.i("RingtonePlayer", "🎵 RINGTONE PLAYING (looping)")
                    } catch (e: Exception) {
                        Log.e("RingtonePlayer", "❌ Failed to start playback", e)
                    }
                }
                
                // Prepare asynchronously to avoid blocking
                mediaPlayer?.prepareAsync()
                Log.d("RingtonePlayer", "⏳ prepareAsync() called, waiting for onPrepared...")
                
            } catch (e: java.io.IOException) {
                Log.e("RingtonePlayer", "❌ IOException during MediaPlayer setup", e)
                Log.e("RingtonePlayer", "   This usually means the URI is inaccessible: $uri")
                stop()
            } catch (e: IllegalStateException) {
                Log.e("RingtonePlayer", "❌ IllegalStateException during MediaPlayer setup", e)
                stop()
            } catch (e: Exception) {
                Log.e("RingtonePlayer", "❌ Unexpected exception during MediaPlayer setup", e)
                stop()
            }
            
        } catch (e: Exception) {
            Log.e("RingtonePlayer", "❌ CRITICAL: Exception in playIncoming", e)
            e.printStackTrace()
        }
    }
    
    @Synchronized
    fun stop() {
        try {
            // Stop and release MediaPlayer with proper state checking
            mediaPlayer?.let { player ->
                try {
                    if (player.isPlaying) {
                        player.stop()
                        Log.d("RingtonePlayer", "🛑 MediaPlayer stopped")
                    }
                } catch (e: IllegalStateException) {
                    Log.w("RingtonePlayer", "MediaPlayer not in playback state", e)
                } catch (e: Exception) {
                    Log.e("RingtonePlayer", "Error stopping MediaPlayer", e)
                }
                
                try {
                    player.release()
                    Log.d("RingtonePlayer", "✅ MediaPlayer released")
                } catch (e: Exception) {
                    Log.e("RingtonePlayer", "Error releasing MediaPlayer", e)
                }
            }
            mediaPlayer = null
            
            // Restore original ring volume
            if (originalRingVolume != -1) {
                try {
                    // We need a context to get AudioManager, but we can skip this for now
                    // Volume will be restored on next call
                    Log.d("RingtonePlayer", "🔊 Original volume was: $originalRingVolume (will restore on next call)")
                } catch (e: Exception) {
                    Log.e("RingtonePlayer", "Error noting volume", e)
                }
                originalRingVolume = -1
            }
        } catch (e: Exception) {
            Log.e("RingtonePlayer", "❌ Error in stop", e)
            e.printStackTrace()
        }
    }
}
