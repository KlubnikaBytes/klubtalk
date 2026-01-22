import 'dart:convert';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:whatsapp_clone/models/user_model.dart';
import 'package:whatsapp_clone/utils/permission_helper.dart';
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

  // Static explicit cache to prevent repeated Native Channel calls
  static List<Contact>? _cachedContacts;

  // Clear cache helper
  void clearContactCache() {
    _cachedContacts = null;
  }

  // Fetch Device Contacts
  Future<List<Contact>> getDeviceContacts({bool forceRefresh = false}) async {
    // 1. Return Cache if available
    if (_cachedContacts != null && !forceRefresh) {
        return _cachedContacts!;
    }

    // Android 13+ / Personal Profile Fix: Explicitly request permission via handler first
    bool hasPermission = await PermissionHelper.requestContactPermission();
    if (!hasPermission) {
        return [];
    }

    // Still call FlutterContacts request to ensure plugin is happy
    if (await FlutterContacts.requestPermission(readonly: true)) {
      final  contacts = await FlutterContacts.getContacts(withProperties: true, withPhoto: true);
      _cachedContacts = contacts; // Update Cache
      return contacts;
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
  // Normalize phone number to +91XXXXXXXXXX
  String normalizePhoneNumber(String phone) {
    String p = phone.replaceAll(RegExp(r'\D'), '');
    if (p.length == 10) return '+91$p';
    if (p.length == 12 && p.startsWith('91')) return '+$p';
    if (p.length > 10 && p.startsWith('0')) return '+91${p.substring(1)}';
    return '+$p';
  }

  // New Sync Method
  Future<Map<String, dynamic>> syncContacts(List<String> phones) async {
    try {
      final token = await AuthService().storage.read(key: 'jwt_token');
      // Normalize all
      final normalized = phones.map((p) => normalizePhoneNumber(p)).toList();
      
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/contacts/sync'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'contacts': normalized}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to sync contacts');
      }
    } catch (e) {
      print('Sync Error: $e');
      rethrow;
    }
  }
  // Resolve Contact Name from Peer ID
  Future<String> resolveContactName(String peerId) async {
     try {
       // 1. Get All Registered Users (to find phone number of peerId)
       // Optimization: In a real app, use GET /users/:id or check local DB. 
       // Here we rely on getRegisteredUsers as per constraints.
       List<UserModel> users = await getRegisteredUsers();
       
       final user = users.firstWhere(
           (u) => u.uid == peerId, 
           orElse: () => UserModel(uid: '', phoneNumber: '', name: 'Unknown')
       );
       
       if (user.phoneNumber.isEmpty) return 'Unknown'; // Fallback
       
       // 2. Get Device Contacts
       final deviceContacts = await getDeviceContacts();
       final normalizedUserPhone = normalizePhoneNumber(user.phoneNumber);
       
       // 3. Match
       for (var contact in deviceContacts) {
          for (var phone in contact.phones) {
             if (normalizePhoneNumber(phone.number) == normalizedUserPhone) {
                return contact.displayName;
             }
          }
       }
       
        // 4. Fallback to User Name if not in contacts
        // STRICT RULE: If not in contacts, show Phone Number ONLY. 
        // Do NOT show user.name from backend.
        return user.phoneNumber.isNotEmpty ? user.phoneNumber : 'Unknown';
        
      } catch (e) {
        print("Name Resolution Error: $e");
        return 'Unknown';
      }
   }

   // NEW: Strict Phone Number Resolver
   Future<String> getContactNameFromPhone(String phone) async {
     try {
       final normalized = normalizePhoneNumber(phone);
       final deviceContacts = await getDeviceContacts();

       for (var contact in deviceContacts) {
          for (var p in contact.phones) {
             if (normalizePhoneNumber(p.number) == normalized) {
                return contact.displayName;
             }
          }
       }
       // If not in contacts, return phone number
       return phone;
     } catch (e) {
       return phone;
     }
   }
}
