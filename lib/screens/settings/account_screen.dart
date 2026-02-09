import 'package:flutter/material.dart';
import 'package:whatsapp_clone/screens/settings/security_notifications_screen.dart';
import 'package:whatsapp_clone/screens/settings/email_screen.dart';
import 'package:whatsapp_clone/screens/settings/two_step_verification_screen.dart';
import 'package:whatsapp_clone/screens/settings/change_number_screen.dart';
import 'package:whatsapp_clone/screens/settings/request_account_info_screen.dart';
import 'package:whatsapp_clone/screens/settings/delete_account_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        children: [
          _buildItem(context, Icons.security, 'Security notifications'),
          _buildItem(context, Icons.lock_outline, 'Passkeys'),
          _buildItem(context, Icons.mail_outline, 'Email address'),
          _buildItem(context, Icons.verified_user_outlined, 'Two-step verification'),
          _buildItem(context, Icons.phone_iphone, 'Change number'),
          _buildItem(context, Icons.file_download_outlined, 'Request account info'),
          _buildItem(context, Icons.delete_outline, 'Delete account'),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, IconData icon, String title) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey),
      title: Text(title),
      onTap: () {
        Widget? screen;
        switch (title) {
          case 'Security notifications':
            screen = const SecurityNotificationsScreen();
            break;
          case 'Email address':
            screen = const EmailScreen();
            break;
          case 'Two-step verification':
            screen = const TwoStepVerificationScreen();
            break;
          case 'Change number':
             screen = const ChangeNumberScreen();
             break;
          case 'Request account info':
             screen = const RequestAccountInfoScreen();
             break;
          case 'Delete account':
             screen = const DeleteAccountScreen();
             break;
          case 'Passkeys':
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passkeys coming soon')));
             break;
          case 'Add account':
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Multi-account support coming soon')));
              break;
        }

        if (screen != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => screen!),
          );
        }
      },
    );
  }
}
