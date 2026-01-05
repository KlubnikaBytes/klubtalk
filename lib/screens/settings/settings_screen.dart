import 'package:flutter/material.dart';
import 'package:whatsapp_clone/models/user_model.dart';
import 'package:whatsapp_clone/screens/settings/privacy_screen.dart';
import 'package:whatsapp_clone/screens/settings/profile_edit_screen.dart';
import 'package:whatsapp_clone/services/user_service.dart';
import 'package:whatsapp_clone/widgets/avatar_widget.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userService = UserService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        children: [
          // Profile Header
          StreamBuilder<UserModel>(
            stream: userService.currentUserStream,
            builder: (context, snapshot) {
              final user = snapshot.data;
              final name = user?.name ?? 'Processing...';
              final about = user?.about ?? '...';
              final image = user?.profilePhotoUrl;

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Hero(
                  tag: 'profile_pic',
                  child: AvatarWidget(imageUrl: image ?? '', radius: 30),
                ),
                title: Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.normal)),
                subtitle: Text(about, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.qr_code, color: Color(0xFF9575CD)),
                onTap: () {
                  if (user != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ProfileEditScreen()),
                    );
                  }
                },
              );
            },
          ),
          const Divider(),

          // Settings Options
          _buildSettingItem(context, Icons.key, 'Account', 'Security notifications, change number', null),
          _buildSettingItem(context, Icons.lock, 'Privacy', 'Block contacts, disappearing messages', const PrivacyScreen()),
          _buildSettingItem(context, Icons.face, 'Avatar', 'Create, edit, profile photo', null),
          _buildSettingItem(context, Icons.chat, 'Chats', 'Theme, wallpapers, chat history', null),
          _buildSettingItem(context, Icons.notifications, 'Notifications', 'Message, group & call tones', null),
          _buildSettingItem(context, Icons.sd_storage, 'Storage and data', 'Network usage, auto-download', null),
          _buildSettingItem(context, Icons.language, 'App language', 'English (device\'s language)', null),
          _buildSettingItem(context, Icons.help_outline, 'Help', 'Help center, contact us, privacy policy', null),
          _buildSettingItem(context, Icons.group_add, 'Invite a friend', '', null),
          
          const SizedBox(height: 20),
          const Center(
            child: Column(
              children: [
                Text('from', style: TextStyle(color: Colors.grey, fontSize: 12)),
                Text('Meta', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black)),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSettingItem(BuildContext context, IconData icon, String title, String subtitle, Widget? destination) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey[700]),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.normal)),
      subtitle: subtitle.isNotEmpty ? Text(subtitle, style: const TextStyle(color: Colors.grey)) : null,
      onTap: () {
        if (destination != null) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => destination));
        }
      },
    );
  }
}
