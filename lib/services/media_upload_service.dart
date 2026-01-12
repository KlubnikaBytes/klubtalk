import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:http/http.dart' as http;
import 'package:whatsapp_clone/config/api_config.dart';
import 'package:mime/mime.dart';

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
  Future<Map<String, dynamic>> uploadVoice(dynamic fileOrPath) async {
    return _uploadFile(fileOrPath, ApiConfig.uploadVoiceEndpoint, fieldName: 'voice', mimeType: 'audio/mpeg');
  }

  // Upload Chat Image
  Future<Map<String, dynamic>> uploadImage(dynamic fileOrPath, {String? mimeType}) async {
    return _uploadFile(fileOrPath, ApiConfig.uploadImageEndpoint, fieldName: 'image', mimeType: mimeType);
  }

  // Upload Profile Avatar
  Future<Map<String, dynamic>> uploadAvatar(dynamic fileOrPath) async {
    return _uploadFile(fileOrPath, ApiConfig.uploadAvatarEndpoint, fieldName: 'avatar');
  }

  // Upload Generic File (Document, Zip, etc)
  Future<Map<String, dynamic>> uploadGenericFile(dynamic fileOrPath, {String? mimeType}) async {
    // Reuse uploadImage endpoint as generic media handler
    return _uploadFile(fileOrPath, ApiConfig.uploadImageEndpoint, fieldName: 'image', mimeType: mimeType); 
  }

  // Core Upload Logic
  Future<Map<String, dynamic>> _uploadFile(dynamic fileOrPath, String endpoint, {String fieldName = 'file', String? mimeType}) async {
    final uri = Uri.parse(endpoint);
    final request = http.MultipartRequest('POST', uri);
    
    // Add Headers (Auth)
    request.headers.addAll(await _getHeaders());

    // Add File
    if (kIsWeb) {
      String extension = 'jpg';
      if (fieldName == 'voice') {
        extension = 'mp3'; // Default for web audio blobs
      } else if (mimeType != null) {
          extension = extensionFromMime(mimeType) ?? 'bin';
          // Fix for audio/mpeg -> mp3 if needed, or video/mp4 -> mp4
          if (extension == 'bin' && mimeType == 'video/mp4') extension = 'mp4';
          if (extension == 'bin' && mimeType == 'image/jpeg') extension = 'jpg';
      }

      print("DEBUG: Web Upload Extension for $mimeType -> .$extension");

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
        final Map<String, dynamic> data = jsonDecode(response.body);
        // Ensure mime is part of the returned data so ChatService can use it
        if (kIsWeb && mimeType != null) {
           data['mime'] = mimeType;
        }
        return data; 
      } else {
        throw Exception('Upload failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Media Upload Error: $e');
      rethrow;
    }
  }
}

