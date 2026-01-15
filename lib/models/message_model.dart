class MessageModel {
  final String id;
  final String text;
  final bool isSentByMe;
  final DateTime timestamp;
  final bool isRead;

  const MessageModel({
    required this.id,
    required this.text,
    required this.isSentByMe,
    required this.timestamp,
    required this.timestamp,
    required this.isRead,
    this.status = 'sent',
  });
  
  final String status;
}
