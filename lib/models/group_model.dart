class GroupModel {
  final String id;
  final String name;
  final String description;
  final String avatar;
  final List<String> participants;
  final List<String> admins;
  final String editInfoPermission; // 'all' or 'admins'
  final String sendMessagePermission; // 'all' or 'admins'
  final String addParticipantsPermission; // 'all' or 'admins'
  final DateTime? createdAt;
  final String? createdBy;

  GroupModel({
    required this.id,
    required this.name,
    this.description = '',
    this.avatar = '',
    required this.participants,
    required this.admins,
    this.editInfoPermission = 'all',
    this.sendMessagePermission = 'all',
    this.addParticipantsPermission = 'all',
    this.createdAt,
    this.createdBy,
  });

  // Helper methods
  bool isAdmin(String userId) {
    return admins.contains(userId);
  }

  bool canEditInfo(String userId) {
    return editInfoPermission == 'all' || isAdmin(userId);
  }

  bool canSendMessage(String userId) {
    return sendMessagePermission == 'all' || isAdmin(userId);
  }

  bool canAddParticipants(String userId) {
    return addParticipantsPermission == 'all' || isAdmin(userId);
  }

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['groupName'] ?? '',
      description: json['groupDescription'] ?? '',
      avatar: json['groupAvatar'] ?? '',
      participants: List<String>.from(
        (json['participants'] as List?)?.map((p) => 
          p is String ? p : p['_id'] ?? p['id'] ?? ''
        ) ?? []
      ),
      admins: List<String>.from(
        (json['groupAdmins'] as List?)?.map((a) => 
          a is String ? a : a['_id'] ?? a['id'] ?? ''
        ) ?? (json['groupAdmin'] != null ? [json['groupAdmin']] : [])
      ),
      editInfoPermission: json['editInfoPermission'] ?? 'all',
      sendMessagePermission: json['sendMessagePermission'] ?? 'all',
      addParticipantsPermission: json['addParticipantsPermission'] ?? 'all',
      createdAt: json['createdAt'] != null 
        ? DateTime.tryParse(json['createdAt']) 
        : null,
      createdBy: json['createdBy'] is String 
        ? json['createdBy'] 
        : json['createdBy']?['_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'groupName': name,
      'groupDescription': description,
      'groupAvatar': avatar,
      'participants': participants,
      'groupAdmins': admins,
      'editInfoPermission': editInfoPermission,
      'sendMessagePermission': sendMessagePermission,
      'addParticipantsPermission': addParticipantsPermission,
      'createdAt': createdAt?.toIso8601String(),
      'createdBy': createdBy,
    };
  }
}
