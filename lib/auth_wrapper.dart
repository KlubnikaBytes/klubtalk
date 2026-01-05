import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:whatsapp_clone/layout/responsive_layout.dart';
import 'package:whatsapp_clone/screens/login_screen.dart';
import 'package:whatsapp_clone/screens/chat_list_screen.dart';
import 'package:whatsapp_clone/screens/web_layout_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
           return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) {
          // Return Responsive Layout
          return const ResponsiveLayout(
            mobileScaffold: MobileChatLayout(),
            webScaffold: WebLayoutScreen(),
          );
        }
        return const LoginScreen();
      },
    );
  }
}
