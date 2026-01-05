import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMeta {
  final String chatId;
  final int unreadCount;
  final bool isFavorite;
  final bool isArchived;
  final DateTime? lastSeenMessageTime;

  ChatMeta({
    required this.chatId,
    this.unreadCount = 0,
    this.isFavorite = false,
    this.isArchived = false,
    this.lastSeenMessageTime,
  });

  factory ChatMeta.fromMap(Map<String, dynamic> map, String id) {
    return ChatMeta(
      chatId: id,
      unreadCount: map['unreadCount'] ?? 0,
      isFavorite: map['isFavorite'] ?? false,
      isArchived: map['isArchived'] ?? false,
      lastSeenMessageTime: map['lastSeenMessageTime'] != null 
          ? (map['lastSeenMessageTime'] as Timestamp).toDate() 
          : null,
    );
  }
}
