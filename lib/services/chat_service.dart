import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:whatsapp_clone/config/api_config.dart';
import 'package:whatsapp_clone/services/media_upload_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Helper to get headers with Auth Token
  Future<Map<String, String>> _getHeaders() async {
    final token = await _auth.currentUser?.getIdToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  // Create or Get existing Chat ID
  Future<String> createOrGetChat(String otherUserId) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.chatsEndpoint}/private'),
        headers: await _getHeaders(),
        body: jsonEncode({'participantId': otherUserId}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        print("✅ createOrGetChat Success: ${data['chatId']}");
        return data['chatId'];
      } else {
        print("❌ createOrGetChat Failed: ${response.statusCode} - ${response.body}");
        throw Exception('Failed to create chat: ${response.body}');
      }
    } catch (e) {
      print('❌ Chat Creation Error: $e');
      rethrow;
    }
  }

  // Send Text Message
  Future<void> sendMessage(String chatId, String text) async {
    await _sendMessageToBackend(chatId, text, 'text');
  }

  // Send Voice Message
  Future<void> sendVoiceMessage(String chatId, dynamic fileOrPath, int durationSeconds) async {
    try {
      final uploadService = MediaUploadService();
      final mediaData = await uploadService.uploadVoice(fileOrPath);
      await _sendMessageToBackend(chatId, mediaData['url'], 'voice', 
        duration: durationSeconds,
        previewUrl: mediaData['previewUrl'],
        originalUrl: mediaData['originalUrl'],
        mime: mediaData['mime']
      );
    } catch (e) {
      print('Voice Send Error: $e');
      rethrow;
    }
  }

  // Send Image Message
  Future<void> sendImageMessage(String chatId, dynamic fileOrPath, {String? mimeType}) async {
    try {
      final uploadService = MediaUploadService();
      final mediaData = await uploadService.uploadImage(fileOrPath, mimeType: mimeType);
      await _sendMessageToBackend(chatId, mediaData['url'], 'image',
        previewUrl: mediaData['previewUrl'],
        originalUrl: mediaData['originalUrl'],
        mime: mediaData['mime'] // Use backend returned mime, or fall back to what we sent? Backend usually detects. But on Web we need extension for backend to detect.
      );
    } catch (e) {
      print('Image Send Error: $e');
      rethrow;
    }
  }

  // Send Video Message
  Future<void> sendVideoMessage(String chatId, dynamic fileOrPath, {String? mimeType}) async {
    try {
      final uploadService = MediaUploadService();
      // Reuse uploadImage/Generic for now as backend handles generic media uploads
      final mediaData = await uploadService.uploadGenericFile(fileOrPath, mimeType: mimeType);
      await _sendMessageToBackend(chatId, mediaData['url'], 'video',
        previewUrl: mediaData['previewUrl'],
        originalUrl: mediaData['originalUrl'],
        mime: mediaData['mime']
      );
    } catch (e) {
      print('Video Send Error: $e');
      rethrow;
    }
  }

  // Send File Message
  Future<void> sendFileMessage(String chatId, dynamic fileOrPath) async {
    try {
      final uploadService = MediaUploadService();
      final mediaData = await uploadService.uploadGenericFile(fileOrPath);
      // Backend derived type might be 'image'/'video'/'file'/'audio'.
      // But for "File Picker" flow, usage dictates it's a file attachment usually.
      // If backend says 'image', should we override to 'file'?
      // Prompt says: "If message.type == 'file' -> show document card".
      // If I pick an image via pin, it should show as document card.
      // So I must force type 'file' regardless of what backend thinks (backend 'type' return is informational mostly or DB storage).
      // If I send 'type': 'file' to _sendMessageToBackend, it will store 'file' in DB 'type' field (controller uses req.body.type).
      
      await _sendMessageToBackend(chatId, mediaData['url'], 'file',
        previewUrl: mediaData['previewUrl'],
        originalUrl: mediaData['originalUrl'],
        mime: mediaData['mime'],
        filename: mediaData['filename'],
        size: mediaData['size']
      );
    } catch (e) {
      print('File Send Error: $e');
      rethrow;
    }
  }

  // Helper: Post Message to Backend
  Future<void> _sendMessageToBackend(
    String chatId, 
    String content, 
    String type, {
    int? duration, 
    String? previewUrl, 
    String? originalUrl, 
    String? mime,
    String? filename,
    int? size
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.messagesEndpoint),
        headers: await _getHeaders(),
        body: jsonEncode({
          'chatId': chatId,
          'content': content,
          'type': type,
          if (duration != null) 'duration': duration,
          if (previewUrl != null) 'previewUrl': previewUrl,
          if (originalUrl != null) 'originalUrl': originalUrl,
          if (mime != null) 'mime': mime,
          if (filename != null) 'filename': filename,
          if (size != null) 'size': size,
        }),
      );

      if (response.statusCode != 201) {
        throw Exception('Failed to send message: ${response.body}');
      }
    } catch (e) {
      print('Send Message API Error: $e');
      rethrow;
    }
  }

  // Get My Chats
  Future<List<Map<String, dynamic>>> getMyChats() async {
    final response = await http.get(
      Uri.parse(ApiConfig.chatsEndpoint),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load chats');
    }
  }

  // Get Messages for a Chat
  Future<List<Map<String, dynamic>>> getMessages(String chatId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.messagesEndpoint}/$chatId'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load messages');
    }
  }

  // Create Group Chat
  Future<String> createGroupChat(String groupName, List<String> participantUids, {String? groupPhotoUrl}) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.chatsEndpoint}/group'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'groupName': groupName,
        'participants': participantUids,
        'groupPhoto': groupPhotoUrl,
      }),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return data['chatId'];
    } else {
      throw Exception('Failed to create group: ${response.body}');
    }
  }

  // Create Community
  Future<Map<String, dynamic>> createCommunity(String name, String description, List<String> groupIds, {String? iconUrl}) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.chatsEndpoint}/community'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'name': name,
        'description': description,
        'groupIds': groupIds,
        'icon': iconUrl
      }),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create community: ${response.body}');
    }
  }

  // --- Missing Methods needed for UI ---

  Future<void> markChatAsRead(String chatId) async {
    // TODO: Implement backend endpoint for this
    print('markChatAsRead not implemented yet for Hybrid Backend');
  }

  Future<void> markChatAsUnread(String chatId) async {
     // TODO: Implement backend endpoint for this
    print('markChatAsUnread not implemented yet for Hybrid Backend');
  }

  // Get Community
  Future<Map<String, dynamic>> getCommunity(String communityId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/communities/$communityId'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load community');
    }
  }

  Future<void> toggleFavorite(String chatId) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.chatsEndpoint}/favorite'),
      headers: await _getHeaders(),
      body: jsonEncode({'chatId': chatId}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to toggle favorite');
    }
  }

  Future<void> toggleArchive(String chatId) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.chatsEndpoint}/archive'),
      headers: await _getHeaders(),
      body: jsonEncode({'chatId': chatId}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to toggle archive');
    }
  }

  // --- NEW FEATURES ---

  Future<void> muteChat(String chatId, String? muteUntil) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.chatsEndpoint}/mute'),
      headers: await _getHeaders(),
      body: jsonEncode({'chatId': chatId, 'muteUntil': muteUntil}),
    );
    if (response.statusCode != 200) throw Exception('Failed to mute chat');
  }

  Future<void> setDisappearingTimer(String chatId, int duration) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.chatsEndpoint}/disappearing'),
      headers: await _getHeaders(),
      body: jsonEncode({'chatId': chatId, 'duration': duration}),
    );
    if (response.statusCode != 200) throw Exception('Failed to set timer');
  }

  Future<void> setChatTheme(String chatId, String wallpaper) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.chatsEndpoint}/wallpaper'),
      headers: await _getHeaders(),
      body: jsonEncode({'chatId': chatId, 'wallpaper': wallpaper}),
    );
    if (response.statusCode != 200) throw Exception('Failed to set theme');
  }

  Future<void> reportChat(String chatId, {String? reportedUserId, String? reason, bool blockUser = false, bool deleteChat = false, List<Map<String, dynamic>>? lastMessages}) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.chatsEndpoint}/report'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'chatId': chatId,
        'reportedUserId': reportedUserId,
        'reason': reason,
        'blockUser': blockUser,
        'deleteChat': deleteChat,
        'lastMessages': lastMessages
      }),
    );
    if (response.statusCode != 200) throw Exception('Failed to report chat');
  }

  Future<void> blockUser(String userId) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/block-user'),
      headers: await _getHeaders(),
      body: jsonEncode({'blocked_id': userId}),
    );
    if (response.statusCode != 200) throw Exception('Failed to block user');
  }

  Future<void> unblockUser(String userId) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/block-user'),
      headers: await _getHeaders(),
      body: jsonEncode({'blocked_id': userId}),
    );
    if (response.statusCode != 200) throw Exception('Failed to unblock user');
  }

  Future<List<String>> getBlockedUsers() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return [];

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/blocked-users/${currentUser.uid}'),
      headers: await _getHeaders(),
    );
    
    if (response.statusCode == 200) {
      final list = jsonDecode(response.body);
      if (list != null && list is List) {
         return List<String>.from(list);
      }
      return [];
    }
    return [];
  }
}
