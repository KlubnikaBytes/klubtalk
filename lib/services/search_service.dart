import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:whatsapp_clone/config/api_config.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SearchService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<Map<String, String>> _getHeaders() async {
    final token = await _auth.currentUser?.getIdToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  // Global Search: Users, Chats, Messages
  Future<Map<String, dynamic>> searchGlobal(String query) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/search/global?q=$query'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      } else {
        throw Exception('Global search failed: ${response.statusCode}');
      }
    } catch (e) {
      print('Search Service Error: $e');
      rethrow;
    }
  }

  // Chat Search: Messages within a specific chat
  Future<List<Map<String, dynamic>>> searchChat(String chatId, String query) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/search/chat/$chatId?q=$query'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['messages']);
      } else {
        throw Exception('Chat search failed: ${response.statusCode}');
      }
    } catch (e) {
      print('Search Service Error: $e');
      rethrow;
    }
  }
}
