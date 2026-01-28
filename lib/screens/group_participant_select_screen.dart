import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:whatsapp_clone/services/auth_service.dart';
import 'package:whatsapp_clone/models/user_model.dart';
import 'package:whatsapp_clone/screens/group_info_screen.dart';
import 'package:whatsapp_clone/services/contact_service.dart';
import 'package:whatsapp_clone/services/chat_service.dart'; // For Groups
import 'package:whatsapp_clone/widgets/avatar_widget.dart';
import 'package:whatsapp_clone/models/contact.dart' as app_contact;

class GroupParticipantSelectScreen extends StatefulWidget {
  final bool isCommunity;
  final String? existingGroupId;
  final List<String> excludeIds;

  const GroupParticipantSelectScreen({
    super.key, 
    this.isCommunity = false,
    this.existingGroupId,
    this.excludeIds = const [],
  });

  @override
  State<GroupParticipantSelectScreen> createState() => _GroupParticipantSelectScreenState();
}

class _GroupParticipantSelectScreenState extends State<GroupParticipantSelectScreen> {
  final ContactService _contactService = ContactService();
  final ChatService _chatService = ChatService(); 
  
  List<app_contact.Contact> _displayContacts = [];
  Map<String, UserModel> _userMap = {}; // Map UID to UserModel
  
  bool _isLoading = true;
  final Set<String> _selectedIds = {}; // UIDs selected

  @override
  void initState() {
    super.initState();
    _fetchContacts();
  }

  Future<void> _fetchContacts() async {
    setState(() => _isLoading = true);
    try {
      if (widget.isCommunity) {
         // Fetch Groups
         final chats = await _chatService.getMyChats();
         final groups = chats.where((c) => c['isGroup'] == true).toList();
         
         final contacts = groups.map((c) {
             return app_contact.Contact(
               name: c['groupName'] ?? 'Unknown Group',
               profileImage: c['groupPhoto'] ?? '',
               isOnline: false,
             );
         }).toList();
         
         // Store mapping for selection
         for (var c in groups) {
             final id = c['_id'] ?? c['id'];
             _userMap[id] = UserModel(uid: id, name: c['groupName'], phoneNumber: '', isOnline: false);
         }

         if (mounted) setState(() {
             _displayContacts = contacts;
             _isLoading = false;
         });
         return;
      }

      // --- REGULAR GROUP: FETCH CONTACTS WITH SYNC ---
      
      // 1. Get Device Contacts (Mobile Only)
      List<dynamic> deviceContacts = [];
      if (!kIsWeb) {
          final status = await _contactService.requestPermission();
          if (status.isGranted) {
             deviceContacts = await _contactService.getDeviceContacts();
          }
      }

      // 2. Sync with Backend
      List<UserModel> registeredUsers = [];
      if (deviceContacts.isNotEmpty) {
           final phones = deviceContacts.expand((c) => (c.phones as List).map((p) => p.number.toString())).toList().cast<String>();
           if (phones.isNotEmpty) {
               try {
                   final syncResult = await _contactService.syncContacts(phones);
                   final List<dynamic> reg = syncResult['registered'];
                   registeredUsers = reg.map((u) => UserModel.fromMap(u, u['_id'])).toList();
               } catch (e) {
                   print('Sync failed, falling back to cached users: $e');
                   registeredUsers = await _contactService.getRegisteredUsers();
               }
           }
      } else {
           // Fallback if no device contacts or Web
           registeredUsers = await _contactService.getRegisteredUsers();
      }

      // 3. Match & Prepare Display List
      final currentUid = AuthService().currentUserId;
      final List<app_contact.Contact> finalContacts = [];
            for (var user in registeredUsers) {
           if (user.uid == currentUid) continue;
           if (widget.excludeIds.contains(user.uid)) continue;

          // Find display name from device contacts
          String displayName = user.name.isNotEmpty ? user.name : user.phoneNumber;
          try {
             if (deviceContacts.isNotEmpty) {
                 final match = deviceContacts.firstWhere((c) => 
                    (c.phones as List).any((p) => _contactService.normalizePhoneNumber(p.number) == user.phoneNumber)
                 );
                 displayName = match.displayName;
             }
          } catch (_) {}

          final contact = app_contact.Contact(
             name: displayName,
             profileImage: user.profilePhotoUrl,
             isOnline: user.isOnline,
          );
          
          finalContacts.add(contact);
          _userMap[user.uid] = user; // Store for valid IDs
      }
      
      if (mounted) {
        setState(() {
          _displayContacts = finalContacts;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading items: $e");
      if (mounted) setState(() => _isLoading = false);
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

  void _onNext() {
    if (widget.existingGroupId != null) {
       Navigator.pop(context, _selectedIds.toList());
       return;
    }

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
    // Filter contacts based on _userMap keys to ensure we match correct users
    // But _displayContacts relies on index matching if list is sorted same way. 
    // To be safe, let's zip them or just rely on the fact we built them sequentially.
    // Better: Store (UserModel, Contact) pairs.
    
    // Re-building logic on fly is okay for small lists.
    // Let's iterate through _userMap entries that match _displayContacts order if possible, 
    // OR just rebuild the list logic.
    
    // Simplification: _displayContacts and _userMap are not synced in order.
    // Let's iterate keys of _userMap.
    final List<UserModel> validUsers = _userMap.values.toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFC92136),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.existingGroupId != null 
                 ? 'Add Participants' 
                 : (widget.isCommunity ? 'Add groups' : 'New Group'), 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
            ),
            Text(widget.isCommunity ? 'Select groups to add' : '${_selectedIds.length} selected', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator()) 
          : validUsers.isEmpty 
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('No contacts found', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                      const SizedBox(height: 10),
                      TextButton(onPressed: _fetchContacts, child: const Text('Refresh'))
                    ],
                  )
                )
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
                  final user = _userMap[id];
                  if (user == null) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            AvatarWidget(imageUrl: user.profilePhotoUrl, radius: 15),
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
                        Text(user.name.split(' ')[0], style: const TextStyle(fontSize: 10)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          
          Expanded(
            child: ListView.builder(
              itemCount: validUsers.length,
              itemBuilder: (context, index) {
                final user = validUsers[index];
                final isSelected = _selectedIds.contains(user.uid);
                
                // Find display name again (or store it in user model temporary)
                // For now use user.name which we updated in _fetchContacts
                final displayName = user.name.isNotEmpty ? user.name : user.phoneNumber;
                final status = user.about;

                return ListTile(
                  leading: Stack(
                    children: [
                      AvatarWidget(imageUrl: user.profilePhotoUrl, radius: 22),
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
                  title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(status, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => _toggleSelection(user.uid),
                );
              },
            ),
          ),
        ],
      ),

      floatingActionButton: _selectedIds.isNotEmpty
          ? FloatingActionButton(
              backgroundColor: const Color(0xFFC92136),
              onPressed: _onNext,
              child: Icon(widget.existingGroupId != null ? Icons.check : Icons.arrow_forward, color: Colors.white),
            )
          : null,
    );
  }
}
