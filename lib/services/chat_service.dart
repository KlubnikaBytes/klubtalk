import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:whatsapp_clone/config/api_config.dart';
import 'package:whatsapp_clone/services/media_upload_service.dart';
import 'package:whatsapp_clone/services/auth_service.dart';
import 'package:whatsapp_clone/services/socket_service.dart';
import 'package:whatsapp_clone/services/local_cache_service.dart';

class ChatService {

  // Local Cache Service Instance
  final _cache = LocalCacheService();

  // Helper to get headers with Auth Token
  Future<Map<String, String>> _getHeaders() async {
    final token = AuthService().token;
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
        body: jsonEncode({'peerId': otherUserId}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final chatId = data['chatId'] ?? data['_id'];
        print("✅ createOrGetChat Success: $chatId");
        if (chatId == null) throw Exception('Server returned null chatId');
        return chatId;
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
  Future<Map<String, dynamic>?> sendMessage(String chatId, String text, {String type = 'text', String? tempId, String? replyToId}) async {
    // Determine if we should use Socket or REST
    // For reliable Unread Count updates (handled by Backend), we MUST use the REST API.
    // The Backend will handle Socket emission to recipients.
    // Optimistic updates should be handled by the UI layer (ChatScreen) separately.
    
    return await _sendMessageToBackend(chatId, text, type, tempId: tempId, replyToId: replyToId);
  }

  // Send Sticker Message
  // Send Sticker Message
  Future<Map<String, dynamic>> sendStickerMessage(String chatId, String stickerUrl, {String? tempId, String? replyToId}) async {
      return await _sendMessageToBackend(chatId, stickerUrl, 'sticker', tempId: tempId, replyToId: replyToId);
  }

  // Send Voice Message
  Future<void> sendVoiceMessage(String chatId, dynamic fileOrPath, int durationSeconds, {String? tempId, String? replyToId}) async {
    try {
      final uploadService = MediaUploadService();
      final mediaData = await uploadService.uploadVoice(fileOrPath);
      await _sendMessageToBackend(chatId, mediaData['url'], 'audio', 
        duration: durationSeconds,
        previewUrl: mediaData['previewUrl'],
        originalUrl: mediaData['originalUrl'],
        mime: mediaData['mime'],
        tempId: tempId,
        replyToId: replyToId
      );
    } catch (e) {
      print('Voice Send Error: $e');
      rethrow;
    }
  }

  // Send Image Message
  Future<void> sendImageMessage(String chatId, dynamic fileOrPath, {String? mimeType, String? caption, String? tempId, String? replyToId}) async {
    try {
      final uploadService = MediaUploadService();
      final mediaData = await uploadService.uploadImage(fileOrPath, mimeType: mimeType);
      await _sendMessageToBackend(chatId, mediaData['url'], 'image',
        previewUrl: mediaData['previewUrl'],
        originalUrl: mediaData['originalUrl'],
        mime: mediaData['mime'],
        caption: caption,
        tempId: tempId,
        replyToId: replyToId
      );
    } catch (e) {
      print('Image Send Error: $e');
      rethrow;
    }
  }

  // Send Video Message
  Future<void> sendVideoMessage(String chatId, dynamic fileOrPath, {String? mimeType, String? caption, String? tempId, String? replyToId}) async {
    try {
      final uploadService = MediaUploadService();
      // Reuse uploadImage/Generic for now as backend handles generic media uploads
      final mediaData = await uploadService.uploadGenericFile(fileOrPath, mimeType: mimeType);
      await _sendMessageToBackend(chatId, mediaData['url'], 'video',
        previewUrl: mediaData['previewUrl'],
        originalUrl: mediaData['originalUrl'],
        mime: mediaData['mime'],
        caption: caption,
        tempId: tempId,
        replyToId: replyToId
      );
    } catch (e) {
      print('Video Send Error: $e');
      rethrow;
    }
  }

  // Send File Message
  Future<void> sendFileMessage(String chatId, dynamic fileOrPath, {String? tempId, String? replyToId}) async {
    try {
      final uploadService = MediaUploadService();
      final mediaData = await uploadService.uploadGenericFile(fileOrPath);
      
      print('📤 sendFileMessage DEBUG:');
      print('   Upload returned type: ${mediaData['type']}');
      print('   Upload returned mime: ${mediaData['mime']}');
      print('   Sending type to backend: file');
      
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
        size: mediaData['size'],
        tempId: tempId,
        replyToId: replyToId
      );
    } catch (e) {
      print('File Send Error: $e');
      rethrow;
    }
  }

  // Helper: Post Message to Backend
  Future<Map<String, dynamic>> _sendMessageToBackend(
    String chatId, 
    String content, 
    String type, {
    int? duration, 
    String? previewUrl, 
    String? originalUrl, 
    String? mime,
    String? filename,
    int? size,
    String? caption,
    String? tempId,
    String? replyToId
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
          if (caption != null && caption.isNotEmpty) 'caption': caption,
          if (tempId != null) 'tempId': tempId,
          if (replyToId != null) 'replyTo': replyToId,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
         final data = Map<String, dynamic>.from(jsonDecode(response.body));
         // Fix: Map createdAt to timestamp
         if (data['timestamp'] == null && data['createdAt'] != null) {
            data['timestamp'] = data['createdAt'];
         }
         return data;
      } else {
        throw Exception('Failed to send message: ${response.body}');
      }
    } catch (e) {
      print('Send Message API Error: $e');
      rethrow;
    }
  }

