// Simple in-memory store to maintain state across tabs/screens for the session.
// Since we cannot modify the backend, this acts as our client-side database enhancement.

import 'package:flutter/foundation.dart';

class ChatSessionStore {
  // Singleton pattern not strictly needed if fields are static, but good for listeners.
  static final ChatSessionStore _instance = ChatSessionStore._internal();
  factory ChatSessionStore() => _instance;
  ChatSessionStore._internal();

  // Observable state to trigger UI updates across tabs
  final ValueNotifier<Set<String>> archivedChatIds = ValueNotifier({});
  final ValueNotifier<Set<String>> mutedChatIds = ValueNotifier({});
  final ValueNotifier<Set<String>> markedUnreadChatIds = ValueNotifier({});
  final ValueNotifier<Set<String>> deletedChatIds = ValueNotifier({});

  void archiveChat(String chatId) {
    var set = Set<String>.from(archivedChatIds.value);
    set.add(chatId);
    archivedChatIds.value = set;
  }

  void unarchiveChat(String chatId) {
    var set = Set<String>.from(archivedChatIds.value);
    set.remove(chatId);
    archivedChatIds.value = set;
  }

  void muteChat(String chatId) {
    var set = Set<String>.from(mutedChatIds.value);
    set.add(chatId);
    mutedChatIds.value = set;
  }

  void unmuteChat(String chatId) {
    var set = Set<String>.from(mutedChatIds.value);
    set.remove(chatId);
    mutedChatIds.value = set;
  }

  void markUnread(String chatId) {
    var set = Set<String>.from(markedUnreadChatIds.value);
    set.add(chatId);
    markedUnreadChatIds.value = set;
  }

  void markRead(String chatId) {
    var set = Set<String>.from(markedUnreadChatIds.value);
    set.remove(chatId);
    markedUnreadChatIds.value = set;
  }

  void deleteChat(String chatId) {
    var set = Set<String>.from(deletedChatIds.value);
    set.add(chatId);
    deletedChatIds.value = set;
  }

  bool isArchived(String chatId) => archivedChatIds.value.contains(chatId);
  bool isMuted(String chatId) => mutedChatIds.value.contains(chatId);
  bool isMarkedUnread(String chatId) => markedUnreadChatIds.value.contains(chatId);
  bool isDeleted(String chatId) => deletedChatIds.value.contains(chatId);
  
  // Refresh Signal for cross-screen updates
  final ValueNotifier<int> refreshTrigger = ValueNotifier(0);
  void triggerRefresh() {
    refreshTrigger.value++;
  }
}
