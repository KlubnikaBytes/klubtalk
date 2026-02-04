import 'package:flutter/material.dart';
import 'package:whatsapp_clone/models/user_model.dart';
import 'package:whatsapp_clone/screens/settings/privacy_screen.dart';
import 'package:whatsapp_clone/screens/settings/profile_edit_screen.dart';
import 'package:whatsapp_clone/screens/settings/notification_settings_screen.dart';
import 'package:whatsapp_clone/screens/settings/account_screen.dart';
import 'package:whatsapp_clone/screens/settings/chats_settings_screen.dart';
import 'package:whatsapp_clone/screens/settings/storage_data_screen.dart';
import 'package:whatsapp_clone/screens/settings/help_screen.dart';
import 'package:whatsapp_clone/screens/settings/avatar_screen.dart';
import 'package:whatsapp_clone/services/user_service.dart';
import 'package:whatsapp_clone/widgets/avatar_widget.dart';
import 'package:whatsapp_clone/widgets/responsive_container.dart';

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
                trailing: const Icon(Icons.qr_code, color: Color(0xFFC92136)),
                onTap: () {
                  if (user != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => Scaffold(
                        backgroundColor: const Color(0xFFF0F2F5),
                        body: ResponsiveContainer(child: const ProfileEditScreen())
                      )),
                    );
                  }
                },
              );
            },
          ),
          const Divider(),

          // Settings Options
          _buildSettingItem(context, Icons.key, 'Account', 'Security notifications, change number', const AccountScreen()),
          _buildSettingItem(context, Icons.lock, 'Privacy', 'Block contacts, disappearing messages', const PrivacyScreen()),
          _buildSettingItem(context, Icons.face, 'Avatar', 'Create, edit, profile photo', const AvatarScreen()),
          _buildItem(context, Icons.chat, 'Chats', 'Theme, wallpapers, chat history', const ChatsSettingsScreen()),
          _buildSettingItem(context, Icons.notifications, 'Notifications', 'Message, group & call tones', const NotificationSettingsScreen()),
          _buildSettingItem(context, Icons.sd_storage, 'Storage and data', 'Network usage, auto-download', const StorageDataScreen()),
          _buildSettingItem(context, Icons.language, 'App language', 'English (device\'s language)', null),
          _buildSettingItem(context, Icons.help_outline, 'Help', 'Help center, contact us, privacy policy', const HelpScreen()),
          _buildFriendInvite(context),
          
          const SizedBox(height: 20),
          const Center(
            child: Column(
              children: [
                Text('from', style: TextStyle(color: Colors.grey, fontSize: 12)),
                Text('Klubnika Bytes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black)),
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
          Navigator.push(context, MaterialPageRoute(builder: (context) => Scaffold(
             backgroundColor: const Color(0xFFF0F2F5),
             body: ResponsiveContainer(child: destination)
          )));
        } else {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$title feature coming soon")));
        }
      },
    );
  }
  
  // Method to handle type mismatch in replacing _buildSettingItem for Chats above (I used _buildItem but method is _buildSettingItem)
  // Let's just reuse _buildSettingItem.
  Widget _buildItem(BuildContext context, IconData icon, String title, String subtitle, Widget? destination) {
      return _buildSettingItem(context, icon, title, subtitle, destination);
  }

  Widget _buildFriendInvite(BuildContext context) {
      return ListTile(
          leading: Icon(Icons.group_add, color: Colors.grey[700]),
          title: const Text("Invite a friend"),
          onTap: () {
             // Share logic stub
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invite friend clicked")));
          },
      );
  }
}
