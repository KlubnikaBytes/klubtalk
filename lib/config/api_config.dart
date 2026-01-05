import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  static String get baseUrl => dotenv.env['VPS_BACKEND_URL'] ?? 'http://localhost:3000';
  
  static const String uploadAudioEndpoint = '$baseUrl/upload/audio';
  static const String uploadImageEndpoint = '$baseUrl/upload/image';
  static const String uploadVideoEndpoint = '$baseUrl/upload/video';
}
