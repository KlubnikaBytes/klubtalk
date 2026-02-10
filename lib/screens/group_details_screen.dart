import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:whatsapp_clone/models/group_model.dart';
import 'package:whatsapp_clone/services/auth_service.dart';
import 'package:whatsapp_clone/services/group_service.dart';
import 'package:whatsapp_clone/services/chat_service.dart';
import 'package:whatsapp_clone/services/media_upload_service.dart';
import 'package:whatsapp_clone/screens/group_settings_screen.dart';
import 'package:whatsapp_clone/screens/group_participant_select_screen.dart';
import 'package:whatsapp_clone/screens/chat_screen.dart'; 
import 'package:whatsapp_clone/models/contact.dart'; 
import 'package:whatsapp_clone/widgets/avatar_widget.dart';
import 'package:whatsapp_clone/config/api_config.dart';
import 'package:whatsapp_clone/services/contact_service.dart';
import 'package:whatsapp_clone/widgets/common/skeletons.dart';

class GroupDetailsScreen extends StatefulWidget {
  final String chatId;
  final String groupName;
  final String groupIcon;
  final bool isCommunity;
  final String? communityId;

  const GroupDetailsScreen({
    super.key, 
    required this.chatId, 
    required this.groupName,
    this.groupIcon = '',
    this.isCommunity = false,
    this.communityId,
  });

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  final GroupService _groupService = GroupService();
  final AuthService _authService = AuthService();
  final ChatService _chatService = ChatService();
  final MediaUploadService _mediaService = MediaUploadService();
  final ContactService _contactService = ContactService();

  GroupModel? _group;
  bool _isLoading = true;
  String? _currentUserUid;
  String _creatorName = 'Unknown';
  List<Map<String, dynamic>> _participants = [];

