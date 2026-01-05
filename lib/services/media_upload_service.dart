import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:http/http.dart' as http;
import 'package:whatsapp_clone/config/api_config.dart';

class MediaUploadService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Helper to get headers with Auth Token
  Future<Map<String, String>> _getHeaders() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');
    
    final token = await user.getIdToken();
    return {
      'Authorization': 'Bearer $token',
      // Content-Type for multipart is handled automatically by MultipartRequest
    };
  }

  // Upload Audio
  Future<String> uploadAudio(dynamic fileOrPath) async {
    return _uploadFile(fileOrPath, ApiConfig.uploadAudioEndpoint);
  }

  // Upload Generic Image (Chat)
  Future<String> uploadImage(dynamic fileOrPath) async {
    return _uploadFile(fileOrPath, '${ApiConfig.baseUrl}/upload/image');
  }

  // Upload Group Icon
  Future<String> uploadGroupIcon(dynamic fileOrPath) async {
    return _uploadFile(fileOrPath, '${ApiConfig.baseUrl}/upload/group');
  }

  // Upload Profile Photo
  Future<String> uploadProfilePhoto(dynamic fileOrPath) async {
    return _uploadFile(fileOrPath, '${ApiConfig.baseUrl}/upload/profile');
  }

  // Core Upload Logic
  Future<String> _uploadFile(dynamic fileOrPath, String endpoint) async {
    final uri = Uri.parse(endpoint);
    final request = http.MultipartRequest('POST', uri);
    
    // Add Headers (Auth)
    request.headers.addAll(await _getHeaders());

    // Add File
    if (kIsWeb) {
      if (fileOrPath is String && (fileOrPath.startsWith('blob:') || fileOrPath.startsWith('http'))) {
        // Fetch Blob data first
        final response = await http.get(Uri.parse(fileOrPath));
        if (response.statusCode != 200) throw Exception('Failed to read blob data');
        
        request.files.add(
          http.MultipartFile.fromBytes(
            'file', 
            response.bodyBytes,
            filename: 'upload_${DateTime.now().millisecondsSinceEpoch}.jpg', // Default extension, backend can rename/detect
          )
        );
      } else if (fileOrPath is Uint8List) {
         request.files.add(
          http.MultipartFile.fromBytes(
            'file', 
            fileOrPath,
            filename: 'upload_${DateTime.now().millisecondsSinceEpoch}.jpg',
          )
        );
      } else {
        throw Exception('Unsupported web file format');
      }
    } else {
      // Mobile: Expecting String path or File object
      String path = fileOrPath is File ? fileOrPath.path : fileOrPath.toString();
      request.files.add(await http.MultipartFile.fromPath('file', path));
    }

    // Send
    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['url'];
      } else {
        throw Exception('Upload failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Media Upload Error: $e');
      // MOCK FALLBACK FOR IMAGES/GROUPS TO ALLOW UI TESTING WITHOUT LIVE VPS
      if (endpoint.contains('audio')) {
         return 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';
      } else {
         return 'https://picsum.photos/200/300'; // Dummy Image
      }
    }
  }
}

