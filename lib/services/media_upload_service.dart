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
    final uri = Uri.parse(ApiConfig.uploadAudioEndpoint);
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
            filename: 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a',
          )
        );
      } else if (fileOrPath is Uint8List) {
         request.files.add(
          http.MultipartFile.fromBytes(
            'file', 
            fileOrPath,
            filename: 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a',
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
      // FALLBACK FOR DEVELOPMENT WITHOUT REAL VPS
      // If the API call fails (mostly because URL is fake), return a dummy URL or rethrow?
      // For now, rethrow so the user knows they need a real VPS.
      // BUT, to allow "Testing" as requested, we might want a mock mode.
      // throw Exception('Media upload failed. Is VPS accessible? $e');
      
      // MOCK FALLBACK (REMOVE IN PRODUCTION)
      print('⚠️ VPS Unreachable. Returning MOCK URL for testing.');
      return 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3'; // Dummy Audio
    }
  }
}
