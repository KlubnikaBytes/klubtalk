import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:whatsapp_clone/services/media_upload_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Create or Get existing Chat ID
  Future<String> createOrGetChat(String otherUserId) async {
    final currentUserId = _auth.currentUser!.uid;
    
    // Check if chat exists (We use a deterministic ID for 1-to-1 chats: uid1_uid2 sorted)
    List<String> ids = [currentUserId, otherUserId];
    ids.sort();
    String chatId = ids.join('_');

    final chatDoc = await _firestore.collection('chats').doc(chatId).get();

    if (!chatDoc.exists) {
      // Create new chat document
      await _firestore.collection('chats').doc(chatId).set({
        'participants': ids,
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(), // To show at top initially or handle sorting
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    return chatId;
  }

  // Send Message and Update Chat Metadata
  Future<void> sendMessage(String chatId, String text) async {
    final currentUserId = _auth.currentUser!.uid;
    final timestamp = FieldValue.serverTimestamp();

    // 1. Add Message
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add({
      'senderId': currentUserId,
      'text': text,
      'timestamp': timestamp,
      'seen': false,
    });

    // 2. Update Chat Metadata (for the chat list)
    await _firestore.collection('chats').doc(chatId).update({
      'lastMessage': text,
      'lastMessageTime': timestamp,
    });

    // 3. Update User Meta
    await _updateChatMetaForNewMessage(chatId, timestamp);
  }

  // Send Voice Message
  Future<void> sendVoiceMessage(String chatId, String filePath, int durationSeconds) async {
    final currentUserId = _auth.currentUser!.uid;
    final timestamp = FieldValue.serverTimestamp();
    final messageId =  FirebaseFirestore.instance.collection('chats').doc().id; // Auto ID

    try {
      // 1. Upload File via VPS Service
      final uploadService = MediaUploadService();
      final downloadUrl = await uploadService.uploadAudio(filePath);

      // 2. Add Message to Firestore
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId) // Use the same ID
          .set({
        'senderId': currentUserId,
        'type': 'audio',
        'audioUrl': downloadUrl,
        'duration': durationSeconds,
        'timestamp': timestamp,
        'seen': false,
      });

      // 3. Update Chat Metadata
      await _firestore.collection('chats').doc(chatId).update({
        'lastMessage': '🎙️ Voice message',
        'lastMessageTime': timestamp,
      });

      // 4. Update User-Specific Metadata (Increment Unread for others)
      await _updateChatMetaForNewMessage(chatId, timestamp);
      
    } catch (e) {
      print('Error sending voice message: $e');
      rethrow;
    }
  }

  // Helper: Update Metadata for Participants
  Future<void> _updateChatMetaForNewMessage(String chatId, FieldValue timestamp) async {
    final chatDoc = await _firestore.collection('chats').doc(chatId).get();
    final participants = List<String>.from(chatDoc['participants']);
    final currentUserId = _auth.currentUser!.uid;

    final batch = _firestore.batch();

    for (var userId in participants) {
      final docRef = _firestore.collection('users').doc(userId).collection('chatMeta').doc(chatId);
      
      if (userId == currentUserId) {
        // For Sender: Reset Unread, Update Time
        batch.set(docRef, {
          'unreadCount': 0,
          'lastSeenMessageTime': timestamp,
        }, SetOptions(merge: true));
      } else {
        // For Receiver: Increment Unread
        batch.set(docRef, {
          'unreadCount': FieldValue.increment(1),
          // We don't update lastSeenMessageTime for receiver until they open it? 
          // Actually, keeping it updated helps sorting "All" if we switched to meta-only.
          // For now, let's just update unread.
        }, SetOptions(merge: true));
      }
    }
    
    await batch.commit();
  }

  // Toggle Favorite
  Future<void> toggleFavorite(String chatId, bool isFavorite) async {
    final uid = _auth.currentUser!.uid;
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('chatMeta')
        .doc(chatId)
        .set({'isFavorite': isFavorite}, SetOptions(merge: true));
  }

  // Mark Read (Open Chat)
  Future<void> markChatAsRead(String chatId) async {
    final uid = _auth.currentUser!.uid;
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('chatMeta')
        .doc(chatId)
        .set({'unreadCount': 0}, SetOptions(merge: true));
  }

  // Mark Unread (Manual)
  Future<void> markChatAsUnread(String chatId) async {
    final uid = _auth.currentUser!.uid;
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('chatMeta')
        .doc(chatId)
        .set({'unreadCount': 1}, SetOptions(merge: true)); // Set to 1 explicitly or increment? WhatsApp usually emphasizes it dot.
  }

  // Create Group Chat
  Future<String> createGroupChat(String groupName, List<String> participantUids) async {
    final currentUserId = _auth.currentUser!.uid;
    // Ensure current user is in participants
    final allParticipants = {...participantUids, currentUserId}.toList();
    
    final newChatDoc = _firestore.collection('chats').doc();
    
    await newChatDoc.set({
      'isGroup': true,
      'groupName': groupName,
      'groupPhoto': '', // Placeholder
      'createdBy': currentUserId,
      'participants': allParticipants,
      'lastMessage': 'Group created',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    return newChatDoc.id;
  }
}
