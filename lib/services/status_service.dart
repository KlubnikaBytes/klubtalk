import 'package:whatsapp_clone/services/media_upload_service.dart';
import 'package:whatsapp_clone/utils/permission_helper.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:whatsapp_clone/services/auth_service.dart';
import 'package:whatsapp_clone/config/api_config.dart';
import 'package:whatsapp_clone/models/status_model.dart';
import 'package:whatsapp_clone/services/socket_service.dart';
import 'package:whatsapp_clone/services/local_cache_service.dart';

import 'package:whatsapp_clone/services/contact_service.dart';

class StatusService {
  static final StatusService _instance = StatusService._internal();
  factory StatusService() => _instance;
  StatusService._internal();

  // Local Cache Service Instance
  final _cache = LocalCacheService();
  final _contactService = ContactService();

  Future<String?> _getToken() async => AuthService().token;

  bool _areListenersInit = false;

  // Init Socket Listeners
  void initSocketListeners() {
    if (_areListenersInit) return;
    _areListenersInit = true;

    // Listen to Stream instead of using socket directly (safer for late connections)
    SocketService().statusStream.listen((data) {
       print("New Status Received via Stream: $data");
       fetchFeed();
    });
  }

  Future<void> createStatus(String type, String content, {
    String? caption, 
    String? color, 
    String? mimeType,
    String privacy = 'contacts',
    List<String>? allowedUsers,
    List<String>? excludedUsers,
  }) async {
    final token = await _getToken();
    await http.post(
      Uri.parse('${ApiConfig.baseUrl}/status/create'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
      body: jsonEncode({
        'type': type,
        'content': content,
        'mimeType': mimeType,
        'caption': caption,
        'backgroundColor': color,
        'privacy': privacy,
        'allowedUsers': allowedUsers ?? [],
        'excludedUsers': excludedUsers ?? [],
      }),
    );
  }

  // Get Feed (cache-only with 24h expiry)
  Future<List<dynamic>> getFeed() async {
    try {
      final token = await _getToken();
      
      // 1️⃣ Load from cache (auto-expires after 24h)
      final cachedStatus = await _cache.getCachedStatus();
      
      if (cachedStatus.isNotEmpty) {
          // ✅ Cache exists and not expired - use it and SKIP API call
          return cachedStatus;
      }
      
      // 2️⃣ Cache empty or expired - fetch from API
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/status/feed'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final feedData = jsonDecode(response.body);
        
        // 3️⃣ Update cache with fresh data and timestamp
        await _cache.cacheStatus(feedData);
        
        return feedData;
      } else {
        // If API fails, return empty (cache was already expired)
        return [];
      }
    } catch (e) {
      print('Error fetching status feed: $e');
      // Return cached data even if expired (offline support)
      try {
        return await _cache.getCachedStatus();
      } catch (_) {
        return [];
      }
    }
  }

  Future<void> viewStatus(String statusId) async {
    final token = await _getToken();
    await http.post(
      Uri.parse('${ApiConfig.baseUrl}/status/view'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
      body: jsonEncode({'statusId': statusId}),
    );
  }

  Future<void> deleteStatus(String statusId) async {
    final token = await _getToken();
    await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/status/$statusId'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
    fetchFeed();
  }

  Future<void> muteUser(String userId) async {
    final token = await _getToken();
    await http.post(
      Uri.parse('${ApiConfig.baseUrl}/status/mute'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
      body: jsonEncode({'userId': userId}),
    );
    fetchFeed();
  }

  Future<void> unmuteUser(String userId) async {
    final token = await _getToken();
    await http.post(
      Uri.parse('${ApiConfig.baseUrl}/status/unmute'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
      body: jsonEncode({'userId': userId}),
    );
    fetchFeed();
  }

  // --- State Management & Helper Methods ---

  final List<VoidCallback> _listeners = [];
  bool get isLoading => false;
  UserStatus? _myStatus;
  List<UserStatus> _recentUpdates = [];
  List<UserStatus> _viewedUpdates = [];
  List<UserStatus> _mutedUpdates = [];

  UserStatus? get myStatus => _myStatus;
  List<UserStatus> get recentUpdates => _recentUpdates;
  List<UserStatus> get viewedUpdates => _viewedUpdates;
  List<UserStatus> get mutedUpdates => _mutedUpdates;

  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }
  
  void notifyListeners() {
      for (var l in _listeners) l();
  }

  Future<void> fetchFeed() async {
      try {
        final feedData = await getFeed();
        final currentUserId = AuthService().currentUserId;

        List<UserStatus> allStatuses = feedData.map((e) => UserStatus.fromJson(e)).toList();

        // 0. Resolve Names (Backend sends 'userName', we override with Contact Name or You)
        for (var s in allStatuses) {
            if (s.userId == currentUserId) {
                s.userName = "You";
            } else {
                s.userName = await _contactService.resolveContactName(s.userId);
            }
        }

        // 1. Extract My Status
        try {
           _myStatus = allStatuses.firstWhere((s) => s.userId == currentUserId);
           allStatuses.removeWhere((s) => s.userId == currentUserId);
        } catch (_) {
           _myStatus = null;
        }

        // 2. Clear lists
        _recentUpdates = [];
        _viewedUpdates = [];
        _mutedUpdates = [];

        for (var statusGroup in allStatuses) {
           // Check Muted FIRST
           if (statusGroup.isMuted) {
             _mutedUpdates.add(statusGroup);
             continue;
           }

           // Check if ANY status in this group is NOT viewed by me
           bool hasUnseen = statusGroup.statuses.any((s) {
              return !s.viewers.contains(currentUserId);
           });

           if (hasUnseen) {
             _recentUpdates.add(statusGroup);
           } else {
             _viewedUpdates.add(statusGroup);
           }
        }
        
        notifyListeners();
      } catch (e) {
        print("Status Fetch Error: $e");
      }
  }

  Future<void> createTextStatus({
    required String text, 
    required String backgroundColor,
    String privacy = 'contacts',
    List<String>? allowedUsers,
    List<String>? excludedUsers,
  }) async {
      await createStatus('text', text, color: backgroundColor, privacy: privacy, allowedUsers: allowedUsers, excludedUsers: excludedUsers);
      fetchFeed(); 
  }

  Future<void> createMediaStatus({
    required File file, 
    String caption = '', 
    bool isVideo = false,
    String privacy = 'contacts',
    List<String>? allowedUsers,
    List<String>? excludedUsers,
  }) async {
       try {
         // Fix: Check Permission BEFORE Upload
         bool hasPermission = await PermissionHelper.requestMediaPermissions(video: isVideo);
         if (!hasPermission) {
           throw Exception("Media permission denied");
         }

         final uploadService = MediaUploadService();
         final type = isVideo ? 'video' : 'image';
         final mime = isVideo ? 'video/mp4' : 'image/jpeg';
         
         final result = await uploadService.uploadGenericFile(file, mimeType: mime);
         final url = result['url'];
         
         if (url == null) throw Exception("Upload failed: No URL returned");

         await createStatus(
           type, url, 
           caption: caption, 
           mimeType: mime,
           privacy: privacy,
           allowedUsers: allowedUsers,
           excludedUsers: excludedUsers
        );
         
         fetchFeed(); 
       } catch (e) {
         print("Create Media Status Error: $e");
         rethrow;
       }
  }
}
