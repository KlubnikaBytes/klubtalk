import 'package:flutter/material.dart';
import 'package:whatsapp_clone/services/auth_service.dart';
import 'package:whatsapp_clone/models/user_model.dart';
import 'package:whatsapp_clone/screens/group_info_screen.dart';
import 'package:whatsapp_clone/services/contact_service.dart';
import 'package:whatsapp_clone/services/chat_service.dart'; // For Groups
import 'package:whatsapp_clone/widgets/avatar_widget.dart';

class GroupParticipantSelectScreen extends StatefulWidget {
  final bool isCommunity;
  const GroupParticipantSelectScreen({super.key, this.isCommunity = false});

  @override
  State<GroupParticipantSelectScreen> createState() => _GroupParticipantSelectScreenState();
}

class _GroupParticipantSelectScreenState extends State<GroupParticipantSelectScreen> {
  final ContactService _contactService = ContactService();
  final ChatService _chatService = ChatService(); // For Groups
  
  List<UserModel> _contacts = [];
  bool _isLoading = true;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _fetchContacts();
  }

  Future<void> _fetchContacts() async {
    try {
      List<UserModel> items = [];
      final currentUid = AuthService().currentUserId;

      if (widget.isCommunity) {
         // Fetch Groups
         final chats = await _chatService.getMyChats();
         // Filter for groups only
         items = chats.where((c) => c['isGroup'] == true).map((c) {
             return UserModel(
               uid: c['_id'] ?? c['id'],
               name: c['groupName'] ?? 'Unknown Group',
               phoneNumber: '',
               isOnline: false,
               profilePhotoUrl: c['groupPhoto'] ?? '',
               about: '${(c['participants'] as List?)?.length ?? 0} members'
             );
         }).toList();
      } else {
         // Fetch Contacts
         final users = await _contactService.getRegisteredUsers();
         items = users.where((u) => u.uid != currentUid).toList();
      }
      
      if (mounted) {
        setState(() {
          _contacts = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      print("Error loading items: $e");
    }
  }

  void _toggleSelection(String uid) {
    setState(() {
      if (_selectedIds.contains(uid)) {
        _selectedIds.remove(uid);
      } else {
        _selectedIds.add(uid);
      }
    });
  }

  void _goToGroupInfo() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupInfoScreen(
          selectedParticipantIds: _selectedIds.toList(),
          isCommunity: widget.isCommunity,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFC92136),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.isCommunity ? 'Add groups' : 'New Group', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text(widget.isCommunity ? 'Select groups to add' : '${_selectedIds.length} selected', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator()) 
          : Column(
        children: [
          // Selected Chips
          if (_selectedIds.isNotEmpty)
            SizedBox(
              height: 70,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                children: _selectedIds.map((id) {
                  final contact = _contacts.firstWhere((c) => c.uid == id, orElse: () => UserModel(uid: id, phoneNumber: '', name: 'Unknown', isOnline: false, lastSeen: null, profilePhotoUrl: '', about: ''));
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            AvatarWidget(imageUrl: contact.profilePhotoUrl, radius: 15),
                            Positioned(
                               bottom: 0, right: 0,
                               child: GestureDetector(
                                 onTap: () => _toggleSelection(id),
                                 child: const CircleAvatar(radius: 6, backgroundColor: Colors.grey, child: Icon(Icons.close, size: 8, color: Colors.white))
                               )
                            )
                          ], 
                        ),
                        const SizedBox(height: 2),
                        Text(contact.name.split(' ')[0], style: const TextStyle(fontSize: 10)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          
          Expanded(
            child: ListView.builder(
              itemCount: _contacts.length,
              itemBuilder: (context, index) {
                final contact = _contacts[index];
                final isSelected = _selectedIds.contains(contact.uid);
                
                return ListTile(
                  leading: Stack(
                    children: [
                      AvatarWidget(imageUrl: contact.profilePhotoUrl, radius: 22),
                      if (isSelected)
                        const Positioned(
                          bottom: 0,
                          right: 0,
                          child: CircleAvatar(
                            radius: 10,
                            backgroundColor: Color(0xFFC92136),
                            child: Icon(Icons.check, size: 12, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                  title: Text(contact.name.isEmpty ? contact.phoneNumber : contact.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(contact.about, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => _toggleSelection(contact.uid),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedIds.isNotEmpty
          ? FloatingActionButton(
              backgroundColor: const Color(0xFFC92136),
              onPressed: _goToGroupInfo,
              child: const Icon(Icons.arrow_forward, color: Colors.white),
            )
          : null,
    );
  }
}
