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

  // Upload Voice Message
  Future<String> uploadVoice(dynamic fileOrPath) async {
    return _uploadFile(fileOrPath, ApiConfig.uploadVoiceEndpoint, fieldName: 'voice');
  }

  // Upload Chat Image
  Future<String> uploadImage(dynamic fileOrPath) async {
    return _uploadFile(fileOrPath, ApiConfig.uploadImageEndpoint, fieldName: 'image');
  }

  // Upload Profile Avatar
  Future<String> uploadAvatar(dynamic fileOrPath) async {
    return _uploadFile(fileOrPath, ApiConfig.uploadAvatarEndpoint, fieldName: 'avatar');
  }

  // Core Upload Logic
  Future<String> _uploadFile(dynamic fileOrPath, String endpoint, {String fieldName = 'file'}) async {
    final uri = Uri.parse(endpoint);
    final request = http.MultipartRequest('POST', uri);
    
    // Add Headers (Auth)
    request.headers.addAll(await _getHeaders());

    // Add File
    if (kIsWeb) {
      String extension = 'jpg';
      if (fieldName == 'voice') {
        extension = 'mp3'; // Default for web audio blobs
      }

      if (fileOrPath is String && (fileOrPath.startsWith('blob:') || fileOrPath.startsWith('http'))) {
        // Fetch Blob data from Blob URL
        final response = await http.get(Uri.parse(fileOrPath));
        if (response.statusCode != 200) throw Exception('Failed to read blob data');
        
        request.files.add(
          http.MultipartFile.fromBytes(
            fieldName, 
            response.bodyBytes,
            filename: 'upload_${DateTime.now().millisecondsSinceEpoch}.$extension', 
          )
        );
      } else if (fileOrPath is Uint8List) {
        request.files.add(
          http.MultipartFile.fromBytes(
            fieldName, 
            fileOrPath,
            filename: 'upload_${DateTime.now().millisecondsSinceEpoch}.$extension',
          )
        );
      } else {
         // Fallback or error
         throw Exception('Unsupported web file format');
      }
    } else {
      // Mobile: Expecting String path or File object
      String path = fileOrPath is File ? fileOrPath.path : fileOrPath.toString();
      request.files.add(await http.MultipartFile.fromPath(fieldName, path));
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
      rethrow;
    }
  }
}

