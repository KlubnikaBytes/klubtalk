import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help')),
      body: ListView(
        children: [
          _buildItem(Icons.help_outline, 'Help Center'),
          _buildItem(Icons.people_outline, 'Contact us', 'Questions? Need help?'),
          _buildItem(Icons.description_outlined, 'Terms and Privacy Policy'),
          _buildItem(Icons.info_outline, 'App info'),
        ],
      ),
    );
  }

  Widget _buildItem(IconData icon, String title, [String? subtitle]) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      onTap: () {},
    );
  }
}
