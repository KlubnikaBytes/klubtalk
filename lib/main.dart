import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:whatsapp_clone/auth_wrapper.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:whatsapp_clone/utils/chat_session_store.dart';

import 'package:whatsapp_clone/utils/web_utils.dart'; // Helper for web
import 'package:whatsapp_clone/services/socket_service.dart';
import 'package:whatsapp_clone/screens/call/incoming_call_screen.dart';
import 'package:whatsapp_clone/screens/call/call_screen.dart'; // Added missing import
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

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Background message received: ${message.data}');

  // ⚡ OPTIMIZATION: Only initialize NotificationService if we need to show notifications
  // For call-related messages, initialize; for others, skip to reduce overhead
  final messageType = message.data['type'];
  if (messageType == 'call' || messageType == 'call_end') {
     await NotificationService.initialize();
  }
  
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

  // Only handle call notifications in background
  if (messageType == 'call' || messageType == 'call_end') {
     await NotificationService.handleRemoteMessage(message);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Initialize Hive (Critical for Cache)
  try {
    await Hive.initFlutter();
    // Initialize ChatSessionStore to load deleted chats
    await ChatSessionStore().init(); 
  } catch (e) {
    print("❌ Hive/Store Init Failed: $e");
  }

  // 2. Initialize Firebase (Critical for FCM/Auth verification)
  try {
    if (!kIsWeb) {
      await Firebase.initializeApp();
      // Register background handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    }
  } catch (e) {
    print("❌ Firebase Init Failed: $e");
  }

  // 3. Initialize Services
  try {
    await NotificationService.initialize();
    if (!kIsWeb) {
      await FcmService().initialize();
    }
  } catch (e) {
    print("❌ Service Init Failed: $e");
  }

  // 4. Load Environment
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print("❌ DotEnv Init Failed: $e");
  }

  if (kIsWeb) {
    preventBrowserContextMenu();
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
      socketService.callStream.listen((event) async { // Made async
          if (event['event'] == 'video_call_request') {
             final timestamp = DateTime.now().toIso8601String();
             print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
             print("📞 [$timestamp] SOCKET: video_call_request received");
             print("📞 [$timestamp] isCallActive: ${WebrtcService().isCallActive}");
             print("📞 [$timestamp] pendingDecline: ${WebrtcService().pendingDecline}");
             
             // Guard: Prevent duplicate calls
             if (WebrtcService().isCallActive) {
                print("⏭️ [$timestamp] SKIP: Call already active");
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
                return; 
             }
             
             WebrtcService().setCallActive(true); // Lock state
             final data = event['data'];
              
              // 🔍 COLD START CHECK:
              // If WebrtcService is waiting for this offer (auto-accept from notification),
              // we process it immediately and DO NOT show Incoming Call Screen.
              if (WebrtcService().pendingAutoAccept) {
                 print("🚀 [$timestamp] Auto-Accepting Call (Cold Start)...");
                 final isVideo = data['callType'] == 'video';
                 
                 // Call full handleIncomingCall with complete data (now includes offer)
                 // This will do all necessary initialization - AWAIT to ensure ready
                 await WebrtcService().handleIncomingCall(data);
                 
                 // 🧭 NAVIGATE TO ACTIVE CALL SCREEN from Cold Start
                 if (navigatorKey.currentState != null) {
                    print("🧭 [$timestamp] Navigating to CallScreen (Cold Start)");
                    // Use push instead of pushReplacement so user can return
                    navigatorKey.currentState!.push(
                      MaterialPageRoute(
                        builder: (_) => CallScreen(
                          peerName: "User ${data['from']?.toString().substring(0, 5) ?? 'Unknown'}...",
                          peerAvatar: "", // Can resolve later
                          isCaller: false,
                          isVideo: isVideo,
                          peerId: data['from'],
                        )
                      )
                    );
                 }
                 print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
                 return;
              }

              // 🔻 DECLINE CHECK:
              // If user already declined from notification, skip showing IncomingCallScreen
              if (WebrtcService().pendingDecline) {
                 print("🔻 [$timestamp] BLOCKED: Call already declined from notification");
                 print("🔻 [$timestamp] Resetting isCallActive and ignoring socket event");
                 WebrtcService().setCallActive(false); // Reset lock
                 print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
                 return;
              }
              
              // 🔻 ADDITIONAL CHECK: If this caller was recently declined, block them
              if (WebrtcService().declinedCallerId == data['from']) {
                 print("🔻 [$timestamp] BLOCKED: This caller (${data['from']}) was already declined");
                 print("🔻 [$timestamp] Resetting isCallActive and ignoring socket event");
                 WebrtcService().setCallActive(false); // Reset lock
                 print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
                 return;
              }

              print("📞 [$timestamp] Showing IncomingCallScreen");
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
                    // When screen pops (back button), we might need cleanup
                    // But usually endCall handles it.
                    if (WebrtcService().isCallActive) {
                       // If we popped but call is active, it means we answered -> CallScreen replaces this.
                       // If we popped and call is NOT active, it means we rejected/ended.
                       WebrtcService().setCallActive(false);
                    }
                 });
              }
              print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
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
         colorScheme: ColorScheme.fromSeed(
           seedColor: const Color(0xFFC92136),
           surfaceTint: Colors.transparent, // Disable Material3 tinting
         ),
         useMaterial3: true,
         scaffoldBackgroundColor: Colors.white, // Force white base
         appBarTheme: const AppBarTheme(
           surfaceTintColor: Colors.transparent, // No tint on AppBar
           elevation: 0,
         ),
      ),
      home: const AuthWrapper(),
    );
  }
}
