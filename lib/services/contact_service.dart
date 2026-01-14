import 'dart:convert';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:whatsapp_clone/models/user_model.dart';
import 'package:whatsapp_clone/models/contact.dart' as app_contact;
import 'package:whatsapp_clone/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'package:whatsapp_clone/config/api_config.dart';

class ContactService {

  // Check Current Permission Status
  Future<PermissionStatus> getPermissionStatus() async {
    return await Permission.contacts.status;
  }

  // Request Permission
  Future<PermissionStatus> requestPermission() async {
    return await Permission.contacts.request();
  }

  // Fetch Device Contacts
  Future<List<Contact>> getDeviceContacts() async {
    if (await FlutterContacts.requestPermission(readonly: true)) {
      return await FlutterContacts.getContacts(withProperties: true, withPhoto: true);
    }
    return [];
  }

  // Fetch ALL Registered Users via API
  Future<List<UserModel>> getRegisteredUsers() async {
     try {
       final token = AuthService().token;
       if (token == null) return [];

       final response = await http.get(
         Uri.parse('${ApiConfig.baseUrl}/users'),
         headers: {
           'Authorization': 'Bearer $token',
         }
       );

       if (response.statusCode == 200) {
         final List<dynamic> data = jsonDecode(response.body);
         return data.map((item) => UserModel.fromMap(item, item['_id'] ?? '')).toList();
       }
       return [];
     } catch (e) {
       print('Error fetching users: $e');
       return [];
     }
  }

  // Add Contact via API
  Future<void> addContact(String name, String phone) async {
    final token = AuthService().token;
    if (token == null) throw Exception('Not authenticated');

    final url = Uri.parse('${ApiConfig.baseUrl}/contacts/add');
    print('POST Request to: $url');
    print('Body: ${jsonEncode({'name': name, 'phone': phone})}');

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': name,
        'phone': phone,
      }),
    );
    
    print('Response Status: ${response.statusCode}');
    print('Response Body: ${response.body}');

    if (response.statusCode != 200) {
      if (response.headers['content-type']?.contains('application/json') ?? false) {
          final err = jsonDecode(response.body);
          throw Exception(err['error'] ?? 'Failed to add contact');
      } else {
         throw Exception('Server Error (${response.statusCode}): ${response.body}');
      }
    }
  }

  // Normalize Phone Number helper
  String normalizePhoneNumber(String phone) {
    // Remove spaces, dashes, parentheses
    String cleaned = phone.replaceAll(RegExp(r'[\s-\(\)]'), '');
    return cleaned;
  }
}
