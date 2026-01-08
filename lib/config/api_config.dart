import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  static String get baseUrl {
    if (kIsWeb) {
      return dotenv.env['VPS_BACKEND_URL'] ?? 'http://127.0.0.1:5000';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return dotenv.env['VPS_BACKEND_URL'] ?? 'http://10.0.2.2:5000';
    } else {
      // iOS, Windows, macOS, Linux
      return dotenv.env['VPS_BACKEND_URL'] ?? 'http://127.0.0.1:5000';
    }
  }
  
  static String get authLoginEndpoint => '$baseUrl/auth/login';
  static String get uploadAvatarEndpoint => '$baseUrl/upload/avatar';
  static String get uploadImageEndpoint => '$baseUrl/upload/image';
  static String get uploadVoiceEndpoint => '$baseUrl/upload/voice';
  
  static String get chatsEndpoint => '$baseUrl/chats';
  static String get messagesEndpoint => '$baseUrl/messages';
}
