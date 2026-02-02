package com.example.whatsapp_clone

import android.app.Application
import android.content.Context
import android.content.Intent
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

class MyApplication : Application() {
    private lateinit var backgroundEngine: FlutterEngine
    
    override fun onCreate() {
        super.onCreate()
        Log.d("MyApplication", "🚀 Application onCreate")
        
        // Create a background FlutterEngine for use by background isolates
        backgroundEngine = FlutterEngine(this)
        backgroundEngine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )
        
        // Cache it so FCM background handler can use it
        FlutterEngineCache.getInstance().put("background_engine", backgroundEngine)
        
        // Register MethodChannel for sending broadcasts
        setupBroadcastChannel(backgroundEngine)
        
        Log.d("MyApplication", "✅ Background engine setup complete")
    }
    
    private fun setupBroadcastChannel(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "com.example.whatsapp_clone/broadcast")
            .setMethodCallHandler { call, result ->
                Log.d("BroadcastChannel", "📨 Method called: ${call.method}")
                
                when (call.method) {
                    "sendCallIncoming" -> {
                        val ringtoneUri = call.argument<String>("ringtoneUri") ?: ""
                        Log.i("BroadcastChannel", "🎵 Sending CALL_INCOMING broadcast with URI: $ringtoneUri")
                        
                        val intent = Intent("com.example.whatsapp_clone.CALL_INCOMING")
                        intent.setPackage(packageName)
                        intent.putExtra("ringtone_uri", ringtoneUri)
                        sendBroadcast(intent)
                        
                        Log.i("BroadcastChannel", "✅ Broadcast sent")
                        result.success(true)
                    }
                    "sendCallStop" -> {
                        Log.i("BroadcastChannel", "🛑 Sending CALL_STOP broadcast")
                        
                        val intent = Intent("com.example.whatsapp_clone.CALL_STOP")
                        intent.setPackage(packageName)
                        sendBroadcast(intent)
                        
                        Log.i("BroadcastChannel", "✅ Broadcast sent")
                        result.success(true)
                    }
                    else -> {
                        Log.w("BroadcastChannel", "⚠️ Unknown method: ${call.method}")
                        result.notImplemented()
                    }
                }
            }
    }
}
