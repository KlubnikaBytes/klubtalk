import 'package:flutter/material.dart';
import 'package:whatsapp_clone/models/user_model.dart';
import 'package:whatsapp_clone/services/user_service.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userService = UserService();

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      body: StreamBuilder<UserModel>(
        stream: userService.currentUserStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final user = snapshot.data!;

          return ListView(
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Who can see my personal info', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ),
              _buildVisibilityOption(
                context, 
                'Last seen and online', 
                _getVisibilityText(user.lastSeenVisibility),
                (val) => userService.updatePrivacySettings(lastSeenVisibility: val),
              ),
               _buildVisibilityOption(
                context, 
                'Profile photo', 
                _getVisibilityText(user.profilePhotoVisibility),
                (val) => userService.updatePrivacySettings(profilePhotoVisibility: val),
              ),
               _buildVisibilityOption(
                context, 
                'About', 
                _getVisibilityText(user.aboutVisibility),
                (val) => userService.updatePrivacySettings(aboutVisibility: val),
              ),
              
              const Divider(),
              
              SwitchListTile(
                activeColor: const Color(0xFF9575CD),
                title: const Text('Read receipts'),
                subtitle: const Text('If turned off, you won\'t send or receive read receipts. Read receipts are always sent for group chats.'),
                value: user.readReceipts,
                onChanged: (val) => userService.updatePrivacySettings(readReceipts: val),
              ),

              const Divider(),
              
              const ListTile(
                title: Text('Disappearing messages'),
                subtitle: Text('Default message timer: Off'),
                trailing: Text('Off', style: TextStyle(color: Colors.grey)),
              ),
              
              const Divider(),

              const ListTile(
                title: Text('Groups'),
                subtitle: Text('Everyone'),
              ),
              const ListTile(
                title: Text('Live location'),
                subtitle: Text('None'),
              ),
              ListTile(
                title: const Text('Blocked contacts'),
                subtitle: Text('${user.blockedUsers.length}'),
              ),
              const ListTile(
                 title: Text('Fingerprint lock'),
                 subtitle: Text('Disabled'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _getVisibilityText(int value) {
    switch (value) {
      case 0: return 'Everyone';
      case 1: return 'My contacts';
      case 2: return 'Nobody';
      default: return 'Everyone';
    }
  }

  Widget _buildVisibilityOption(BuildContext context, String title, String value, Function(int) onSelect) {
    return ListTile(
      title: Text(title),
      subtitle: Text(value),
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => SimpleDialog(
            title: Text(title),
            children: [
              SimpleDialogOption(child: const Text('Everyone'), onPressed: () { onSelect(0); Navigator.pop(context); }),
              SimpleDialogOption(child: const Text('My contacts'), onPressed: () { onSelect(1); Navigator.pop(context); }),
              SimpleDialogOption(child: const Text('Nobody'), onPressed: () { onSelect(2); Navigator.pop(context); }),
            ],
          ),
        );
      },
    );
  }
}
