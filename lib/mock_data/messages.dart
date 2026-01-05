import 'package:whatsapp_clone/models/message_model.dart';

class MockMessages {
  static List<MessageModel> get initialMessages {
    final now = DateTime.now();
    return [
      MessageModel(
        id: '1',
        text: 'Hey! How are you doing today?',
        isSentByMe: false,
        timestamp: now.subtract(const Duration(hours: 2, minutes: 30)),
        isRead: true,
      ),
      MessageModel(
        id: '2',
        text: 'I\'m good, thanks for asking! Just working on some Flutter UI code.',
        isSentByMe: true,
        timestamp: now.subtract(const Duration(hours: 2, minutes: 28)),
        isRead: true, // Double blue check
      ),
      MessageModel(
        id: '3',
        text: 'That sounds awesome. Is it the Messaging App project?',
        isSentByMe: false,
        timestamp: now.subtract(const Duration(hours: 2, minutes: 25)),
        isRead: true,
      ),
      MessageModel(
        id: '4',
        text: 'Yes, exactly! I\'m trying to make it pixel perfect.',
        isSentByMe: true,
        timestamp: now.subtract(const Duration(hours: 2, minutes: 24)),
        isRead: true,
      ),
      MessageModel(
        id: '5',
        text: 'Nice! Don\'t forget the animations.',
        isSentByMe: false,
        timestamp: now.subtract(const Duration(hours: 2, minutes: 20)),
        isRead: true,
      ),
      MessageModel(
        id: '6',
        text: 'I won\'t. I\'m adding hero animations and simple fade transitions.',
        isSentByMe: true,
        timestamp: now.subtract(const Duration(hours: 2, minutes: 18)),
        isRead: false, // Single grey check (conceptually, though UI might just show double grey)
      ),
    ];
  }
}
