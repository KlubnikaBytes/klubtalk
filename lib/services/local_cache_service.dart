import 'package:hive/hive.dart';

class LocalCacheService {
  static const _contactsBox = 'contacts_cache';
  static const _chatsBox = 'chats_cache';
  static const _messagesBox = 'messages_cache';
  static const _statusBox = 'status_cache';

  /// CONTACTS (PERMANENT)
  Future<void> cacheContacts(List contacts) async {
    final box = await Hive.openBox(_contactsBox);
    await box.put('list', contacts);
  }

  Future<List> getCachedContacts() async {
    final box = await Hive.openBox(_contactsBox);
    return box.get('list', defaultValue: []);
  }

  /// CHATS (PERMANENT)
  Future<void> cacheChats(List chats) async {
    final box = await Hive.openBox(_chatsBox);
    await box.put('list', chats);
  }

  Future<List> getCachedChats() async {
    final box = await Hive.openBox(_chatsBox);
    return box.get('list', defaultValue: []);
  }

  /// MESSAGES (PER CHAT PERMANENT)
  Future<void> cacheMessages(String chatId, List messages) async {
    final box = await Hive.openBox(_messagesBox);
    await box.put(chatId, messages);
  }

  Future<List> getCachedMessages(String chatId) async {
    final box = await Hive.openBox(_messagesBox);
    return box.get(chatId, defaultValue: []);
  }

  /// STATUS (24 HOURS ONLY)
  Future<void> cacheStatus(List statusList) async {
    final box = await Hive.openBox(_statusBox);
    await box.put('data', {
      'time': DateTime.now().millisecondsSinceEpoch,
      'list': statusList,
    });
  }

  Future<List> getCachedStatus() async {
    final box = await Hive.openBox(_statusBox);
    final data = box.get('data');

    if (data == null) return [];

    final savedTime = DateTime.fromMillisecondsSinceEpoch(data['time']);
    final diff = DateTime.now().difference(savedTime).inHours;

    if (diff >= 24) {
      await box.delete('data'); // auto expire
      return [];
    }

    return data['list'];
  }

  /// USERS (PERMANENT)
  static const _usersBox = 'users_cache';

  Future<void> cacheUserProfile(String userId, Map<String, dynamic> data) async {
    final box = await Hive.openBox(_usersBox);
    await box.put(userId, data);
  }

  Future<Map<String, dynamic>?> getCachedUserProfile(String userId) async {
    final box = await Hive.openBox(_usersBox);
    final data = box.get(userId);
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  /// CLEAR ALL CACHE (optional future use)
  Future<void> clearAll() async {
    await Hive.deleteBoxFromDisk(_contactsBox);
    await Hive.deleteBoxFromDisk(_chatsBox);
    await Hive.deleteBoxFromDisk(_messagesBox);
    await Hive.deleteBoxFromDisk(_statusBox);
    await Hive.deleteBoxFromDisk(_usersBox);
  }
}
