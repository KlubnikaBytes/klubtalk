import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:whatsapp_clone/config/api_config.dart';
import '../models/community_model.dart';
import '../models/group_model.dart';

class CommunityService {
  final FlutterSecureStorage storage = const FlutterSecureStorage();
  String get baseUrl => ApiConfig.baseUrl;

  Future<String?> _getToken() async {
    return await storage.read(key: 'jwt_token');
  }

  // Create Community
  Future<CommunityModel?> createCommunity(String name, String description, String photo, List<String> initialGroupIds) async {
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/communities/create'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': name,
          'description': description,
          'photo': photo, // URL string or base64? Usually URL from upload
          'initialGroupIds': initialGroupIds,
        }),
      );

      if (response.statusCode == 200) {
        return CommunityModel.fromJson(jsonDecode(response.body));
      } else {
        print('Create Community Error: ${response.body}');
        return null; // Or throw error
      }
    } catch (e) {
      print('Create Community Exception: $e');
      return null;
    }
  }

  // Get My Communities
  Future<List<CommunityModel>> getMyCommunities() async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/communities'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => CommunityModel.fromJson(e)).toList();
      }
    } catch (e) {
      print('Get My Communities Error: $e');
    }
    return [];
  }

  // Get Community Details
  Future<CommunityModel?> getCommunityDetails(String id) async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/communities/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return CommunityModel.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      print('Get Community Details Error: $e');
    }
    return null;
  }

  // Add Groups
  Future<bool> addGroupsToCommunity(String communityId, List<String> groupIds) async {
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/communities/$communityId/groups'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'groupIds': groupIds}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
