import 'package:whatsapp_clone/services/media_upload_service.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:whatsapp_clone/services/auth_service.dart';
import 'package:whatsapp_clone/config/api_config.dart';
import 'package:whatsapp_clone/models/status_model.dart';

class StatusService {

  Future<String?> _getToken() async => AuthService().token;

  Future<void> createStatus(String type, String content, {String? caption, String? color}) async {
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
        'caption': caption,
        'backgroundColor': color
      }),
    );
  }

  Future<List<dynamic>> getFeed() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/status/feed'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
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

  // --- State Management & Helper Methods ---

  final List<VoidCallback> _listeners = [];
  bool get isLoading => false;
  UserStatus? _myStatus;
  List<UserStatus> _recentUpdates = [];
  List<UserStatus> _viewedUpdates = [];

  UserStatus? get myStatus => _myStatus;
  List<UserStatus> get recentUpdates => _recentUpdates;
  List<UserStatus> get viewedUpdates => _viewedUpdates;

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

        // 1. Extract My Status
        try {
           _myStatus = allStatuses.firstWhere((s) => s.userId == currentUserId);
           allStatuses.removeWhere((s) => s.userId == currentUserId);
        } catch (_) {
           _myStatus = null;
        }

        // 2. Separate Recent vs Viewed
        _recentUpdates = [];
        _viewedUpdates = [];

        for (var statusGroup in allStatuses) {
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

  Future<void> createTextStatus({required String text, required String backgroundColor}) async {
      await createStatus('text', text, color: backgroundColor);
      fetchFeed(); // Refresh after create
  }

  Future<void> createMediaStatus({required File file, String caption = '', bool isVideo = false}) async {
       final uploadService = MediaUploadService();
       final type = isVideo ? 'video' : 'image';
       // Ensure mimeType is valid for backend
       final mime = isVideo ? 'video/mp4' : 'image/jpeg';
       final result = await uploadService.uploadGenericFile(file, mimeType: mime);
       final url = result['url'] ?? ''; 
       await createStatus(type, url, caption: caption);
       fetchFeed(); // Refresh
  }
}
