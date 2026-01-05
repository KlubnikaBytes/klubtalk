import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatTestScreen extends StatelessWidget {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  ChatTestScreen({super.key});

  void addChat() async {
    try {
      await firestore.collection('chats').add({
        'user': 'Me',
        'message': 'Hello World!',
        'timestamp': FieldValue.serverTimestamp(),
      });
      print('Message added!');
    } catch (e) {
      print('Error adding chat: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test Chat Insert')),
      body: Center(
        child: ElevatedButton(
          onPressed: addChat,
          child: const Text('Send Test Message'),
        ),
      ),
    );
  }
}
