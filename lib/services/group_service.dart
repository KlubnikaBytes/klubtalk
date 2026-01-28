import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:whatsapp_clone/config/api_config.dart';
import 'package:whatsapp_clone/services/auth_service.dart';
import 'package:whatsapp_clone/models/group_model.dart';

class GroupService {
  final AuthService _authService = AuthService();

  Future<String> createGroup({
    required String name,
    required List<String> participants,
    String? description,
    String? avatar,
  }) async {
    final token = _authService.token;
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/chats/group'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'name': name,
        'description': description ?? '',
        'participants': participants,
        'avatar': avatar ?? '',
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['_id'] ?? data['id'];
    } else {
      throw Exception('Failed to create group: ${response.body}');
    }
  }

  Future<void> updateGroupInfo({
    required String chatId,
    String? name,
    String? description,
    String? avatar,
  }) async {
    final token = _authService.token;
    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/chats/$chatId/info'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (avatar != null) 'avatar': avatar,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update group info: ${response.body}');
    }
  }

  Future<void> updatePermissions({
    required String chatId,
    String? editInfoPermission,
    String? sendMessagePermission,
    String? addParticipantsPermission,
  }) async {
    final token = _authService.token;
    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/chats/$chatId/permissions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        if (editInfoPermission != null) 'editInfoPermission': editInfoPermission,
        if (sendMessagePermission != null) 'sendMessagePermission': sendMessagePermission,
        if (addParticipantsPermission != null) 'addParticipantsPermission': addParticipantsPermission,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update permissions: ${response.body}');
    }
  }

  Future<void> addParticipant({
    required String chatId,
    required String userId,
  }) async {
    final token = _authService.token;
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/chats/$chatId/participants'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'userId': userId}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to add participant: ${response.body}');
    }
  }

  Future<void> removeParticipant({
    required String chatId,
    required String userId,
  }) async {
    final token = _authService.token;
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/chats/$chatId/participants/$userId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to remove participant: ${response.body}');
    }
  }

  Future<void> promoteToAdmin({
    required String chatId,
    required String userId,
  }) async {
    final token = _authService.token;
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/chats/$chatId/admins'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'userId': userId}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to promote to admin: ${response.body}');
    }
  }

  Future<void> demoteAdmin({
    required String chatId,
    required String userId,
  }) async {
    final token = _authService.token;
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/chats/$chatId/admins/$userId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to demote admin: ${response.body}');
    }
  }

  Future<void> leaveGroup({required String chatId}) async {
    final token = _authService.token;
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/chats/$chatId/leave'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to leave group: ${response.body}');
    }
  }

  Future<GroupModel> getGroupDetails(String chatId) async {
    final token = _authService.token;
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/chats'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> chats = jsonDecode(response.body);
      final groupData = chats.firstWhere(
        (chat) => (chat['_id'] ?? chat['id']) == chatId && chat['isGroup'] == true,
        orElse: () => throw Exception('Group not found'),
      );
      return GroupModel.fromJson(groupData);
    } else {
      throw Exception('Failed to get group details: ${response.body}');
    }
  }
}
