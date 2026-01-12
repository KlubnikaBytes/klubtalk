import 'package:flutter/material.dart';
import 'package:whatsapp_clone/models/contact.dart';
import 'package:whatsapp_clone/services/chat_service.dart';
import 'package:whatsapp_clone/screens/chat_screen.dart';
import 'package:whatsapp_clone/widgets/avatar_widget.dart';

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
  final ChatService _chatService = ChatService();
  bool _isLoading = true;
  List<Contact> _participants = [];
  List<dynamic> _communityGroups = [];
  Map<String, dynamic>? _announcementsGroup;

  @override
  void initState() {
    super.initState();
    if (widget.isCommunity) {
      _fetchCommunityDetails();
    } else {
      _fetchGroupDetails();
    }
  }

  Future<void> _fetchCommunityDetails() async {
    if (widget.communityId == null) return;
    try {
      final data = await _chatService.getCommunity(widget.communityId!);
      setState(() {
        _isLoading = false;
        _communityGroups = data['groupIds'] ?? [];
        _announcementsGroup = data['announcementsGroupId'];
      });
    } catch (e) {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchGroupDetails() async {
    try {
      // Mocking for existing group logic or implement proper fetch
      // For now we just stop loading as we don't have getGroupDetails
      setState(() {
        _isLoading = false;
        // _participants = details.participants;
      });
    } catch (e) {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _exitGroup() async {
     // Implement Exit Logic
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(widget.groupName),
              background: widget.groupIcon.isNotEmpty 
                ? Image.network(widget.groupIcon, fit: BoxFit.cover)
                : Container(color: Colors.grey, child: Icon(widget.isCommunity ? Icons.groups : Icons.group, size: 100, color: Colors.white)),
            ),
            backgroundColor: const Color(0xFF075E54),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 10),
                ListTile(
                  title: Text(widget.isCommunity ? "${_communityGroups.length + 1} groups" : "${_participants.length} participants"),
                  trailing: const Icon(Icons.search, color: Color(0xFF075E54)),
                ),
                const Divider(),
                
                if (widget.isCommunity) ...[
                   // COMMUNITY VIEW
                   if (_isLoading) 
                      const Center(child: CircularProgressIndicator())
                   else ...[
                      // Announcements
                      if (_announcementsGroup != null)
                        ListTile(
                          leading: const CircleAvatar(backgroundColor: Color(0xFF075E54), child: Icon(Icons.campaign, color: Colors.white)),
                          title: Text(_announcementsGroup!['groupName'] ?? 'Announcements'),
                          subtitle: const Text("Announcements"),
                          onTap: () {
                             Navigator.push(context, MaterialPageRoute(builder: (c) => ChatScreen(
                               contact: Contact(name: _announcementsGroup!['groupName'], profileImage: _announcementsGroup!['groupPhoto'] ?? '', isOnline: false),
                               peerId: 'group',
                               chatId: _announcementsGroup!['_id'],
                               isGroup: true
                             )));
                          },
                        ),
                      const Divider(),
                      ..._communityGroups.map((g) => ListTile(
                         leading: AvatarWidget(imageUrl: g['groupPhoto'] ?? '', radius: 20),
                         title: Text(g['groupName'] ?? 'Group'),
                         subtitle: Text("${(g['participants'] as List?)?.length ?? 0} members"),
                         onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (c) => ChatScreen(
                               contact: Contact(name: g['groupName'], profileImage: g['groupPhoto'] ?? '', isOnline: false),
                               peerId: 'group',
                               chatId: g['_id'],
                               isGroup: true
                             )));
                         },
                      )),
                   ]
                ] else ...[
                  // GROUP VIEW
                  ListTile(
                    leading: const CircleAvatar(backgroundColor: Color(0xFF075E54), child: Icon(Icons.add, color: Colors.white)),
                    title: const Text("Add participants"),
                    onTap: () {},
                  ),
                  if (_isLoading) 
                     const Center(child: CircularProgressIndicator())
                  else
                     ..._participants.map((p) => ListTile(
                       leading: CircleAvatar(backgroundImage: NetworkImage(p.profileImage)),
                       title: Text(p.name),
                       subtitle: const Text("Hey there! I am using WhatsApp."),
                     )),
                ],
                
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.exit_to_app, color: Colors.red),
                  title: Text(widget.isCommunity ? "Exit community" : "Exit group", style: const TextStyle(color: Colors.red)),
                  onTap: _exitGroup,
                ),
                if (!widget.isCommunity)
                ListTile(
                  leading: const Icon(Icons.thumb_down, color: Colors.red),
                  title: const Text("Report group", style: TextStyle(color: Colors.red)),
                  onTap: () {}, 
                ),
                const SizedBox(height: 50),
              ],
            ),
          )
        ],
      ),
    );
  }
}