  // Get My Chats (with cache-first pattern)
  Future<List<Map<String, dynamic>>> getMyChats() async {
      // For backward compatibility or simple usage, we can just return cache if available,
      // and trigger background fetch. But standard Future usage implies waiting.
      // So we will stick to the plan: This method returns *something* valid.
      // Ideally, UI calls getCachedChatsOnly() then fetchRemoteChats().
      
      // If we just want a simple "get data" that is fast:
      final cached = await getCachedChatsOnly();
      if (cached.isNotEmpty) return cached;
      
      return await fetchRemoteChats();
  }

  // ⚡ New: Get Cached Chats Only (Instant)
  Future<List<Map<String, dynamic>>> getCachedChatsOnly() async {
      try {
         final cachedChats = await _cache.getCachedChats();
         return List<Map<String, dynamic>>.from(cachedChats);
      } catch (e) {
         print("Cache Load Error: $e");
         return [];
      }
  }

  // ⚡ New: Fetch Remote Chats Only (updates cache)
  Future<List<Map<String, dynamic>>> fetchRemoteChats() async {
    try {
      final url = Uri.parse(ApiConfig.chatsEndpoint);
      // print("Fetching chats from: $url");
      final response = await http.get(
        url,
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final chats = List<Map<String, dynamic>>.from(jsonDecode(response.body));
        
        // 3️⃣ Update cache with fresh data
        await _cache.cacheChats(chats);
        
        return chats;
      } else {
        throw Exception('Failed to load chats: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching chats: $e');
      rethrow;
    }
  }

  // Get Messages (with cache-first pattern)
  Future<List<Map<String, dynamic>>> getMessages(String chatId) async {
      // Backward compatibility: try cache first
      final cached = await getCachedMessagesOnly(chatId);
      if (cached.isNotEmpty) return cached;
      return await fetchRemoteMessages(chatId);
  }

  // ⚡ New: Get Cached Messages Only (Instant)
  Future<List<Map<String, dynamic>>> getCachedMessagesOnly(String chatId) async {
      try {
         final cached = await _cache.getCachedMessages(chatId);
         return List<Map<String, dynamic>>.from(cached);
      } catch (e) {
         print("Cache Load Error: $e");
         return [];
      }
  }

  // ⚡ New: Fetch Remote Messages Only (updates cache)
  Future<List<Map<String, dynamic>>> fetchRemoteMessages(String chatId) async {
      try {
        final response = await http.get(
          Uri.parse('${ApiConfig.messagesEndpoint}/$chatId'),
          headers: await _getHeaders(),
        );

        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          final messages = data.map((m) {
             final map = Map<String, dynamic>.from(m);
             if (map['timestamp'] == null && map['createdAt'] != null) {
                map['timestamp'] = map['createdAt'];
             }
             return map;
          }).toList();
          
          await _cache.cacheMessages(chatId, messages);
          return messages;
        } else {
           throw Exception('Failed to load messages: ${response.statusCode}');
        }
      } catch (e) {
         print("Remote Fetch Error: $e");
         rethrow;
      }
  }

  // Create Group Chat
  Future<String> createGroupChat(String groupName, List<String> participantUids, {String? groupPhotoUrl, String? description}) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.chatsEndpoint}/group'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'name': groupName,
        'participants': participantUids,
        'avatar': groupPhotoUrl,
        'description': description ?? '',
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return data['chatId'] ?? data['_id'] ?? data['id'];
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

  Future<void> reactToMessage(String messageId, String reaction) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.messagesEndpoint}/$messageId/react'),
      headers: await _getHeaders(),
      body: jsonEncode({'reaction': reaction}),
    );
     if (response.statusCode != 200) throw Exception('Failed to add reaction');
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
    print('🚫 Blocking user: $userId');
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/block-user'),
        headers: await _getHeaders(),
        body: jsonEncode({'userId': userId}),
      );
      print('🚫 Block response: ${response.statusCode} - ${response.body}');
      if (response.statusCode != 200) {
        throw Exception('Failed to block user: ${response.body}');
      }
      print('✅ Successfully blocked user: $userId');
    } catch (e) {
      print('❌ Block error: $e');
      rethrow;
    }
  }

  Future<void> unblockUser(String userId) async {
    print('✅ Unblocking user: $userId');
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/block-user'),
        headers: await _getHeaders(),
        body: jsonEncode({'userId': userId}),
      );
      print('✅ Unblock response: ${response.statusCode} - ${response.body}');
      if (response.statusCode != 200) {
        throw Exception('Failed to unblock user: ${response.body}');
      }
      print('✅ Successfully unblocked user: $userId');
    } catch (e) {
      print('❌ Unblock error: $e');
      rethrow;
    }
  }

  Future<List<String>> getBlockedUsers() async {
    final currentUserId = AuthService().currentUserId;
    if (currentUserId == null) return [];

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/blocked-users/$currentUserId'),
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
