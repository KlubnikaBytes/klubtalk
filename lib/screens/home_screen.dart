import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _lastChatId;

  Future<void> insertUser() async {
    try {
      await FirebaseFirestore.instance.collection('users').doc('user_001').set({
        'name': 'Klubnika',
        'phone': '+91XXXXXXXXXX',
        'online': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User Inserted!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> insertChat() async {
    try {
      DocumentReference ref = await FirebaseFirestore.instance.collection('chats').add({
        'participants': ['user_001', 'user_002'],
        'lastMessage': 'Hello',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      setState(() {
        _lastChatId = ref.id;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Chat Created! ID: ${ref.id}')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> insertMessage() async {
    if (_lastChatId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Create a chat first!')));
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(_lastChatId)
          .collection('messages')
          .add({
        'senderId': 'user_001',
        'text': 'Hello World ${DateTime.now().second}',
        'timestamp': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message Sent!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firestore Data Seeder')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: insertUser,
              child: const Text('1. Insert User (user_001)'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: insertChat,
              child: const Text('2. Insert Chat'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: insertMessage,
              child: const Text('3. Insert Message'),
            ),
            const SizedBox(height: 20),
            if (_lastChatId != null) Text('Last Chat ID: $_lastChatId'),
          ],
        ),
      ),
    );
  }
}
