import 'dart:typed_data'; // Added for Int64List
import 'package:flutter/material.dart'; // Added for Color
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Added
import 'package:permission_handler/permission_handler.dart'; // Added
import 'package:android_intent_plus/android_intent.dart'; // For fallback broadcast

class NotificationService {
  static final FlutterLocalNotificationsPlugin _fln = 
      FlutterLocalNotificationsPlugin();

  /// Show Call Notification with Actions
  static Future<void> _showCallNotification(RemoteMessage message) async {
      final data = message.data;
      final callerName = data['callerName'] ?? 'Unknown';
      final callType = data['callType'] ?? 'voice';
      final callerId = data['callerId'] ?? ''; 
      
      final id = 12345; // Constant ID to ensure we can cancel it exactly
      
      print("📞 Showing Call Notification: $callerName ($callType)");

      // 🎵 START RINGTONE via BroadcastReceiver
      try {
        final prefs = await SharedPreferences.getInstance();
        final String ringtoneUri = prefs.getString('call_ringtone') ?? '';
        
        print("🔍 Sending broadcast to start ringtone with URI: $ringtoneUri");
        
        // Send broadcast to CallNotificationReceiver (works from background!)
        final intent = AndroidIntent(
          action: 'com.example.whatsapp_clone.CALL_INCOMING',
          package: 'com.example.whatsapp_clone',
          arguments: <String, dynamic>{'ringtone_uri': ringtoneUri},
          flags: <int>[268435456], // FLAG_INCLUDE_STOPPED_PACKAGES
        );
        await intent.sendBroadcast();
        
        print("✅ Ringtone broadcast sent successfully");
      } catch (e) {
        print("❌ ERROR sending broadcast: $e");
      }

      await _fln.show(
        id,
        'Incoming $callType call',
        '$callerName is calling...',
        NotificationDetails( 
          android: AndroidNotificationDetails(
            'incoming_call_channel_v8', // Updated Channel ID to v8
            'Incoming Calls V8',
            channelDescription: 'Rings like a real phone call',
            importance: Importance.max,
            priority: Priority.max,
            
            // 🔄 MAKE IT RING CONTINUOUSLY
            additionalFlags: Int32List.fromList([4]), // FLAG_INSISTENT
            icon: '@drawable/notification_icon',
            
            // 🔊 SOUND handled by native MediaPlayer, vibration by notification
            playSound: false, // Native MediaPlayer plays the actual ringtone
            enableVibration: true,
            vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000, 500, 1000]), // Long pattern
            
            // Behavior
            fullScreenIntent: true,
            ongoing: true,
            autoCancel: false,
            visibility: NotificationVisibility.public,
            category: AndroidNotificationCategory.call,
            
            // Actions
            actions: [
               AndroidNotificationAction('ACCEPT', 'Accept', showsUserInterface: true),
               AndroidNotificationAction('DECLINE', 'Decline', showsUserInterface: true),
            ],
            timeoutAfter: 60000, // 60s timeout
          ),
        ),
        // Payload: type_callId_callerId_callType
        payload: 'call_${data['callId']}_${callerId}_$callType',
      );
  }

  /// Show Missed Call Notification
  static Future<void> showMissedCallNotification(String callerName) async {
     final id = DateTime.now().millisecondsSinceEpoch;
     await _fln.show(
        id,
        "Missed Call",
        "You missed a call from $callerName",
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'missed_call_channel',
            'Missed Calls',
            category: AndroidNotificationCategory.missedCall,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@drawable/notification_icon',
          ),
        ),
      );
  }

  /// Initialize local notifications
  static Future<void> initialize() async {
    print('🔔 Initializing NotificationService...');
    
    const AndroidInitializationSettings androidSettings = 
        AndroidInitializationSettings('@drawable/notification_icon');
    
    await _fln.initialize(
      const InitializationSettings(android: androidSettings),
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
         final payload = response.payload;
         print("🔔 Notification Action Clicked: ${response.actionId} (Payload: $payload)");
         // Just cancel notification so it clears. App is already brought to front by OS.
         await cancelCallNotification();
      },
    );

    // Check if app was launched by notification
    try {
        final NotificationAppLaunchDetails? launchDetails = 
            await _fln.getNotificationAppLaunchDetails();
            
        if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
             print("🚀 App launched via Notification: ${launchDetails.notificationResponse?.payload}");
             // Clear notification
             await cancelCallNotification();
        }
    } catch (e) {
        print("Error checking launch details: $e");
    }

    // Create message channel
    await _fln
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'message_channel',
            'Messages',
            description: 'Message notifications',
            importance: Importance.max,
          ),
        );
        
    // Get System Ringtone URI from Native
    String? ringtoneUri;
    try {
      const channel = MethodChannel('com.example.whatsapp_clone/ringtone');
      ringtoneUri = await channel.invokeMethod<String>('getSystemRingtoneUri');
      print('🎵 Native System Ringtone URI: $ringtoneUri');
    } catch (e) {
      print('Error getting system ringtone: $e');
    }

    // 1️⃣ INCOMING CALL CHANNEL (Rings like phone)
    await _fln
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
           AndroidNotificationChannel(
            'incoming_call_channel_v8',
            'Incoming Calls V8',
            description: 'Rings like a real phone call',
            importance: Importance.max,
            
            // 🔊 SOUND handled by native MediaPlayer, vibration by notification
            playSound: false, // Native MediaPlayer plays the actual ringtone
            enableVibration: true,
            vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000, 500, 1000]),
          ),
        );

    // 3️⃣ MISSED CALL CHANNEL
    await _fln
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'missed_call_channel',
            'Missed Calls',
            description: 'Missed call alerts',
            importance: Importance.high,
            playSound: true,
          ),
        );
        
    print('✅ NotificationService initialized');
  }

  /// Handle remote message (foreground & background)
  static Future<void> handleRemoteMessage(RemoteMessage message) async {
    final type = message.data['type'];
    print('📨 Handling message type: $type');

    if (type == 'message') {
      await _showMessageNotification(message);
    } else if (type == 'message_read') {
      await cancelMessageNotification(message.data['messageId']);
    } else if (type == 'call') {
      await _showCallNotification(message);
    } else if (type == 'call_end') {
      await cancelCallNotification();
      // Logic for Missed Call could go here if we track state
    }
  }

  /// Show message notification
  static Future<void> _showMessageNotification(RemoteMessage message) async {
    final data = message.data;
    final id = data['messageId']?.hashCode ?? DateTime.now().millisecondsSinceEpoch;

    // Load Preferences
    final prefs = await SharedPreferences.getInstance();
    final String? toneUri = prefs.getString('message_tone');
    final String vibrateType = prefs.getString('message_vibrate') ?? 'Default';
    
    // Determine Vibration Pattern
    Int64List? vibrationPattern;
    if (vibrateType == 'Off') {
       vibrationPattern = Int64List.fromList([0]); // Effectively no vibration
    } else if (vibrateType == 'Short') {
       vibrationPattern = Int64List.fromList([0, 200, 100, 200]);
    } else if (vibrateType == 'Long') {
       vibrationPattern = Int64List.fromList([0, 1000, 500, 1000]);
    } else {
       // Default
       vibrationPattern = Int64List.fromList([0, 250, 250, 250]);
    }

    // Determine Channel ID based on sound to allow changes (Channels are immutable)
    final String channelId = 'message_channel_${toneUri?.hashCode ?? 'default'}';
    final String channelName = 'Messages'; // Can keep name same, ID distinct
    
    print("🔔 Creating Message Channel: ID=$channelId, ToneURI='$toneUri', Vibrate=$vibrateType");

    // Create Channel Dynamically
    final AndroidNotificationChannel channel = AndroidNotificationChannel(
      channelId,
      channelName,
      importance: Importance.max,
      playSound: true,
      enableVibration: vibrateType != 'Off',
      vibrationPattern: vibrationPattern,
      sound: toneUri != null && toneUri.isNotEmpty 
          ? UriAndroidNotificationSound(toneUri) 
          : null, // Null uses default notification sound
    );

    await _fln
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await _fln.show(
      id,
      data['senderName'] ?? 'New Message',
      data['message'] ?? '',
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@drawable/notification_icon',
          largeIcon: const DrawableResourceAndroidBitmap('@drawable/notification_icon'),
          sound: channel.sound,
          enableVibration: channel.enableVibration,
          vibrationPattern: channel.vibrationPattern,
        ),
      ),
      payload: 'message_${data['chatId']}_${data['senderId']}',
    );
    
    print('✅ Showed notification for message: ${data['messageId']}');
  }
  


  /// Cancel a specific message notification
  static Future<void> cancelMessageNotification(String? messageId) async {
    if (messageId == null) return;
    final int id = messageId.hashCode;
    await _fln.cancel(id);
    print("❌ Message notification cancelled (ID: $id from msgId: $messageId)");
  }

  static Future<void> cancelCallNotification() async {
      // 🛑 STOP RINGTONE via Broadcast
      try {
        final intent = AndroidIntent(
          action: 'com.example.whatsapp_clone.CALL_STOP',
          package: 'com.example.whatsapp_clone',
          flags: <int>[268435456], // FLAG_INCLUDE_STOPPED_PACKAGES
        );
        await intent.sendBroadcast();
        print("🛑 Ringtone stop broadcast sent");
      } catch (e) {
        print("Error stopping ringtone: $e");
      }
      
      await _fln.cancel(12345);
      print("❌ Call notification cancelled (ID: 12345)");
  }



}
