import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:whatsapp_clone/models/user_model.dart';
import 'package:whatsapp_clone/models/contact.dart' as app_contact;
import 'package:whatsapp_clone/screens/chat_screen.dart';
import 'package:whatsapp_clone/services/chat_service.dart';
import 'package:whatsapp_clone/services/contact_service.dart';
import 'package:whatsapp_clone/widgets/avatar_widget.dart';

import 'package:whatsapp_clone/screens/add_contact_screen.dart';
import 'package:whatsapp_clone/screens/group_participant_select_screen.dart';

class NewChatScreen extends StatefulWidget {
  final bool isSelectionMode;
  final bool isMultiSelect; // New Flag

  const NewChatScreen({
    super.key, 
    this.isSelectionMode = false, 
    this.isMultiSelect = false
  });

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> with WidgetsBindingObserver {
  final ContactService _contactService = ContactService();
  final ChatService _chatService = ChatService();
  
  PermissionStatus _permissionStatus = PermissionStatus.denied;
  List<UserModel> _registeredUsers = [];
  bool _isLoading = true;

  // App groups created inside app
  List<Map<String, dynamic>> _myGroups = [];

  // Phone contacts
  List<Contact> _deviceContacts = [];

  // Multi-select support (for camera send / media send)
  final Set<String> _selectedIds = {};
  final List<Map<String, dynamic>> _selectedItems = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!kIsWeb) {
       _contactService.getPermissionStatus().then((s) { 
           if (mounted) setState(() => _permissionStatus = s);
           _fetchContacts();
       });
    } else {
       _fetchContacts();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !kIsWeb) {
       _contactService.getPermissionStatus().then((s) { 
           if (mounted) setState(() => _permissionStatus = s);
           if (s.isGranted) _fetchContacts();
       });
    }
  }


  Future<void> _requestPermission() async {
    final status = await _contactService.requestPermission();
    if (mounted) setState(() => _permissionStatus = status);
    if (status.isGranted) {
      _fetchContacts();
    } else if (status.isPermanentlyDenied) {
      openAppSettings();
    }
  }

  Future<void> _fetchContacts() async {
    setState(() => _isLoading = true);
    
    try {
      // 1. Fetch Registered Users (Parallel)
      final usersFuture = _contactService.getRegisteredUsers();
      
      // 2. Fetch Groups (Parallel)
      final chatsFuture = _chatService.getMyChats();
      
      // 3. Fetch Device Contacts (Parallel)
      // Only fetch if permission granted (check again to be safe/consistent)
      Future<List<Contact>> contactsFuture;
      if (!kIsWeb) {
          final status = await _contactService.getPermissionStatus();
           if (status.isGranted) {
               contactsFuture = _contactService.getDeviceContacts();
          } else {
               contactsFuture = Future.value(<Contact>[]);
          }
      } else {
          contactsFuture = Future.value(<Contact>[]);
      }

      final results = await Future.wait([usersFuture, chatsFuture, contactsFuture]);
      
      final users = results[0] as List<UserModel>;
      final chats = results[1] as List<Map<String, dynamic>>;
      final contacts = results[2] as List<Contact>; // Cast to flutter_contacts.Contact
      final groups = chats.where((c) => c['isGroup'] == true).toList();

      if (mounted) {
        setState(() {
          _registeredUsers = users;
          _myGroups = groups;
          _deviceContacts = contacts;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onContactSelected(Map<String, dynamic> item) async {
       final String type = item['type']; // 'user' or 'group'
       final String id = item['id'];
       final String selectionKey = "$type:$id";

       if (widget.isMultiSelect) {
           setState(() {
               if (_selectedIds.contains(selectionKey)) {
                   _selectedIds.remove(selectionKey);
                   _selectedItems.removeWhere((i) => "${i['type']}:${i['id']}" == selectionKey);
               } else {
                   _selectedIds.add(selectionKey);
                   _selectedItems.add(item);
               }
           });
           return;
       }

       // Single Selection Mode
        String chatId;
        UserModel? user;
        String? peerId;
        app_contact.Contact? contactObj;
        
        if (type == 'group') {
            chatId = id; // Group Chat ID
            // For groups, we don't have a single "contact" object navigation style usually, 
            // but ChatScreen supports group chats if we pass correct params.
            // existing ChatScreen params: contact, peerId, chatId.
            // If group, peerId might be empty or group ID. 
            // Let's check ChatScreen. It usually uses chatId to load messages.
            // peerId is used for 1-1 specifics.
            peerId = '';
        } else {
            user = item['userObject'];
            chatId = item['chatId'] ?? await _chatService.createOrGetChat(user!.uid);
            peerId = user!.uid;
            contactObj = item['contactObject'];
            
            if (contactObj == null && user != null) {
                 // Create dummy contact from user
                 contactObj = app_contact.Contact(
                    name: user.name.isEmpty ? user.phoneNumber : user.name,
                    profileImage: user.profilePhotoUrl,
                    isOnline: user.isOnline 
                 );
            }
        }
        
        final result = {
            'contact': contactObj,
            'peerId': peerId,
            'chatId': chatId,
            'user': user,
            'isGroup': type == 'group'
        };

        if (widget.isSelectionMode) {
            Navigator.pop(context, [result]); // Return List even for single select to be consistent if caller handles list
        } else {
             if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    contact: contactObj, // Might be null for group, ChatScreen handles?
                    peerId: peerId!, // Empty string for group
                    chatId: chatId,
                    isGroup: type == 'group',
                    groupName: item['name'], // Pass group name if needed
                    groupPhoto: item['photo'],
                  ),
                ),
              );
             }
        }
  }
  
  Map<String, dynamic> _normalizeSelection(Map<String, dynamic> item) {
       final String type = item['type'];
       // If already normalized (e.g. from matched contacts which had contactObject), use it.
       // But we need to be uniform.
       
       String chatId = item['chatId'] ?? ''; // Might be empty
       UserModel? user = item['userObject'];
       String peerId = user?.uid ?? '';
       app_contact.Contact? contactObj = item['contactObject'];
       
       if (type == 'group') {
            chatId = item['id']; // Group ID is chatId
            peerId = '';
            // No contact object for group
       } else {
            // User
            if (contactObj == null && user != null) {
                 contactObj = app_contact.Contact(
                    name: user.name.isEmpty ? user.phoneNumber : user.name,
                    profileImage: user.profilePhotoUrl,
                    isOnline: user.isOnline 
                 );
            }
       }
       
       return {
            'contact': contactObj,
            'peerId': peerId,
            'chatId': chatId,
            'user': user,
            'isGroup': type == 'group',
            'name': item['name'], // for group
            'photo': item['photo'] // for group
       };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                widget.isMultiSelect 
                  ? '${_selectedIds.length} selected'
                  : 'Select contact', 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
            ),
            if (!kIsWeb && _permissionStatus.isGranted && !widget.isMultiSelect)
              Text('${_deviceContacts.length} contacts', style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          if (!widget.isMultiSelect)
             IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      floatingActionButton: (widget.isMultiSelect && _selectedIds.isNotEmpty) 
        ? FloatingActionButton(
            backgroundColor: const Color(0xFF075E54),
            child: const Icon(Icons.check, color: Colors.white),
            onPressed: () {
                 // Normalize items before returning
                 final List<Map<String, dynamic>> normalizedItems = _selectedItems.map((item) {
                     return _normalizeSelection(item);
                 }).toList();
                 Navigator.pop(context, normalizedItems);
            },
          )
        : null,
      body: FutureBuilder<List<UserModel>>(
        future: _contactService.getRegisteredUsers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
             return const Center(child: CircularProgressIndicator());
          }
          final registeredUsers = snapshot.data ?? [];

          // WEB FALLBACK
          if (kIsWeb) {
            return _buildWebList(registeredUsers);
          }

          // MOBILE: Permission Check
          if (!_permissionStatus.isGranted) {
             return _buildPermissionRequestUI();
          }

          final List<Widget> listItems = [];

          // 1. Static Options (Only in Single Select Mode)
          if (!widget.isMultiSelect) {
            listItems.add(_buildFixedOption(
                Icons.group, 'New group',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const GroupParticipantSelectScreen()))
            ));
            listItems.add(_buildFixedOption(
                Icons.person_add, 'New contact', 
                trailing: const Icon(Icons.qr_code),
                onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (context) => const AddContactScreen()));
                    setState(() {}); 
                    _fetchContacts(); 
                }
            ));
            listItems.add(_buildFixedOption(Icons.groups, 'New community'));
          }

          // 2. GROUPS Section (Crucial for Sharing)
          if (_myGroups.isNotEmpty) {
               listItems.add(const Padding(
                 padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                 child: Text('Groups', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
               ));
               
               for (var group in _myGroups) {
                   final String id = group['chatId'] ?? group['_id'] ?? '';
                   if (id.isEmpty) continue; // Skip invalid groups
                   final String selectionKey = "group:$id";
                   final bool isSelected = _selectedIds.contains(selectionKey);
                   
                   listItems.add(ListTile(
                       leading: Stack(
                         children: [
                           AvatarWidget(imageUrl: group['groupPhoto'] ?? '', radius: 22),
                           if (isSelected) 
                              const Positioned(
                                bottom: 0, right: 0, 
                                child: CircleAvatar(radius: 10, backgroundColor: Colors.teal, child: Icon(Icons.check, size: 12, color: Colors.white))
                              )
                         ]
                       ),
                       title: Text(group['groupName'] ?? 'Unknown Group', style: const TextStyle(fontWeight: FontWeight.bold)),
                       trailing: widget.isMultiSelect ? Checkbox(
                           value: isSelected,
                           onChanged: (v) => _onContactSelected({'type': 'group', 'id': id, 'name': group['groupName'] ?? 'Group', 'photo': group['groupPhoto'] ?? ''})
                       ) : null,
                       onTap: () => _onContactSelected({'type': 'group', 'id': id, 'name': group['groupName'] ?? 'Group', 'photo': group['groupPhoto'] ?? ''}),
                   ));
               }
          }

          // 3. Matched Contacts
          final matchedContacts = <Map<String, dynamic>>[];
          final inviteContacts = <Contact>[];
          
          for (var contact in _deviceContacts) {
             if (contact.phones.isEmpty) continue;
             String phone = _contactService.normalizePhoneNumber(contact.phones.first.number);
             UserModel? matchedUser;
             try {
                matchedUser = registeredUsers.firstWhere(
                  (u) => _contactService.normalizePhoneNumber(u.phoneNumber).contains(phone) || phone.contains(_contactService.normalizePhoneNumber(u.phoneNumber)),
                );
             } catch (e) { matchedUser = null; }
             
             if (matchedUser != null && matchedUser.uid != _chatService.auth.currentUser?.uid) {
                matchedContacts.add({'contact': contact, 'user': matchedUser});
             } else {
                inviteContacts.add(contact);
             }
          }

           if (matchedContacts.isNotEmpty) {
             listItems.add(const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('Contacts on WhatsApp', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
             ));
             
             for (var item in matchedContacts) {
                 final Contact c = item['contact'];
                 final UserModel u = item['user'];
                 final String selectionKey = "user:${u.uid}";
                 final bool isSelected = _selectedIds.contains(selectionKey);

                 // Adapt to App Contact model
                 final appContact = app_contact.Contact(
                     name: c.displayName,
                     profileImage: u.profilePhotoUrl,
                     isOnline: u.isOnline
                 );
                 final selectionItem = {'type': 'user', 'id': u.uid, 'userObject': u, 'contactObject': appContact};

                 listItems.add(ListTile(
                    leading: Stack(
                         children: [
                           AvatarWidget(imageUrl: u.profilePhotoUrl, radius: 22),
                           if (isSelected) 
                              const Positioned(
                                bottom: 0, right: 0, 
                                child: CircleAvatar(radius: 10, backgroundColor: Colors.teal, child: Icon(Icons.check, size: 12, color: Colors.white))
                              )
                         ]
                    ),
                    title: Text(c.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(u.about, maxLines: 1, overflow: TextOverflow.ellipsis),
                     trailing: widget.isMultiSelect ? Checkbox(
                           value: isSelected,
                           onChanged: (v) => _onContactSelected(selectionItem)
                    ) : null,
                    onTap: () => _onContactSelected(selectionItem),
                 ));
             }
           }

          // 4. All Registered Users (Unmatched)
          // Ensure we don't duplicate
          final matchedIds = matchedContacts.map((m) => (m['user'] as UserModel).uid).toSet();
          final unmatchedUsers = registeredUsers.where((u) => !matchedIds.contains(u.uid) && u.uid != _chatService.auth.currentUser?.uid).toList();

          if (unmatchedUsers.isNotEmpty) {
            listItems.add(const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('All Registered Users', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ));

            for (var u in unmatchedUsers) {
               final String selectionKey = "user:${u.uid}";
               final bool isSelected = _selectedIds.contains(selectionKey);

               listItems.add(ListTile(
                leading: Stack(
                         children: [
                           AvatarWidget(imageUrl: u.profilePhotoUrl, radius: 22),
                           if (isSelected) 
                              const Positioned(
                                bottom: 0, right: 0, 
                                child: CircleAvatar(radius: 10, backgroundColor: Colors.teal, child: Icon(Icons.check, size: 12, color: Colors.white))
                              )
                         ]
                ),
                title: Text(u.name.isEmpty ? u.phoneNumber : u.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(u.about, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: widget.isMultiSelect ? Checkbox(
                           value: isSelected,
                           onChanged: (v) => _onContactSelected({'type': 'user', 'id': u.uid, 'userObject': u})
                ) : null,
                onTap: () => _onContactSelected({'type': 'user', 'id': u.uid, 'userObject': u}),
              ));
            }
          }

          // 5. Invite Section
           if (inviteContacts.isNotEmpty) {
              listItems.add(const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('Invite to WhatsApp', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ));
              for (var c in inviteContacts) {
                 listItems.add(ListTile(
                  leading: const CircleAvatar(backgroundColor: Colors.grey, radius: 22, child: Icon(Icons.person, color: Colors.white)),
                  title: Text(c.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: const Text('Invite', style: TextStyle(color: Color(0xFF075E54), fontWeight: FontWeight.bold)),
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invite sent! (Simulated)'))),
                ));
              }
           }

          return ListView(children: listItems);
        },
      ),
    );
  }

  Widget _buildWebList(List<UserModel> users) {
     final currentUser = _chatService.auth.currentUser;
     final otherUsers = users.where((u) => u.uid != currentUser?.uid).toList();
     // Web Implementation of Multi-Select omitted for brevity unless requested, focusing on mobile as per context.
     // But logic should be similar.
     return ListView(
       children: otherUsers.map((u) => ListTile(
            leading: AvatarWidget(imageUrl: u.profilePhotoUrl, radius: 22),
            title: Text(u.name.isEmpty ? u.phoneNumber : u.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            onTap: () => _onContactSelected({'type': 'user', 'id': u.uid, 'userObject': u}),
       )).toList()
     );
  }

  Widget _buildPermissionRequestUI() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            const Icon(Icons.contacts, size: 80, color: Color(0xFF075E54)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _requestPermission,
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFixedOption(IconData icon, String label, {Widget? trailing, VoidCallback? onTap}) {
    return ListTile(
      leading: CircleAvatar(backgroundColor: const Color(0xFF9575CD), radius: 22, child: Icon(icon, color: Colors.white)),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
extension on ChatService {
  get auth => FirebaseAuth.instance;
}
