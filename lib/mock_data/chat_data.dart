import 'package:whatsapp_clone/models/chat_model.dart';

class ChatData {
  static const List<ChatModel> list = [
    ChatModel(
      id: '1',
      name: 'Alice Smith',
      avatarUrl: 'https://i.pravatar.cc/150?u=1',
      lastMessage: 'Hey, are we still on for lunch?',
      time: '12:30 PM',
      unreadCount: 2,
    ),
    ChatModel(
      id: '2',
      name: 'Bob Johnson',
      avatarUrl: 'https://i.pravatar.cc/150?u=2',
      lastMessage: 'I sent you the file.',
      time: 'Yesterday',
      unreadCount: 0,
    ),
    ChatModel(
      id: '3',
      name: 'Carol Williams',
      avatarUrl: 'https://i.pravatar.cc/150?u=3',
      lastMessage: 'Thanks!',
      time: 'Yesterday',
      unreadCount: 0,
    ),
    ChatModel(
      id: '4',
      name: 'David Brown',
      avatarUrl: 'https://i.pravatar.cc/150?u=4',
      lastMessage: 'Meeting starts in 10 mins',
      time: 'Monday',
      unreadCount: 1,
    ),
    ChatModel(
      id: '5',
      name: 'Eva Davis',
      avatarUrl: 'https://i.pravatar.cc/150?u=5',
      lastMessage: 'Can you call me?',
      time: 'Sunday',
      unreadCount: 5,
    ),
    ChatModel(
      id: '6',
      name: 'Frank Miller',
      avatarUrl: 'https://i.pravatar.cc/150?u=6',
      lastMessage: 'See you later',
      time: '12/25/23',
      unreadCount: 0,
    ),
    ChatModel(
      id: '7',
      name: 'Grace Wilson',
      avatarUrl: 'https://i.pravatar.cc/150?u=7',
      lastMessage: 'Happy New Year!',
      time: '12/31/23',
      unreadCount: 0,
    ),
  ];
}
