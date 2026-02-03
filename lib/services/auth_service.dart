import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:whatsapp_clone/config/api_config.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:whatsapp_clone/services/socket_service.dart';
import 'package:whatsapp_clone/services/fcm_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FlutterSecureStorage storage = const FlutterSecureStorage();
  String? _token;
  Map<String, dynamic>? _currentUser;

  bool get isAuthenticated => _token != null && !JwtDecoder.isExpired(_token!);
  String? get token => _token;
  Map<String, dynamic>? get currentUser => _currentUser;
  String? get currentUserId => _currentUser?['_id'];

  // Send OTP
  Future<void> sendOtp(String phone) async {
    final url = '${ApiConfig.baseUrl}/auth/send-otp';
    print('🔐 [AUTH DEBUG] Sending OTP to backend');
    print('   📍 URL: $url');
    print('   📱 Phone: $phone');
    
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone}),
      );

      print('   📬 Response Status: ${response.statusCode}');
      print('   📬 Response Body: ${response.body}');

      if (response.statusCode != 200) {
        final errorMsg = jsonDecode(response.body)['message'] ?? 'Failed to send OTP';
        print('   ❌ OTP Error: $errorMsg');
        throw Exception(errorMsg);
      }
      
      print('   ✅ OTP sent successfully');
    } catch (e) {
      print('   ❌ Exception sending OTP: $e');
      rethrow;
    }
  }

  // Verify OTP
  Future<Map<String, dynamic>> verifyOtp(String phone, String otp) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'otp': otp}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _token = data['token'];
      _currentUser = data['user'];
      await storage.write(key: 'jwt_token', value: _token);
      SocketService().connect(); // Connect to socket
      
      // Send FCM token to backend
      FcmService().sendTokenToBackend();
      
      return data;
    } else {
      throw Exception(jsonDecode(response.body)['message'] ?? 'Invalid OTP');
    }
  }

  // Auto Login
  Future<bool> tryAutoLogin() async {
    final savedToken = await storage.read(key: 'jwt_token');
    if (savedToken == null || JwtDecoder.isExpired(savedToken)) {
      return false;
    }

    _token = savedToken;
    try {
      // Fetch fresh user data
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/auth/me'),
        headers: {'Authorization': 'Bearer $_token'},
      );

      if (response.statusCode == 200) {
        _currentUser = jsonDecode(response.body);
        SocketService().connect(); // Connect to socket
        
        // Send FCM token to backend
        FcmService().sendTokenToBackend();
        
        return true;
      }
    } catch (e) {
      print('Auto login error: $e');
    }
    
    // If failed, clear token
    await logout();
    return false;
  }

  Future<void> updateProfile({required String name, String? about}) async {
    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/auth/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      },
      body: jsonEncode({'name': name, 'about': about}),
    );

    if (response.statusCode == 200) {
      _currentUser = jsonDecode(response.body);
    } else {
       throw Exception('Failed to update profile');
    }
  }

  Future<void> logout() async {
    _token = null;
    _currentUser = null;
    await storage.delete(key: 'jwt_token');
  }
}
