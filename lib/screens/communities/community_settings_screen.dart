import 'package:flutter/material.dart';
import 'package:whatsapp_clone/models/community_model.dart';
import 'package:whatsapp_clone/models/group_model.dart';
import 'package:whatsapp_clone/services/community_service.dart';
import 'package:whatsapp_clone/services/chat_service.dart';
import 'package:whatsapp_clone/services/auth_service.dart';

class CommunitySettingsScreen extends StatefulWidget {
  final CommunityModel community;
  const CommunitySettingsScreen({super.key, required this.community});

  @override
  State<CommunitySettingsScreen> createState() => _CommunitySettingsScreenState();
}

class _CommunitySettingsScreenState extends State<CommunitySettingsScreen> {
  late CommunityModel _community;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _community = widget.community;
  }

  Future<void> _addGroups() async {
    // Show dialog or screen to select groups
    // Simplified: Show multi-select dialog of my admin groups NOT in community
    final chatService = ChatService();
    // Assuming we can get all chats and filter
    // This logic duplicates CreateCommunityScreen. Ideally refactor to reusable widget.
    // For now inline for speed.
    
    // ... Fetch groups ...
    // ... Show Dialog ...
    // ... Call service ...
    
    // Stub implementation:
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Add Group UI implementation pending reuse")));
  }

  @override
  Widget build(BuildContext context) {
    final isCreator = _community.createdBy == AuthService().currentUserId;
    final isAdmin = _community.isAdmin(AuthService().currentUserId!);

    return Scaffold(
      appBar: AppBar(title: const Text("Community Settings")),
      body: SingleChildScrollView(
        child: Column(
          children: [
             _buildHeader(),
             const Divider(),
             if (isAdmin)
               ListTile(
                 leading: const Icon(Icons.add_circle, color: Colors.green),
                 title: const Text("Add Group"),
                 onTap: _addGroups,
               ),
             _buildGroupsList(isAdmin),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage: _community.photo.isNotEmpty 
              ? NetworkImage(_community.photo) 
              : null,
            child: _community.photo.isEmpty ? const Icon(Icons.groups, size: 50) : null,
          ),
          const SizedBox(height: 16),
          Text(_community.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(_community.description, style: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildGroupsList(bool isAdmin) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _community.groups?.length ?? 0,
      itemBuilder: (context, index) {
        final group = _community.groups![index];
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: group.avatar.isNotEmpty ? NetworkImage(group.avatar) : null,
          ),
          title: Text(group.name),
          trailing: isAdmin 
            ? IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                onPressed: () {
                   // Remove group logic
                },
              )
            : null,
        );
      },
    );
  }
}
