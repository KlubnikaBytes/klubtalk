import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:whatsapp_clone/models/user_model.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String get currentUid => _auth.currentUser!.uid;

  // Get Current User Data
  Stream<UserModel> get currentUserStream {
    return _firestore
        .collection('users')
        .doc(currentUid)
        .snapshots()
        .map((snapshot) => UserModel.fromMap(snapshot.data()!, snapshot.id));
  }

  // Update Profile Info (Name, About)
  Future<void> updateProfile({String? name, String? about}) async {
    final Map<String, dynamic> data = {};
    if (name != null) data['name'] = name;
    if (about != null) data['about'] = about;
    
    await _firestore.collection('users').doc(currentUid).update(data);
  }

  // Update Profile Photo
  Future<String> updateProfilePhoto(File imageFile) async {
    try {
      final ref = _storage.ref().child('profile_photos/$currentUid.jpg');
      await ref.putFile(imageFile);
      final url = await ref.getDownloadURL();
      
      await _firestore.collection('users').doc(currentUid).update({
        'profilePhotoUrl': url,
      });
      
      return url;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  // Update Privacy Settings
  Future<void> updatePrivacySettings({
    int? lastSeenVisibility,
    int? profilePhotoVisibility,
    int? aboutVisibility,
    bool? readReceipts,
  }) async {
    final Map<String, dynamic> data = {};
    if (lastSeenVisibility != null) data['lastSeenVisibility'] = lastSeenVisibility;
    if (profilePhotoVisibility != null) data['profilePhotoVisibility'] = profilePhotoVisibility;
    if (aboutVisibility != null) data['aboutVisibility'] = aboutVisibility;
    if (readReceipts != null) data['readReceipts'] = readReceipts;

    await _firestore.collection('users').doc(currentUid).update(data);
  }

  // Set Online Status
  Future<void> setOnlineStatus(bool isOnline) async {
    await _firestore.collection('users').doc(currentUid).update({
      'isOnline': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }
}
