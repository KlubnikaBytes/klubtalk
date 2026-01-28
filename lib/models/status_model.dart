import 'package:whatsapp_clone/config/api_config.dart';
import 'package:whatsapp_clone/models/user_model.dart';

class Status {
  final String id;
  final String userId;
  final String type; // 'image', 'video', 'text'
  final String content;
  final String? mimeType;
  final String? caption;
  final String backgroundColor; // Hex string e.g. #7E57C2
  final DateTime createdAt;
  final List<String> viewers; // Just IDs for now
  final String privacy; // 'contacts', 'exclude', 'only'

  Status({
    required this.id,
    required this.userId,
    required this.type,
    required this.content,
    this.mimeType,
    this.caption,
    this.backgroundColor = '#7E57C2',
    required this.createdAt,
    this.viewers = const [],
    this.privacy = 'contacts',
  });

  factory Status.fromJson(Map<String, dynamic> json) {
    return Status(
      id: json['_id'] ?? '',
      userId: json['userId'] ?? '',
      type: json['type'] ?? 'text',
      content: (json['content'] != null && json['content'].startsWith('/')) 
          ? '${ApiConfig.baseUrl}${json['content']}' 
          : (json['content'] ?? ''),
      mimeType: json['mimeType'],
      caption: json['caption'],
      backgroundColor: json['backgroundColor'] ?? '#7E57C2',
      createdAt: DateTime.parse(json['createdAt']),
      viewers: (json['viewers'] as List?)?.map((v) => v['userId'].toString()).toList() ?? [],
      privacy: json['privacy'] ?? 'contacts',
    );
  }
  
  bool get isSeen => false; 
}

class UserStatus {
  final String userId;
  String userName;
  final String? userAvatar;
  final List<Status> statuses;
  final DateTime lastUpdate;
  final bool isMuted;

  UserStatus({
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.statuses,
    required this.lastUpdate,
    this.isMuted = false,
  });

  factory UserStatus.fromJson(Map<String, dynamic> json) {
    // The aggregation pipeline returns specific structure:
    // { _id: userId, user: { name, avatar... }, statuses: [], lastUpdate }
    // Or it might be flattened depending on projection.
    // Based on statusController: 
    /*
      {
        _id: userId,
        user: { name, avatar, phone },
        statuses: [ ... ],
        lastUpdate: ...
      }
    */
    
    final userObj = json['user'] ?? {};
    
    return UserStatus(
      userId: json['_id'] ?? '',
      userName: userObj['name'] ?? 'Unknown',
      userAvatar: (userObj['avatar'] != null && userObj['avatar'].toString().startsWith('/'))
          ? '${ApiConfig.baseUrl}${userObj['avatar']}'
          : userObj['avatar'],
      statuses: (json['statuses'] as List?)?.map((s) => Status.fromJson(s)).toList() ?? [],
      lastUpdate: DateTime.parse(json['lastUpdate']),
      isMuted: json['isMuted'] ?? false,
    );
  }
}
