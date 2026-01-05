import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:whatsapp_clone/auth_wrapper.dart';

import 'package:whatsapp_clone/utils/web_utils.dart'; // Helper for web

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    // Prevent default right-click menu on Web
    preventBrowserContextMenu();
  }
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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


