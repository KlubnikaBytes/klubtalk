import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:whatsapp_clone/models/user_model.dart';
import 'package:whatsapp_clone/models/contact.dart' as app_contact;

class ContactService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  // Stream of ALL Registered Users (For Matching)
  // Note: For a real app with millions of users, we'd hash contacts and use Cloud Functions.
  // For a clone/prototype, fetching 'users' collection is standard and performant enough.
  Stream<List<UserModel>> getRegisteredUsersStream() {
    return _firestore.collection('users').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => UserModel.fromMap(doc.data(), doc.id)).toList();
    });
  }

  // Normalize Phone Number helper
  String normalizePhoneNumber(String phone) {
    // Remove spaces, dashes, parentheses
    String cleaned = phone.replaceAll(RegExp(r'[\s-\(\)]'), '');
    // Ensure it starts with +, if local, might need Country Code (Assuming IN +91 for now or leaving as is)
    // Detailed normalization requires `libphonenumber` package, for this clone we'll do basic cleaning.
    return cleaned;
  }
}
