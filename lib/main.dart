import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:whatsapp_clone/auth_wrapper.dart';

import 'package:whatsapp_clone/utils/web_utils.dart'; // Helper for web
import 'package:whatsapp_clone/services/socket_service.dart';
import 'package:whatsapp_clone/screens/call/incoming_call_screen.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await dotenv.load(fileName: ".env");

    if (kIsWeb) {
      preventBrowserContextMenu();
    }
    
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    if (kDebugMode) {
      print("Initialization error: $e");
    }
  }
  
  runApp(const MyApp());
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _initSocket();
  }

  void _initSocket() {
    try {
      final socketService = SocketService();
      socketService.initSocket();

      socketService.on('incoming-call', (data) {
          if (navigatorKey.currentState != null) {
            navigatorKey.currentState!.push(
              MaterialPageRoute(
                builder: (_) => IncomingCallScreen(
                  callerName: "User ${data['from'].toString().substring(0, 5)}...",
                  callerAvatar: "",
                  callType: data['callType'],
                  callData: data,
                )
              )
            );
          }
      });
    } catch (e) {
      debugPrint("Socket init error: $e");
    }
  }
  
  @override
  void dispose() {
    SocketService().dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Messaging App',
      theme: ThemeData(
         primaryColor: const Color(0xFF9575CD),
         colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF9575CD)),
         useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}


