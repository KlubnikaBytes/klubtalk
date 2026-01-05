import 'package:flutter/material.dart';
import 'package:whatsapp_clone/models/contact.dart';
import 'package:whatsapp_clone/screens/chat_list_screen.dart';
import 'package:whatsapp_clone/screens/chat_screen.dart';

class WebLayoutScreen extends StatefulWidget {
  const WebLayoutScreen({super.key});

  @override
  State<WebLayoutScreen> createState() => _WebLayoutScreenState();
}

class _WebLayoutScreenState extends State<WebLayoutScreen> {
  // State for Right Panel
  Widget? _selectedChatView;

  void _onChatSelected(Contact contact, String peerId, String chatId) {
    setState(() {
      _selectedChatView = ChatScreen(
        contact: contact, 
        peerId: peerId, 
        chatId: chatId,
        // Optional: You might want to hide the back button on web
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Panel: Chat List (with AppBar/Tabs/FAB re-used from Mobile Layout)
          Expanded(
            flex: 3, 
            child: MobileChatLayout(
              isWeb: true,
              onChatSelected: _onChatSelected,
            ),
          ),
          
          // Divider
          const VerticalDivider(width: 1, color: Colors.grey),

          // Right Panel: Chat or Placeholder
          Expanded(
            flex: 7,
            child: _selectedChatView ?? Container(
              color: const Color(0xFFF0F2F5),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat, size: 80, color: Colors.grey),
                    SizedBox(height: 20),
                    Text(
                      'Select a chat to start messaging',
                      style: TextStyle(fontSize: 20, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
