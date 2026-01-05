class ChatModel {
  final String id;
  final String name;
  final String avatarUrl;
  final String lastMessage; // Text preview
  final String time;        // Formatted timestamp string
  final int unreadCount;

  const ChatModel({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.lastMessage,
    required this.time,
    required this.unreadCount,
  });
}
