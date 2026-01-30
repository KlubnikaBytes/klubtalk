import 'package:flutter/widgets.dart';
import 'package:whatsapp_clone/services/socket_service.dart';

class AppLifecycleHandler with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        // App going to background
        // User requesting to NOT disconnect: "dont disconnect user if the user has internet or app running in backgroud"
        print('📴 App paused - Keeping socket alive as requested');
        // SocketService().disconnect(); // REMOVED
        break;
        
      case AppLifecycleState.resumed:
        // App coming back to foreground - reconnect socket
        print('🔄 App resumed - reconnecting socket');
        SocketService().connect();
        break;
        
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      default:
        // No action needed
        break;
    }
  }
}
