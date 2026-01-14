import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:whatsapp_clone/config/api_config.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  String? _token;
  Map<String, dynamic>? _currentUser;

  bool get isAuthenticated => _token != null && !JwtDecoder.isExpired(_token!);
  String? get token => _token;
  Map<String, dynamic>? get currentUser => _currentUser;
  String? get currentUserId => _currentUser?['_id'];

  // Send OTP
  Future<void> sendOtp(String phone) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/send-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone}),
    );

    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['message'] ?? 'Failed to send OTP');
    }
  }

  // Verify OTP
  Future<void> verifyOtp(String phone, String otp) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'otp': otp}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _token = data['token'];
      _currentUser = data['user'];
      await _storage.write(key: 'jwt_token', value: _token);
    } else {
      throw Exception(jsonDecode(response.body)['message'] ?? 'Invalid OTP');
    }
  }

  // Auto Login
  Future<bool> tryAutoLogin() async {
    final savedToken = await _storage.read(key: 'jwt_token');
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
        return true;
      }
    } catch (e) {
      print('Auto login error: $e');
    }
    
    // If failed, clear token
    await logout();
    return false;
  }

  Future<void> logout() async {
    _token = null;
    _currentUser = null;
    await _storage.delete(key: 'jwt_token');
  }
}
