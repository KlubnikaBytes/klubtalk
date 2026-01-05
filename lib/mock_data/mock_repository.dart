import 'package:whatsapp_clone/models/project_models.dart';

class MockRepository {
  static const User currentUser = User(
    id: 'me',
    name: 'Me',
    avatarUrl: 'https://i.pravatar.cc/150?u=me',
    phoneNumber: '+1 555 012 3456',
  );

  static final List<User> contacts = [
    const User(id: 'u1', name: 'Alice Smith', avatarUrl: 'https://i.pravatar.cc/150?u=1'),
    const User(id: 'u2', name: 'Bob Johnson', avatarUrl: 'https://i.pravatar.cc/150?u=2'),
    const User(id: 'u3', name: 'Carol Williams', avatarUrl: 'https://i.pravatar.cc/150?u=3'),
    const User(id: 'u4', name: 'David Brown', avatarUrl: 'https://i.pravatar.cc/150?u=4'),
    const User(id: 'u5', name: 'Eva Davis', avatarUrl: 'https://i.pravatar.cc/150?u=5'),
  ];

  static final List<Chat> chats = [
    Chat(
      id: 'c1',
      contact: contacts[0],
      lastMessage: Message(
        id: 'm1',
        senderId: 'u1',
        text: 'Hey, how are you doing?',
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        isRead: true,
        isSentByMe: false,
      ),
      unreadCount: 2,
    ),
    Chat(
      id: 'c2',
      contact: contacts[1],
      lastMessage: Message(
        id: 'm2',
        senderId: 'me',
        text: 'See you tomorrow!',
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
        isRead: true,
        isSentByMe: true,
      ),
      unreadCount: 0,
    ),
    Chat(
      id: 'c3',
      contact: contacts[2],
      lastMessage: Message(
        id: 'm3',
        senderId: 'u3',
        text: 'Can you send me the file?',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        isRead: false,
        isSentByMe: false,
      ),
      unreadCount: 1,
    ),
  ];

  static List<Message> getMessages(String chatId) {
    // Generate some mock history
    return [
      Message(
        id: 'msg1',
        senderId: 'me',
        text: 'Hi there!',
        timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
        isRead: true,
        isSentByMe: true,
      ),
      Message(
        id: 'msg2',
        senderId: 'other',
        text: 'Hello! Long time no see.',
        timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 1, minutes: 55)),
        isRead: true,
        isSentByMe: false,
      ),
       Message(
        id: 'msg3',
        senderId: 'me',
        text: 'I know right? How have you been?',
        timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 1, minutes: 50)),
        isRead: true,
        isSentByMe: true,
      ),
       Message(
        id: 'msg4',
        senderId: 'other',
        text: 'Pretty good, just busy with work.',
        timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 1, minutes: 45)),
        isRead: true,
        isSentByMe: false,
      ),
    ];
  }
}
