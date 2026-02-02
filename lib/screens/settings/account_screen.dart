import 'package:flutter/material.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        children: [
          _buildItem(Icons.security, 'Security notifications'),
          _buildItem(Icons.lock_outline, 'Passkeys'),
          _buildItem(Icons.mail_outline, 'Email address'),
          _buildItem(Icons.verified_user_outlined, 'Two-step verification'),
          _buildItem(Icons.phone_iphone, 'Change number'),
          _buildItem(Icons.file_download_outlined, 'Request account info'),
          _buildItem(Icons.delete_outline, 'Delete account'),
        ],
      ),
    );
  }

  Widget _buildItem(IconData icon, String title) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey),
      title: Text(title),
      onTap: () {
        // TODO: Implement specific actions
      },
    );
  }
}
