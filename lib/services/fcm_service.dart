import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:whatsapp_clone/config/api_config.dart';
import 'package:whatsapp_clone/services/auth_service.dart';
import 'package:whatsapp_clone/main.dart'; // Circular?
import 'package:whatsapp_clone/screens/chat_screen.dart';
import 'package:whatsapp_clone/screens/call/incoming_call_screen.dart';
import 'package:whatsapp_clone/models/contact.dart';
import 'package:whatsapp_clone/services/notification_service.dart';

// Removed redundant _firebaseMessagingBackgroundHandler as it's now in main.dart

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  String? _currentToken;

  /// Initialize FCM and set up handlers
  Future<void> initialize() async {
    // Initialize local notifications
    await _initializeLocalNotifications();
    
    // Request notification permissions
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    print('FCM Permission status: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      // Get FCM token
      try {
        _currentToken = await _messaging.getToken();
        print('FCM TOKEN: $_currentToken');
      } catch (e) {
        print('Error getting FCM token: $e');
      }

      // Set up foreground message handler
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);



      // Handle notification tap when app is in background/terminated
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Check if app was opened from a notification
      RemoteMessage? initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        _currentToken = newToken;
        print('FCM token refreshed: $newToken');
        sendTokenToBackend();
      });
    }
  }

  /// Initialize local notifications with Android channels
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channels for Android
    await _createNotificationChannels();
  }

  /// Create Android notification channels
  Future<void> _createNotificationChannels() async {
    // Message channel - default priority
    const AndroidNotificationChannel messageChannel = AndroidNotificationChannel(
      'message_channel',
      'Messages',
      description: 'Notifications for new messages',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    // Call channel - high priority with full-screen intent
    const AndroidNotificationChannel callChannel = AndroidNotificationChannel(
      'call_channel',
      'Calls',
      description: 'Incoming call notifications',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(messageChannel);

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(callChannel);

    print('Notification channels created: message_channel, call_channel');
  }

  /// Handle foreground messages - show local notification
  void _handleForegroundMessage(RemoteMessage message) {
    print('Foreground message received: ${message.data}');
    
    final data = message.data;
    final type = data['type'];

    if (type == 'message' || type == 'message_read') {
      // Delegate message notifications to NotificationService
      NotificationService.handleRemoteMessage(message);
    } else if (type == 'call') {
      // Force notification even if app is in foreground to ensure Ringtone plays
      print('📞 Call FCM received in foreground - Triggering NotificationService for Ringtone');
      NotificationService.handleRemoteMessage(message);
    }
  }

  /// Show local notification for messages
  Future<void> _showMessageNotification({
    required String title,
    required String body,
    required String payload,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'message_channel',
      'Messages',
      channelDescription: 'Notifications for new messages',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// Show high-priority call notification with full-screen intent
  Future<void> _showCallNotification({
    required String callerName,
    required String callType,
    required String payload,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'call_channel',
      'Calls',
      channelDescription: 'Incoming call notifications',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      color: Color(0xFFDC143C), // Red color for calls
      icon: '@mipmap/ic_launcher',
      fullScreenIntent: true, // Enable full-screen intent
      category: AndroidNotificationCategory.call,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'Incoming $callType call',
      '$callerName is calling...',
      notificationDetails,
      payload: payload,
    );
  }

  /// Handle notification tap from local notifications
  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload == null) return;
    
    try {
      final data = jsonDecode(response.payload!);
      _handleNotificationTap(RemoteMessage(data: data));
    } catch (e) {
      print('Error handling notification tap: $e');
    }
  }

  /// Handle notification tap (app opened from notification)
  void _handleNotificationTap(RemoteMessage message) {
    print('Notification tapped: ${message.data}');
    
    final data = message.data;
    final type = data['type'];

    if (type == 'message') {
      _handleMessageNavigation(data);
    } else if (type == 'call') {
      _handleCallNavigation(data);
    }
  }

  /// Navigate to chat screen
  void _handleMessageNavigation(Map<String, dynamic> data) {
    final chatId = data['chatId'];
    final peerId = data['peerId'];
    final senderName = data['senderName'] ?? 'Chat';

    if (chatId != null && navigatorKey.currentState != null) {
      navigatorKey.currentState!.push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            contact: Contact(name: senderName, profileImage: '', isOnline: false),
            peerId: peerId ?? '',
            chatId: chatId,
            isGroup: false,
          ),
        ),
      );
    }
  }

  /// Navigate to incoming call screen
  void _handleCallNavigation(Map<String, dynamic> data) {
    final callType = data['callType'];
    final from = data['from'];
    final callerName = data['callerName'] ?? 'Unknown';
    
    if (navigatorKey.currentState != null) {
      navigatorKey.currentState!.push(
        MaterialPageRoute(
          builder: (_) => IncomingCallScreen(
            callerName: callerName,
            callerAvatar: '',
            callType: callType ?? 'video',
            callData: {
              'from': from,
              'callType': callType,
              'offer': data['offer'] != null ? jsonDecode(data['offer']) : null,
            },
          ),
        ),
      );
    }
  }

  /// Send FCM token to backend
  Future<void> sendTokenToBackend() async {
    if (_currentToken == null) {
      print('No FCM token to send');
      return;
    }

    final token = AuthService().token;
    if (token == null) {
      print('Not authenticated, cannot send FCM token');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'fcmToken': _currentToken}),
      );

      if (response.statusCode == 200) {
        print('FCM token sent to backend successfully');
      } else {
        print('Failed to send FCM token: ${response.statusCode}');
      }
    } catch (e) {
      print('Error sending FCM token to backend: $e');
    }
  }

  /// Get current FCM token
  String? get currentToken => _currentToken;
}
