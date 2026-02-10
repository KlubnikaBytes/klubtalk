import 'package:flutter/material.dart';
import 'package:whatsapp_clone/layout/responsive_layout.dart';
import 'package:whatsapp_clone/screens/login_screen.dart';
import 'package:whatsapp_clone/screens/chat_list_screen.dart';
import 'package:whatsapp_clone/screens/web_layout_screen.dart';
import 'package:whatsapp_clone/services/auth_service.dart';
import 'package:whatsapp_clone/widgets/common/skeletons.dart';


class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  late Future<bool> _autoLoginFuture;

  @override
  void initState() {
    super.initState();
    _autoLoginFuture = AuthService().tryAutoLogin();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _autoLoginFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
           return const Scaffold(body: ChatListSkeleton());
        }

        if (snapshot.hasData && snapshot.data == true) {
          // Logged in
          return const ResponsiveLayout(
            mobileScaffold: MobileChatLayout(),
            webScaffold: WebLayoutScreen(),
          );
        }

        // Not logged in
        return const LoginScreen();
      },
    );
  }
}
