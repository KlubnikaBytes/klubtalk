import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:flutter/material.dart';
import 'package:whatsapp_clone/services/auth_service.dart';
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
      // 1. Fetch Groups (Parallel)
      final chatsFuture = _chatService.getMyChats();
      
      // 2. Fetch Device Contacts if permission granted
      List<Contact> deviceContacts = [];
      if (!kIsWeb) {
          final status = await _contactService.getPermissionStatus();
           if (status.isGranted) {
               deviceContacts = await _contactService.getDeviceContacts();
          }
      }

      // 3. Sync Contacts with Backend
      List<UserModel> registeredUsers = [];
      List<String> unregisteredPhones = [];

      try {
          if (deviceContacts.isNotEmpty) {
              final phones = deviceContacts
                  .expand((c) => c.phones.map((p) => p.number))
                  .toList();
              
              if (phones.isNotEmpty) {
                  final syncResult = await _contactService.syncContacts(phones);
                  
                  final List<dynamic> reg = syncResult['registered'];
                  registeredUsers = reg.map((u) => UserModel.fromMap(u, u['_id'])).toList();
                  
                  // Unregistered phones returned from backend (normalized)
                  final List<dynamic> unreg = syncResult['unregistered'];
                  unregisteredPhones = unreg.cast<String>();
              }
          }
      } catch (e) {
          print('Sync warning: $e');
      }

      final chats = await chatsFuture;
      final groups = chats.where((c) => c['isGroup'] == true).toList();

      if (mounted) {
        setState(() {
          _registeredUsers = registeredUsers;
          _myGroups = groups;
          // Filter device contacts to only those who are NOT registered
          // We can match by phone number to be precise, or just use the device list as source for invites
          // Ideally, we show "Invite" for anyone not in registeredUsers.
          // Let's store ALL device contacts, but mark them in the UI logic.
          _deviceContacts = deviceContacts; 
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

          // 3. Matched Contacts (Registered)
          final matchedContacts = <Map<String, dynamic>>[];
          final Set<String> matchedPhones = {};
          
          for (var user in _registeredUsers) {
              if (user.uid == AuthService().currentUserId) continue;
              
              // Find local contact name if possible
              String displayName = user.name.isNotEmpty ? user.name : user.phoneNumber;
              
              // Try to find in device contacts to get real name
              try {
                  final contact = _deviceContacts.firstWhere((c) => 
                      c.phones.any((p) => _contactService.normalizePhoneNumber(p.number) == user.phoneNumber)
                  );
                  displayName = contact.displayName;
              } catch (_) {}

              // Create app contact for consistent UI object
              final appContact = app_contact.Contact(
                  name: displayName,
                  profileImage: user.profilePhotoUrl,
                  isOnline: user.isOnline
              );
              
              matchedContacts.add({
                  'contact': app_contact.Contact(name: displayName, profileImage: user.profilePhotoUrl), // For list display mainly
                  'user': user,
                  'contactObject': appContact
              });
              matchedPhones.add(user.phoneNumber);
          }

          // 4. Invite Contacts (Unregistered)
          final inviteContacts = <Contact>[];
          for (var contact in _deviceContacts) {
              // Check if any of this contact's phones are registered
              bool isRegistered = contact.phones.any((p) => 
                  matchedPhones.contains(_contactService.normalizePhoneNumber(p.number))
              );
              
              if (!isRegistered && contact.phones.isNotEmpty) {
                  inviteContacts.add(contact);
              }
          }

           if (matchedContacts.isNotEmpty) {
             listItems.add(const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('Contacts on WhatsApp', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
             ));
             
             for (var item in matchedContacts) {
                 final app_contact.Contact c = item['contact'];
                 final UserModel u = item['user'];
                 final String selectionKey = "user:${u.uid}";
                 final bool isSelected = _selectedIds.contains(selectionKey);

                 // Adapt to App Contact model
                 final appContact = app_contact.Contact(
                     name: c.name,
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
                    title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(u.about, maxLines: 1, overflow: TextOverflow.ellipsis),
                     trailing: widget.isMultiSelect ? Checkbox(
                           value: isSelected,
                           onChanged: (v) => _onContactSelected(selectionItem)
                    ) : null,
                    onTap: () => _onContactSelected(selectionItem),
                 ));
             }
           }

          // 4. Unmatched Registered Users - REMOVED
          // WhatsApp only shows contacts in your phone book.
          // If you want to chat with someone not in contacts, you usually add them first.
          // Code block for "All Registered Users" removed per requirements.

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
     final currentUserId = AuthService().currentUserId;
     final otherUsers = users.where((u) => u.uid != currentUserId).toList();
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
      leading: CircleAvatar(backgroundColor: const Color(0xFFC92136), radius: 22, child: Icon(icon, color: Colors.white)),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
