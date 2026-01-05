class User {
  final String id;
  final String name;
  final String avatarUrl;
  final String phoneNumber;
  final String about;

  const User({
    required this.id,
    required this.name,
    required this.avatarUrl,
    this.phoneNumber = '',
    this.about = 'Hey there! I am using WhatsApp.',
  });
}

class Message {
  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final bool isRead;
  final bool isSentByMe;

  const Message({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    required this.isRead,
    required this.isSentByMe,
  });
}

class Chat {
  final String id;
  final User contact;
  final Message lastMessage;
  final int unreadCount;

  const Chat({
    required this.id,
    required this.contact,
    required this.lastMessage,
    // Provide a default for simplicity in some contexts, but usually required
    this.unreadCount = 0,
  });
}
