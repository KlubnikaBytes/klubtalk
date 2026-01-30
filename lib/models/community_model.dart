import 'package:whatsapp_clone/models/group_model.dart';

class CommunityModel {
  final String id;
  final String name;
  final String description;
  final String photo;
  final String createdBy; // ID
  final List<String> adminIds;
  final List<String> memberIds;
  final List<String> groupIds;
  final String announcementsGroupId;
  final DateTime createdAt;
  
  // Optional: Populated fields
  final int membersCount;
  final int groupsCount;
  final List<GroupModel>? groups; // For details view

  CommunityModel({
    required this.id,
    required this.name,
    this.description = '',
    this.photo = '',
    required this.createdBy,
    required this.adminIds,
    required this.memberIds,
    required this.groupIds,
    required this.announcementsGroupId,
    required this.createdAt,
    this.membersCount = 0,
    this.groupsCount = 0,
    this.groups,
  });

  bool isAdmin(String userId) {
    return adminIds.contains(userId);
  }

  factory CommunityModel.fromJson(Map<String, dynamic> json) {
    return CommunityModel(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      photo: json['photo'] ?? '',
      createdBy: json['createdBy'] is String ? json['createdBy'] : (json['createdBy']?['_id'] ?? ''),
      adminIds: List<String>.from((json['admins'] as List?)?.map((e) => e is String ? e : e['_id']) ?? []),
      memberIds: List<String>.from((json['members'] as List?)?.map((e) => e is String ? e : e['_id']) ?? []),
      groupIds: List<String>.from((json['groups'] as List?)?.map((e) => e is String ? e : e['_id']).where((e) => e != null) ?? []),
      announcementsGroupId: json['announcementsGroupId'] is String ? json['announcementsGroupId'] : (json['announcementsGroupId']?['_id'] ?? ''),
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      
      membersCount: json['membersCount'] ?? (json['members'] as List?)?.length ?? 0,
      groupsCount: json['groupsCount'] ?? (json['groups'] as List?)?.length ?? 0,
      
      // If groups are populated (full objects)
      groups: (json['groups'] as List?)?.where((g) => g is Map<String, dynamic>).map((g) => GroupModel.fromJson(g)).toList(),
    );
  }
}
