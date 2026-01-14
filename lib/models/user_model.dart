// import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String phoneNumber;
  final String name;
  final String about;
  final String profilePhotoUrl;
  final bool isOnline;
  final DateTime? lastSeen;
  
  // Privacy Settings (0: Everyone, 1: Contacts, 2: Nobody)
  final int lastSeenVisibility;
  final int profilePhotoVisibility;
  final int aboutVisibility;
  final bool readReceipts;
  
  final List<String> blockedUsers;

  UserModel({
    required this.uid,
    required this.phoneNumber,
    this.name = '',
    this.about = 'Hey there! I am using WhatsApp.',
    this.profilePhotoUrl = '',
    this.isOnline = false,
    this.lastSeen,
    this.lastSeenVisibility = 0,
    this.profilePhotoVisibility = 0,
    this.aboutVisibility = 0,
    this.readReceipts = true,
    this.blockedUsers = const [],
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    // Handle lastSeen as String (Backend JSON) or DateTime
    DateTime? lastSeenVal;
    final lastSeenRaw = map['lastSeen'];
    if (lastSeenRaw is String) {
      lastSeenVal = DateTime.tryParse(lastSeenRaw);
    } else if (lastSeenRaw is int) {
       lastSeenVal = DateTime.fromMillisecondsSinceEpoch(lastSeenRaw);
    }
    
    return UserModel(
      uid: uid,
      phoneNumber: map['phone'] ?? map['phoneNumber'] ?? '', // Handle both backend 'phone' and old 'phoneNumber'
      name: map['name'] ?? '',
      about: map['about'] ?? 'Hey there! I am using WhatsApp.',
      profilePhotoUrl: map['avatar'] ?? map['profilePhotoUrl'] ?? '',
      isOnline: map['isOnline'] ?? false,
      lastSeen: lastSeenVal,
      lastSeenVisibility: map['lastSeenVisibility'] ?? 0,
      profilePhotoVisibility: map['profilePhotoVisibility'] ?? 0,
      aboutVisibility: map['aboutVisibility'] ?? 0,
      readReceipts: map['readReceipts'] ?? true,
      blockedUsers: List<String>.from(map['blockedUsers'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'phoneNumber': phoneNumber,
      'name': name,
      'about': about,
      'profilePhotoUrl': profilePhotoUrl,
      'isOnline': isOnline,
      'lastSeen': lastSeen?.toIso8601String(),
      'lastSeenVisibility': lastSeenVisibility,
      'profilePhotoVisibility': profilePhotoVisibility,
      'aboutVisibility': aboutVisibility,
      'readReceipts': readReceipts,
      'blockedUsers': blockedUsers,
    };
  }
}
