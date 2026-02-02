import 'package:flutter/material.dart';

class ChatsSettingsScreen extends StatelessWidget {
  const ChatsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Display', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          _buildItem(Icons.brightness_medium, 'Theme', 'System default'),
          _buildItem(Icons.wallpaper, 'Wallpaper', ''),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Chat settings', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
           SwitchListTile(
            value: true, 
            onChanged: (val) {},
            title: const Text('Enter is send'),
            subtitle: const Text('Enter key will send your message'),
            secondary: const Icon(Icons.send),
          ),
          SwitchListTile(
            value: true, 
            onChanged: (val) {},
            title: const Text('Media visibility'),
            subtitle: const Text('Show newly downloaded media in your device gallery'),
            secondary: const Icon(Icons.image),
          ),
           _buildItem(Icons.font_download, 'Font size', 'Medium'),
           const Divider(),
           _buildItem(Icons.backup, 'Chat backup', ''),
           _buildItem(Icons.history, 'Chat history', ''),
        ],
      ),
    );
  }

  Widget _buildItem(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey),
      title: Text(title),
      subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
      onTap: () {},
    );
  }
}
