package com.example.whatsapp_clone

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.util.Log

class RingtoneService : Service() {
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d("RingtoneService", "🔔 Service started")
        
        val action = intent?.action
        Log.d("RingtoneService", "Action: $action")
        
        when (action) {
            ACTION_START_RINGTONE -> {
                val ringtoneUri = intent.getStringExtra(EXTRA_RINGTONE_URI)
                Log.i("RingtoneService", "🎵 Starting ringtone with URI: $ringtoneUri")
                RingtonePlayer.playIncoming(applicationContext, ringtoneUri)
            }
            ACTION_STOP_RINGTONE -> {
                Log.i("RingtoneService", "🛑 Stopping ringtone")
                RingtonePlayer.stop()
                stopSelf()
            }
        }
        
        return START_NOT_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d("RingtoneService", "Service destroyed, stopping ringtone")
        RingtonePlayer.stop()
    }
    
    companion object {
        const val ACTION_START_RINGTONE = "com.example.whatsapp_clone.START_RINGTONE"
        const val ACTION_STOP_RINGTONE = "com.example.whatsapp_clone.STOP_RINGTONE"
        const val EXTRA_RINGTONE_URI = "ringtone_uri"
    }
}
