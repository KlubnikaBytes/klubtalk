import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  static String get baseUrl {
    String url;
    if (kIsWeb) {
      url = dotenv.env['VPS_BACKEND_URL'] ?? 'http://192.168.1.10:5000';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      url = dotenv.env['VPS_BACKEND_URL'] ?? 'http://192.168.1.10:5000';
    } else {
      // iOS, Windows, macOS, Linux
      url = dotenv.env['VPS_BACKEND_URL'] ?? 'http://127.0.0.1:5000';
    }
    // print("DEBUG: API Base URL: $url"); // Uncomment for spammy debug if needed, or rely on Socket/Http failures
    return url;
  }
  
  static String get authLoginEndpoint => '$baseUrl/auth/login';
  static String get uploadAvatarEndpoint => '$baseUrl/upload/avatar';
  static String get uploadImageEndpoint => '$baseUrl/upload/image';
  static String get uploadVoiceEndpoint => '$baseUrl/upload/voice';
  
  static String get chatsEndpoint => '$baseUrl/chats';
  static String get messagesEndpoint => '$baseUrl/messages';
}
