import 'package:flutter/material.dart';
import 'package:whatsapp_clone/models/contact.dart';
import 'package:whatsapp_clone/utils/platform_helper.dart'; // Assuming this exists or similar
import 'package:whatsapp_clone/widgets/avatar_widget.dart';

class GlobalSearchOverlay extends StatelessWidget {
  final Map<String, dynamic> results;
  final bool isLoading;
  final Function(String, Map<String, dynamic>?) onResultTap; // type, data

  const GlobalSearchOverlay({
    super.key,
    required this.results,
    required this.isLoading,
    required this.onResultTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF075E54))));
    }

    final contacts = (results['contacts'] as List?) ?? [];
    final chats = (results['chats'] as List?) ?? [];
    final messages = (results['messages'] as List?) ?? [];

    if (contacts.isEmpty && chats.isEmpty && messages.isEmpty) {
      return Container(
        color: Colors.white,
        alignment: Alignment.topCenter,
        padding: const EdgeInsets.only(top: 50),
        child: const Text("No results found", style: TextStyle(color: Colors.grey, fontSize: 16)),
      );
    }

    return Container(
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 0),
        children: [
          if (contacts.isNotEmpty) ...[
            _buildSectionHeader("Contacts"),
            ...contacts.map((c) => _buildContactTile(c)),
          ],
          if (chats.isNotEmpty) ...[
            _buildSectionHeader("Chats"),
            ...chats.map((c) => _buildChatTile(c)),
          ],
          if (messages.isNotEmpty) ...[
            _buildSectionHeader("Messages"),
            ...messages.map((m) => _buildMessageTile(m)),
          ],
          const SizedBox(height: 50), // Bottom padding
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFFF0F2F5),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF075E54),
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildContactTile(Map<String, dynamic> data) {
    return ListTile(
      leading: AvatarWidget(imageUrl: data['avatar'] ?? '', radius: 20),
      title: _highlightText(data['name'] ?? '', ''), // Logic for highlight could be passed but simple for now
      subtitle: Text(data['about'] ?? 'Hey there! I am using WhatsApp.'),
      onTap: () => onResultTap('contact', data),
    );
  }

  Widget _buildChatTile(Map<String, dynamic> data) {
    return ListTile(
      leading: AvatarWidget(imageUrl: data['groupPhoto'] ?? '', radius: 20),
      title: _highlightText(data['groupName'] ?? '', ''),
      subtitle: const Text("Group"),
      onTap: () => onResultTap('chat', data),
    );
  }

  Widget _buildMessageTile(Map<String, dynamic> data) {
    final sender = data['senderId'];
    final senderName = sender is Map ? sender['name'] : 'Unknown';
    final chat = data['chatId'];
    final chatName = chat is Map && chat['isGroup'] == true ? chat['groupName'] : senderName;
    
    // For DM explanation: 
    // If it's a DM, backend might have populated 'chatId' with participants or we use 'senderId'
    // Let's assume title is Chat Name, subtitle is "Sender: Message"
    
    return ListTile(
      leading: const CircleAvatar(backgroundColor: Colors.transparent, child: Icon(Icons.search, color: Colors.grey)), 
      title: Text(chatName, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(
        "$senderName: ${data['content']}",
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        _formatDate(data['timestamp']),
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      onTap: () => onResultTap('message', data),
    );
  }
  
  // Simple Date Formatter
  String _formatDate(String? timestamp) {
     if (timestamp == null) return '';
     final date = DateTime.tryParse(timestamp);
     if (date == null) return '';
     return "${date.month}/${date.day}/${date.year}"; 
  }

  // Helper for highlighting - We will pass query logic later if needed
  Widget _highlightText(String text, String query) {
     return Text(text, style: const TextStyle(fontWeight: FontWeight.bold)); 
  }
}
