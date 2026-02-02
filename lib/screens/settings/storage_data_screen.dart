import 'package:flutter/material.dart';

class StorageDataScreen extends StatelessWidget {
  const StorageDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Storage and data')),
      body: ListView(
        children: [
          _buildItem(Icons.folder_open, 'Manage storage', '2.5 GB used'),
          const Divider(),
          _buildItem(Icons.data_usage, 'Network usage', '1.2 GB sent • 4.5 GB received'),
          const Divider(),
           SwitchListTile(
            value: true, 
            onChanged: (val) {},
            title: const Text('Use less data for calls'),
            secondary:  const SizedBox(),
          ),
          const Divider(),
           const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Media auto-download', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
           _buildItem(null, 'When using mobile data', 'Photos'),
           _buildItem(null, 'When connected on Wi-Fi', 'All media'),
           _buildItem(null, 'When roaming', 'No media'),
        ],
      ),
    );
  }

  Widget _buildItem(IconData? icon, String title, String subtitle) {
    return ListTile(
      leading: icon != null ? Icon(icon, color: Colors.grey) : const SizedBox(width: 24),
      title: Text(title),
      subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
      onTap: () {},
    );
  }
}
