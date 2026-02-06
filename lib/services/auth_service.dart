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
    print('🔐 [AUTH] tryAutoLogin() called');
    final savedToken = await storage.read(key: 'jwt_token');
    
    if (savedToken == null) {
       print('🔐 [AUTH] No saved token found');
       return false;
    }
    
    if (JwtDecoder.isExpired(savedToken)) {
       print('🔐 [AUTH] Saved token is EXPIRED');
       return false;
    }

    _token = savedToken;
    print('🔐 [AUTH] Token loaded (valid). Verifying with backend...');

    try {
      // Fetch fresh user data
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/auth/me'),
        headers: {'Authorization': 'Bearer $_token'},
      ).timeout(const Duration(seconds: 5)); // Add timeout

      if (response.statusCode == 200) {
        _currentUser = jsonDecode(response.body);
        print('🔐 [AUTH] Backend verification SUCCESS. User: ${_currentUser?['name']}');
        
        SocketService().connect(); // Connect to socket
        
        // Send FCM token to backend
        FcmService().sendTokenToBackend();
        
        return true;
      } else if (response.statusCode == 401) {
         print('🔐 [AUTH] Backend verification FAILED (401). Token invalid.');
         await logout();
         return false;
      } else {
         print('🔐 [AUTH] Backend verification returned status ${response.statusCode}. Keeping local token.');
         // Optimistic: Keep token, assume valid, socket might work or fail later.
         SocketService().connect();
         return true;
      }
    } catch (e) {
      print('🔐 [AUTH] Auto login network error: $e');
      print('🔐 [AUTH] Proceeding optimistically with local token.');
      
      // OPTIMISTIC LOGIN:
      // If network fails (timeout, no internet), we still start the socket with existing token.
      // Socket handles its own reconnection.
      SocketService().connect();
      return true;
    }
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
