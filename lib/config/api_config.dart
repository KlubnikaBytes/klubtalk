import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  static String get baseUrl {
    String url;
    if (kIsWeb) {
      // VPS Backend (Production)
      try {
        url = dotenv.env['VPS_BACKEND_URL'] ?? 'http://72.62.73.45:7000';
      } catch (_) {
        url = 'http://72.62.73.45:7000'; // Fallback if dotenv not initialized
      }
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      // VPS Backend (Production)
      try {
        url = dotenv.env['VPS_BACKEND_URL'] ?? 'http://72.62.73.45:7000';
      } catch (_) {
        url = 'http://72.62.73.45:7000'; // Fallback
      }
    } else {
      // iOS, Windows, macOS, Linux
      try {
        url = dotenv.env['VPS_BACKEND_URL'] ?? 'http://72.62.73.45:7000';
      } catch (_) {
        url = 'http://72.62.73.45:7000'; // Fallback
      }
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
