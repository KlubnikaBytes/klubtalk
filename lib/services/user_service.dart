import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:whatsapp_clone/services/auth_service.dart';
import 'package:whatsapp_clone/config/api_config.dart';
import 'package:whatsapp_clone/models/user_model.dart';
import 'package:whatsapp_clone/services/media_upload_service.dart';

class UserService {

  String get currentUid => AuthService().currentUserId ?? '';

  Future<Map<String, String>> _getHeaders() async {
    final token = AuthService().token;
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  // Get Current User Data (Polling to simulate Realtime)
  Stream<UserModel> get currentUserStream {
    return Stream.periodic(const Duration(seconds: 2))
        .asyncMap((_) => _fetchUserProfile());
  }

  Future<UserModel> _fetchUserProfile() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/auth/me'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return UserModel.fromMap(data, currentUid);
      } else {
        throw Exception('Failed to load profile');
      }
    } catch (e) {
      print('Profile Fetch Error: $e');
      // Return a dummy/cached user or rethrow? 
      // Rethrowing will cause StreamBuilder error.
      // Return default.
      return UserModel(uid: currentUid, phoneNumber: '');
    }
  }

  // Update Profile Info (Name, About)
  Future<void> updateProfile({String? name, String? about}) async {
    await http.put(
      Uri.parse('${ApiConfig.baseUrl}/auth/me'),
      headers: await _getHeaders(),
      body: jsonEncode({
        if (name != null) 'name': name,
        if (about != null) 'about': about,
      }),
    );
  }

  // Update Profile Photo
  Future<String> updateProfilePhoto(dynamic imageFile) async {
    try {
      final uploadService = MediaUploadService();
      final mediaData = await uploadService.uploadAvatar(imageFile);
      final url = mediaData['url'];
      
      // Backend automatically updates the user document in MongoDB.
      // The stream will pick up the change on next poll.
      
      return url;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  // Update Privacy Settings (Stub - requires backend endpoint)
  Future<void> updatePrivacySettings({
    int? lastSeenVisibility,
    int? profilePhotoVisibility,
    int? aboutVisibility,
    bool? readReceipts,
  }) async {
    // TODO: Implement backend endpoint
  }

  // Set Online Status
  Future<void> setOnlineStatus(bool isOnline) async {
     try {
       await http.put(
        Uri.parse('${ApiConfig.baseUrl}/auth/me'),
        headers: await _getHeaders(),
        body: jsonEncode({'isOnline': isOnline}),
      );
     } catch (e) {
       print('Online status error: $e');
     }
  }
}
