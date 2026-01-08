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
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> with WidgetsBindingObserver {
  final ContactService _contactService = ContactService();
  final ChatService _chatService = ChatService();
  
  PermissionStatus _permissionStatus = PermissionStatus.denied;
  List<Contact> _deviceContacts = [];
  bool _isLoadingContacts = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!kIsWeb) {
      _checkPermissionAndFetch();
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
      _checkPermissionAndFetch();
    }
  }

  Future<void> _checkPermissionAndFetch() async {
    final status = await _contactService.getPermissionStatus();
    if (mounted) {
      setState(() => _permissionStatus = status);
    }
    
    if (status.isGranted) {
      _fetchContacts();
    }
  }

  Future<void> _requestPermission() async {
    final status = await _contactService.requestPermission();
    if (mounted) {
      setState(() => _permissionStatus = status);
    }
    if (status.isGranted) {
      _fetchContacts();
    } else if (status.isPermanentlyDenied) {
      openAppSettings();
    }
  }

  Future<void> _fetchContacts() async {
    if (_isLoadingContacts) return;
    setState(() => _isLoadingContacts = true);
    
    try {
      final contacts = await _contactService.getDeviceContacts();
      if (mounted) {
        setState(() {
          _deviceContacts = contacts;
          _isLoadingContacts = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingContacts = false);
      print('Error fetching contacts: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select contact', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            if (!kIsWeb && _permissionStatus.isGranted)
              Text('${_deviceContacts.length} contacts', style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: FutureBuilder<List<UserModel>>(
        future: _contactService.getRegisteredUsers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // Show loading IF we are also waiting for permissions/contacts
             // Or just let it load in background. We need partial connection state handling.
             // But we can just show empty or progress.
             // If we return spinner, it blocks UI. Maybe linear progress?
             return const Center(child: CircularProgressIndicator());
          }
          final registeredUsers = snapshot.data ?? [];

          // WEB FALLBACK: Just show registered users
          if (kIsWeb) {
            return _buildWebList(registeredUsers);
          }

          // MOBILE: Permission Denied State
          if (!_permissionStatus.isGranted) {
             return _buildPermissionRequestUI();
          }

          // MOBILE: Loading State
          if (_isLoadingContacts && _deviceContacts.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          // MATCHING LOGIC
          // 1. Registered: Contact Phone matches User Phone
          // 2. Invite: Contact Phone NOT in Users
          
          final List<Widget> listItems = [];

          // Headers
          listItems.add(_buildFixedOption(
            Icons.group, 
            'New group',
            onTap: () {
               Navigator.push(context, MaterialPageRoute(builder: (context) => const GroupParticipantSelectScreen()));
            }
          ));
          listItems.add(_buildFixedOption(
             Icons.person_add, 'New contact', 
             trailing: const Icon(Icons.qr_code),
             onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (context) => const AddContactScreen()));
                // Refresh contacts after return if needed, but setState triggers rebuild on lifecycle change for mobile usually
                _fetchContacts(); // Refresh
             }
          ));
          listItems.add(_buildFixedOption(Icons.groups, 'New community'));
          listItems.add(const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('Contacts on WhatsApp', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ));

          // Normalize and Match
          final registeredPhones = registeredUsers.map((u) => _contactService.normalizePhoneNumber(u.phoneNumber)).toSet();
          
          final matchedContacts = <Map<String, dynamic>>[];
          final inviteContacts = <Contact>[];

          for (var contact in _deviceContacts) {
             if (contact.phones.isEmpty) continue;
             String phone = _contactService.normalizePhoneNumber(contact.phones.first.number);
             
             // Check if this normalized phone exists in registered users
             // Note: In real app, strict matching (+91) required. Here we do simple string contains for clone ease.
             UserModel? matchedUser;
             try {
                matchedUser = registeredUsers.firstWhere(
                  (u) => _contactService.normalizePhoneNumber(u.phoneNumber).contains(phone) || phone.contains(_contactService.normalizePhoneNumber(u.phoneNumber)),
                );
             } catch (e) {
                matchedUser = null;
             }
             
             if (matchedUser != null && matchedUser.uid != _chatService.auth.currentUser?.uid) {
                matchedContacts.add({
                  'contact': contact,
                  'user': matchedUser,
                });
             } else {
                inviteContacts.add(contact);
             }
          }

          // Add Matched Contacts
          for (var item in matchedContacts) {
            final Contact c = item['contact'];
            final UserModel u = item['user'];
            
            listItems.add(ListTile(
              leading: AvatarWidget(imageUrl: u.profilePhotoUrl, radius: 22),
              title: Text(c.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(u.about, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () async {
                 String chatId = await _chatService.createOrGetChat(u.uid);
                 if (context.mounted) {
                    final contactObj = app_contact.Contact(
                      name: c.displayName, // Use local name
                      profileImage: u.profilePhotoUrl,
                      isOnline: u.isOnline,
                    );
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          contact: contactObj,
                          peerId: u.uid,
                          chatId: chatId,
                        ),
                      ),
                    );
                 }
              },
            ));
          }
          
          if (matchedContacts.isEmpty) {
             listItems.add(const Padding(
               padding: EdgeInsets.all(16.0),
               child: Text('No contacts on WhatsApp yet.', style: TextStyle(color: Colors.grey)),
             ));
          }

          // Invite Section
          listItems.add(const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('Invite to WhatsApp', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ));

          for (var c in inviteContacts) {
            listItems.add(ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.grey,
                radius: 22,
                child: Icon(Icons.person, color: Colors.white),
              ),
              title: Text(c.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
              trailing: const Text('Invite', style: TextStyle(color: Color(0xFF075E54), fontWeight: FontWeight.bold)),
              onTap: () {
                // Share invite link logic would go here
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invite sent! (Simulated)')));
              },
            ));
          }

          return ListView(children: listItems);
        },
      ),
    );
  }

  Widget _buildWebList(List<UserModel> users) {
     final currentUser = _chatService.auth.currentUser;
     final otherUsers = users.where((u) => u.uid != currentUser?.uid).toList();

     return ListView(
       children: [
          _buildFixedOption(
            Icons.group, 
            'New group',
            onTap: () {
               Navigator.push(context, MaterialPageRoute(builder: (context) => const GroupParticipantSelectScreen()));
            }
          ),
          _buildFixedOption(
             Icons.person_add, 'New contact', 
             trailing: const Icon(Icons.qr_code),
             onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (context) => const AddContactScreen()));
                setState(() {}); // Trigger rebuild to show new contacts if any (though for Web logic we rely on API in web list, we might need real fetch)
                // For web list, it renders 'otherUsers' from 'registeredUsers'. 
                // We actually need to refresh the contact list from API (User Model list doesn't change unless we re-fetch).
                // But AddContact adds to 'contacts' collection, while this list shows 'users' collection.
                // WE NEED TO DECIDE: Does Web view show Contacts or All Users? 
                // The current implementation of `_buildWebList` shows 'registeredUsers' passed from FutureBuilder -> `getRegisteredUsers`.
                // `getRegisteredUsers` returns ALL users in the system. 
                // So adding a contact won't change this list unless a new user signed up (which Add Contact doesn't do, it just links).
                // BUT, the user wants 'Add Contact' to add to their address book.
                // The Web View currently shows "Registered Users" (Global Directory basically).
                // Ideally, web view should ALSO show "My Contacts". 
                // Use the same logic as mobile or at least refresh.
                setState(() {}); 
             }
          ),
           const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('Registered Users', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ...otherUsers.map((u) => ListTile(
            leading: AvatarWidget(imageUrl: u.profilePhotoUrl, radius: 22),
            title: Text(u.name.isEmpty ? u.phoneNumber : u.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(u.about),
            onTap: () async {
                 try {
                   print("Attempting to open chat with: ${u.uid}");
                   String chatId = await _chatService.createOrGetChat(u.uid);
                   print("Chat ID received: $chatId");
                   
                   if (chatId.isEmpty) throw Exception("Received empty Chat ID");

                   if (context.mounted) {
                      final contactObj = app_contact.Contact(
                        name: u.name.isEmpty ? u.phoneNumber : u.name,
                        profileImage: u.profilePhotoUrl,
                        isOnline: u.isOnline,
                      );
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            contact: contactObj,
                            peerId: u.uid,
                            chatId: chatId,
                          ),
                        ),
                      );
                   }
                 } catch (e) {
                   print("Error opening chat: $e");
                   if (context.mounted) {
                     ScaffoldMessenger.of(context).showSnackBar(
                       SnackBar(content: Text("Failed to open chat: $e"), backgroundColor: Colors.red)
                     );
                   }
                 }
            },
          )),
       ],
     );
  }

  Widget _buildPermissionRequestUI() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.contacts, size: 80, color: Color(0xFF075E54)),
            const SizedBox(height: 24),
            const Text(
              'To help you connect with friends and family, WhatsApp needs access to your contacts.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9575CD),
                foregroundColor: Colors.white,
              ),
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
      leading: CircleAvatar(
        backgroundColor: const Color(0xFF9575CD),
        radius: 22,
        child: Icon(icon, color: Colors.white),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
extension on ChatService {
  get auth => FirebaseAuth.instance;
}