  @override
  void initState() {
    super.initState();
    _currentUserUid = _authService.currentUserId;
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    setState(() => _isLoading = true);
    try {
      if (widget.isCommunity) {
         // TODO: Community Details
         setState(() => _isLoading = false);
      } else {
        final group = await _groupService.getGroupDetails(widget.chatId);
        
        // Resolve Creator Name
        String cName = 'Unknown';
        if (group.createdBy != null) {
           if (group.createdBy == _currentUserUid) {
              cName = "You";
           } else {
              cName = await _contactService.resolveContactName(group.createdBy!);
           }
        }



        // Resolve Participants (Names from Contacts)
        List<Map<String, dynamic>> resolvedParts = [];
        try {
           final chats = await _chatService.getMyChats();
           final fullChat = chats.firstWhere((c) => (c['_id']??c['id']) == widget.chatId, orElse: () => {});
           
           if (fullChat.isNotEmpty && fullChat['participants'] != null) {
              final rawList = List<Map<String, dynamic>>.from(
                 (fullChat['participants'] as List).map((x) => x is Map ? x : {'_id': x.toString()})
              );

              for (var p in rawList) {
                  final uid = p['_id'] ?? p['id'] ?? '';
                  if (uid == _currentUserUid) {
                     p['displayName'] = "You";
                  } else {
                     final phone = p['phoneNumber'] ?? p['phone'] ?? '';
                     if (phone.isNotEmpty) {
                        p['displayName'] = await _contactService.getContactNameFromPhone(phone);
                     } else {
                        p['displayName'] = await _contactService.resolveContactName(uid);
                     }
                  }
                  resolvedParts.add(p);
              }
           }
        } catch (e) {
           print("Error processing participants: $e");
        }

        if (mounted) {
           setState(() {
             _group = group;
             _creatorName = cName;
             _participants = resolvedParts;
             _isLoading = false;
           });
        }
      }
    } catch (e) {
      print("Error fetching group details: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }


  String _getFullUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '${ApiConfig.baseUrl}$path';
  }

  Future<void> _updateName() async {
    if (_group == null) return;
    if (!_group!.canEditInfo(_currentUserUid!)) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Only admins can change group info')));
       return;
    }

    String newName = _group!.name;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Enter new subject"),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(hintText: "Subject"),
          onChanged: (val) => newName = val,
          controller: TextEditingController(text: _group!.name),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
               if (newName.isNotEmpty) {
                 Navigator.pop(context);
                 try {
                    await _groupService.updateGroupInfo(chatId: widget.chatId, name: newName);
                    _fetchDetails();
                 } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to update name: $e")));
                 }
               }
            }, 
            child: const Text("OK")
          ),
        ],
      )
    );
  }

  Future<void> _updateDescription() async {
     if (_group == null) return;
    if (!_group!.canEditInfo(_currentUserUid!)) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Only admins can change group info')));
       return;
    }

    String newDesc = _group!.description;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Enter group description"),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(hintText: "Description"),
          onChanged: (val) => newDesc = val,
          controller: TextEditingController(text: _group!.description),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
                 Navigator.pop(context);
                 try {
                    await _groupService.updateGroupInfo(chatId: widget.chatId, description: newDesc);
                    _fetchDetails();
                 } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to update description: $e")));
                 }
            }, 
            child: const Text("OK")
          ),
        ],
      )
    );
  }

  Future<void> _updateIcon() async {
    if (_group == null) return;
    if (!_group!.canEditInfo(_currentUserUid!)) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Only admins can change group icon')));
       return;
    }

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
       try {
          // Upload Image (Use generic uploadImage to avoid updating user profile)
          final data = await _mediaService.uploadImage(File(image.path));
          await _groupService.updateGroupInfo(chatId: widget.chatId, avatar: data['url']);
          _fetchDetails();
       } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to update icon: $e")));
       }
    }
  }

  Future<void> _addParticipant() async {
    if (_group == null) return;
    if (!_group!.canAddParticipants(_currentUserUid!)) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Only admins can add participants')));
       return;
    }

    // Open Participant Select Screen in Selection Mode
    final List<String>? selectedIds = await Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (context) => GroupParticipantSelectScreen(
           existingGroupId: widget.chatId,
           excludeIds: _group!.participants,
        )
      )
    );

    if (selectedIds != null && selectedIds.isNotEmpty) {
       // Add each
       try {
           for (var uid in selectedIds) {
              await _groupService.addParticipant(chatId: widget.chatId, userId: uid);
           }
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Participants added")));
           _fetchDetails();
       } catch (e) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to add participants: $e")));
       }
    }
  }

  Future<void> _exitGroup() async {
    try {
       await _groupService.leaveGroup(chatId: widget.chatId);
       // Navigate back to home
       Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to exit group: $e")));
    }
  }

  void _showParticipantOptions(Map<String, dynamic> user, bool isAdmin) {
      final uid = user['_id'] ?? user['id'];
      final name = user['name'] ?? user['phone'] ?? 'User';
      final isSelf = uid == _currentUserUid;

      if (isSelf) return;

      final bool amIAdmin = _group?.isAdmin(_currentUserUid!) ?? false;

      showModalBottomSheet(
        context: context,
        builder: (context) {
           return Column(
             mainAxisSize: MainAxisSize.min,
             children: [
               ListTile(
                 leading: const Icon(Icons.message),
                 title: Text("Message $name"),
                 onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (c) => ChatScreen(
                       contact: Contact(name: name, profileImage: user['avatar']??'', isOnline: false),
                       peerId: uid, 
                       chatId: 'temp_$uid', // ChatService will resolve
                       isGroup: false
                    )));
                 },
               ),
               if (amIAdmin) ...[
                  if (isAdmin)
                    ListTile(
                      leading: const Icon(Icons.security_update_warning),
                      title: const Text("Dismiss as admin"),
                      onTap: () async {
                         Navigator.pop(context);
                         try {
                            await _groupService.demoteAdmin(chatId: widget.chatId, userId: uid);
                            _fetchDetails();
                         } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed: $e")));
                         }
                      },
                    )
                  else
                    ListTile(
                      leading: const Icon(Icons.security),
                      title: const Text("Make group admin"),
                      onTap: () async {
                         Navigator.pop(context);
                         try {
                            await _groupService.promoteToAdmin(chatId: widget.chatId, userId: uid);
                            _fetchDetails();
                         } catch (e) {
                             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed: $e")));
                         }
                      },
                    ),
                  
                  ListTile(
                    leading: const Icon(Icons.person_remove, color: Colors.red),
                    title: Text("Remove $name", style: const TextStyle(color: Colors.red)),
                    onTap: () async {
                       Navigator.pop(context);
                       try {
                          await _groupService.removeParticipant(chatId: widget.chatId, userId: uid);
                          _fetchDetails();
                       } catch (e) {
                           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed: $e")));
                       }
                    },
                  ),
               ]
             ],
           );
        }
      );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: ContactListSkeleton());
    if (_group == null) return const Scaffold(body: Center(child: Text('Failed to load group')));

    final isCommunity = widget.isCommunity;
    final amIAdmin = _group!.isAdmin(_currentUserUid ?? '');

    // Resolve Participant Objects (Since GroupModel only holds Strings, we rely on cached data 
    // OR we need to populate. 
    // Wait, getGroupDetails() in GroupService fetches Chat object which HAS populated participants!
    // But GroupModel.fromJson only stores List<String>.
    // To display list, we need the FULL array of user objects.
    // I should update GroupModel to store List<User> or fetch them.
    // OR, I can just use the RAW json response in the service?
    // GroupService.getGroupDetails returns GroupModel. 
    // I should Modify GroupService to return Map<String, dynamic> or update GroupModel.
    // BUT, GroupDetailsScreen needs names/avatars.
    // I will simply modify `GroupService.getGroupDetails` to return the RAW MAP, or create a `FullGroupModel`.
    // Or I'll just use `ChatService.getMyChats()` filter method again but return the raw map here locally.
    // Ah, wait. GroupService logic:
    /*
      final List<dynamic> chats = jsonDecode(response.body);
      final groupData = chats.firstWhere...
      return GroupModel.fromJson(groupData);
    */
    // The `groupData` HAS populated fields. `GroupModel` discards them.
    // I will update GroupModel.dart to include `participantObjects` if I can, OR
    // I can just cheat here and fetch chats again? No, duplicate call.
    // Ideally I update GroupModel.
    // But for now, I'll bypass and use `_groupService` returning `Map`?
    // No, strictly types.
    // I will assume `GroupModel` has `participants` as IDs, and I need to fetch their info?
    // But device contacts?
    // Backend returns `participants` populated with `{ name, phone, avatar }`.
    // I will use a local Helper to fetch user details or just Hack: 
    // Modify GroupService to return Map!
    // Or add `participantDetails` to `GroupModel`.
    
    // Let's rely on `_chatService.getMyChats()` since it's cached.
    // I'll fetch raw chat data here.
    
    return Scaffold(
      body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                backgroundColor: const Color(0xFFC92136),
                flexibleSpace: FlexibleSpaceBar(
                  title: GestureDetector(
                    onTap: _updateName,
                    child: Text(_group!.name, style: const TextStyle(shadows: [Shadow(blurRadius: 2, color: Colors.black)]))
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                       _group!.avatar.isNotEmpty 
                          ? Image.network(_getFullUrl(_group!.avatar), fit: BoxFit.cover)
                          : Container(color: Colors.grey, child: Icon(Icons.group, size: 100, color: Colors.white)),
                       
                       if (_group!.canEditInfo(_currentUserUid!))
                       Positioned(
                         bottom: 16, right: 16,
                         child: FloatingActionButton(
                           mini: true,
                           onPressed: _updateIcon,
                           child: const Icon(Icons.edit),
                         )
                       )
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    ListTile(
                      title: Text(_group!.description.isEmpty ? "Add group description" : _group!.description),
                      subtitle: Text("Created by $_creatorName"), 
                      trailing: const Icon(Icons.edit, size: 18),
                      onTap: _updateDescription,
                    ),
                    const Divider(thickness: 10, color: Color(0xFFF2F2F2)),
                    
                    // Stats
                    ListTile(
                      title: Text("${_participants.length} participants"),
                      trailing: const Icon(Icons.search, color: Color(0xFFC92136)),
                    ),
                    
                    // Add Participant
                    if (_group!.canAddParticipants(_currentUserUid!))
                    ListTile(
                      leading: const CircleAvatar(backgroundColor: Color(0xFFC92136), child: Icon(Icons.person_add, color: Colors.white)),
                      title: const Text("Add participants"),
                      onTap: _addParticipant,
                    ),
                    
                    // Group Settings (Admin Only)
                    if (amIAdmin)
                     ListTile(
                      leading: const CircleAvatar(backgroundColor: Colors.grey, child: Icon(Icons.settings, color: Colors.white)),
                      title: const Text("Group Settings"),
                      onTap: () async {
                         final changed = await Navigator.push(context, MaterialPageRoute(builder: (_) => GroupSettingsScreen(group: _group!)));
                         if (changed == true) _fetchDetails();
                      },
                    ),

                  ],
                ),
              ),

              // Participants List
              SliverList(
                delegate: SliverChildBuilderDelegate(
                    (context, index) {
                         final u = _participants[index];
                         final uid = u['_id'] ?? u['id'];
                         final isAdmin = _group!.isAdmin(uid);
                         final isMe = uid == _currentUserUid;

                         return ListTile(
                           leading: AvatarWidget(imageUrl: _getFullUrl(u['avatar'] ?? ''), radius: 20),
                           title: Text(u['displayName'] ?? u['phone'] ?? 'User'),
                           subtitle: Text(u['about'] ?? "Hey there! I am using WhatsApp."),
                           trailing: isAdmin 
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: const Color(0xFFC92136)),
                                    borderRadius: BorderRadius.circular(4)
                                  ),
                                  child: const Text("Group Admin", style: TextStyle(color: Color(0xFFC92136), fontSize: 10))
                                )
                              : null,
                           onTap: () => _showParticipantOptions(u, isAdmin),
                         );
                    },
                    childCount: _participants.length,
                  ),
                ),
              
              SliverToBoxAdapter(
                child: Padding(
                   padding: const EdgeInsets.all(20),
                   child: _group!.participants.contains(_currentUserUid) 
                   ? TextButton(
                       onPressed: _exitGroup,
                       child: const Row(
                         children: [
                           Icon(Icons.exit_to_app, color: Colors.red),
                           SizedBox(width: 10),
                           Text("Exit Group", style: TextStyle(color: Colors.red, fontSize: 16))
                         ],
                       )
                     )
                   : const SizedBox(),
                ) 
              ),
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.thumb_down, color: Colors.red),
                      title: const Text("Report group", style: TextStyle(color: Colors.red)),
                      onTap: () async {
                         try {
                           await _groupService.leaveGroup(chatId: widget.chatId); // Simplified report = leave logic for now
                           Navigator.popUntil(context, (route) => route.isFirst);
                         } catch (e) {}
                      }, 
                    ),
                    const SizedBox(height: 50),
                  ],
                ),
              )
            ],
           )
    );
  }

  // Workaround to get raw data
  Future<Map<String, dynamic>> _fetchRawChat() async {
     final chats = await ChatService().getMyChats();
     return chats.firstWhere((c) => (c['_id']??c['id']) == widget.chatId);
  }
}
