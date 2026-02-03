import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  static String get baseUrl {
    String url;
    if (kIsWeb) {
      // VPS Backend (Production)
      url = dotenv.env['VPS_BACKEND_URL'] ?? 'http://72.62.73.45:6000';
      // Local Development: 'http://localhost:6000'
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      // VPS Backend (Production)
      url = dotenv.env['VPS_BACKEND_URL'] ?? 'http://72.62.73.45:6000';
      // Local Development: 'http://192.168.1.7:6000'
    } else {
      // iOS, Windows, macOS, Linux
      // VPS Backend (Production)
      url = dotenv.env['VPS_BACKEND_URL'] ?? 'http://72.62.73.45:6000';
      // Local Development: 'http://127.0.0.1:6000'
    }
    return url;
  }
  
  static String get authLoginEndpoint => '$baseUrl/auth/login';
  static String get uploadAvatarEndpoint => '$baseUrl/upload/avatar';
  static String get uploadImageEndpoint => '$baseUrl/upload/image';
  static String get uploadVoiceEndpoint => '$baseUrl/upload/voice';
  
  static String get chatsEndpoint => '$baseUrl/chats';
  static String get messagesEndpoint => '$baseUrl/messages';

  // Helper to resolve full image URL
  static String getFullImageUrl(String? path) {
    if (path == null || path.isEmpty) return "";
    if (path.startsWith("http")) return path;
    return "$baseUrl$path";
  }
}
