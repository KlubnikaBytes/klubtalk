import 'package:whatsapp_clone/services/auth_service.dart';

class MessageModel {
  final String id;
  final String text;
  final bool isSentByMe;
  final DateTime timestamp;
  final bool isRead;
  final String status;

  const MessageModel({
    required this.id,
    required this.text,
    required this.isSentByMe,
    required this.timestamp,
    required this.isRead,
    this.status = 'sent',
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    DateTime parsedTimestamp;
    try {
      if (json['createdAt'] != null) {
        parsedTimestamp = DateTime.parse(json['createdAt']).toLocal();
      } else {
        parsedTimestamp = DateTime.now();
      }
    } catch (e) {
      parsedTimestamp = DateTime.now();
    }

    final currentUserId = AuthService().currentUserId;
    final senderData = json['sender'];
    String? senderId;
    
    if (senderData is Map) {
      senderId = senderData['_id'];
    } else if (senderData is String) {
      senderId = senderData;
    } else {
      senderId = json['senderId'];
    }

    return MessageModel(
      id: json['_id'] ?? json['id'] ?? '',
      text: json['content'] ?? json['text'] ?? '',
      isSentByMe: currentUserId != null && senderId == currentUserId,
      timestamp: parsedTimestamp,
      isRead: json['readBy'] != null && (json['readBy'] as List).isNotEmpty,
      status: json['status'] ?? 'sent',
    );
  }
}
