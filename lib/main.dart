import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:whatsapp_clone/auth_wrapper.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:whatsapp_clone/utils/web_utils.dart'; // Helper for web
import 'package:whatsapp_clone/services/socket_service.dart';
import 'package:whatsapp_clone/screens/call/incoming_call_screen.dart';
import 'package:whatsapp_clone/services/webrtc_service.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:whatsapp_clone/services/fcm_service.dart';
import 'package:whatsapp_clone/services/notification_service.dart';
import 'package:whatsapp_clone/services/app_lifecycle_handler.dart';
import 'package:http/http.dart' as http;
import 'package:whatsapp_clone/config/api_config.dart';
import 'package:whatsapp_clone/utils/route_observer.dart';

// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Background message received: ${message.data}');

  // Update: Initialize Local Notifications for Background Isolation
  await NotificationService.initialize();
  
  // 🎯 HTTP ACK for Delivery (Offline/Background)
  // Ensure we tell the server we got it!
  if (message.data['messageId'] != null) {
     try {
       // We need to initialize Hive to get the token
       await Hive.initFlutter();
       var box = await Hive.openBox('user');
       final token = box.get('token');
       
       if (token != null) {
          final messageId = message.data['messageId'];
          // Use direct HTTP call to ACK
          // We have to hardcode or import ApiConfig. Since it's a static string usually, imports work.
          // But imports in isolate can be tricky if they depend on Flutter context. ApiConfig is pure Dart.
          
          // Assuming ApiConfig is imported or we construct URL manually to be safe or use imported one.
          // Let's rely on imports working (standard in Flutter).
          final url = Uri.parse('${ApiConfig.baseUrl}/api/messages/$messageId/ack');
          
          // Need http package. We should add import 'package:http/http.dart' as http;
          final response = await http.post(
             url,
             headers: {'Authorization': 'Bearer $token'}
          );
          print("Background ACK sent for $messageId: ${response.statusCode}");
       }
     } catch (e) {
       print("Background ACK Error: $e");
     }
  }

  await NotificationService.handleRemoteMessage(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // Register background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  // Initialize Notification Service
  await NotificationService.initialize();
  
  // Initialize FCM Service
  await FcmService().initialize();
  
  // Initialize Hive for local caching
  await Hive.initFlutter();
  
  try {
    await dotenv.load(fileName: ".env");

    if (kIsWeb) {
      preventBrowserContextMenu();
    }
  } catch (e) {
    if (kDebugMode) {
      print("Initialization error: $e");
    }
  }
  
  runApp(const MyApp());
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AppLifecycleHandler _lifecycleHandler = AppLifecycleHandler();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(_lifecycleHandler);
    _initSocket();
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycleHandler);
    super.dispose();
  }

  void _initSocket() {
    try {
      final socketService = SocketService();
      socketService.connect();

      // Listen to Call Events
      socketService.callStream.listen((event) {
          if (event['event'] == 'video_call_request') {
             // Guard: Prevent duplicate calls
             if (WebrtcService().isCallActive) {
                print("Ignored duplicate call request: Call already active");
                return; 
             }
             
             WebrtcService().setCallActive(true); // Lock state
             
             final data = event['data'];
             
             if (navigatorKey.currentState != null) {
                navigatorKey.currentState!.push(
                  MaterialPageRoute(
                    builder: (_) => IncomingCallScreen(
                      callerName: "User ${data['from']?.toString().substring(0, 5) ?? 'Unknown'}...",
                      callerAvatar: "",
                      callType: data['callType'],
                      callData: data,
                    )
                  )
                ).then((_) {
                   // When screen pops (back button / reject without endCall), ensure state is cleared if not handled
                   // Actually, if we accepted, we are "On Call" so isCallActive should remain True
                   // If we rejected, isCallActive should be False
                   // But "then" logic is hard to distinguish Accept vs Reject unless we return value
                   // Safety check: if call is not connected, reset.
                });
             }
          }
      });
    } catch (e) {
      debugPrint("Socket init error: $e");
    }
  }
  




  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: [routeObserver],
      scaffoldMessengerKey: scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      title: 'KlubTalk',
      theme: ThemeData(
         primaryColor: const Color(0xFFC92136),
         colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFC92136)),
         useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}


