package com.klubnikabytes.kchat

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class CallNotificationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        Log.d("CallNotificationReceiver", "🔔 Received action: $action")
        
        when (action) {
            ACTION_CALL_INCOMING -> {
                val ringtoneUri = intent.getStringExtra(EXTRA_RINGTONE_URI)
                Log.i("CallNotificationReceiver", "📞 Starting RingtoneService with URI: $ringtoneUri")
                
                // Start the RingtoneService
                val serviceIntent = Intent(context, RingtoneService::class.java)
                serviceIntent.action = RingtoneService.ACTION_START_RINGTONE
                serviceIntent.putExtra(RingtoneService.EXTRA_RINGTONE_URI, ringtoneUri)
                context.startService(serviceIntent)
                
                Log.i("CallNotificationReceiver", "✅ RingtoneService started")
            }
            ACTION_CALL_STOP -> {
                Log.i("CallNotificationReceiver", "🛑 Stopping ringtone")
                
                // Stop the RingtoneService
                val serviceIntent = Intent(context, RingtoneService::class.java)
                serviceIntent.action = RingtoneService.ACTION_STOP_RINGTONE
                context.startService(serviceIntent)
                
                Log.i("CallNotificationReceiver", "✅ Stop command sent")
            }
        }
    }
    
    companion object {
        const val ACTION_CALL_INCOMING = "com.klubnikabytes.kchat.CALL_INCOMING"
        const val ACTION_CALL_STOP = "com.klubnikabytes.kchat.CALL_STOP"
        const val EXTRA_RINGTONE_URI = "ringtone_uri"
    }
}
