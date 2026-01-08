import 'package:flutter/material.dart';
import 'package:whatsapp_clone/models/contact.dart';
import 'package:whatsapp_clone/services/chat_service.dart';

class GroupDetailsScreen extends StatefulWidget {
  final String chatId;
  final String groupName;
  final String groupIcon;

  const GroupDetailsScreen({
    super.key, 
    required this.chatId, 
    required this.groupName,
    this.groupIcon = '',
  });

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  final ChatService _chatService = ChatService();
  bool _isLoading = true;
  List<Contact> _participants = [];
  bool _isAdmin = false; // TODO: Fetch validation

  @override
  void initState() {
    super.initState();
    _fetchGroupDetails();
  }

  Future<void> _fetchGroupDetails() async {
    try {
      // TODO: Implement getGroupDetails in ChatService and Backend
      // For now mocking or fetching basics
      // final details = await _chatService.getGroupDetails(widget.chatId);
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
                : Container(color: Colors.grey, child: const Icon(Icons.group, size: 100, color: Colors.white)),
            ),
            backgroundColor: const Color(0xFF075E54),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 10),
                ListTile(
                  title: Text("${_participants.length} participants"),
                  trailing: const Icon(Icons.search, color: const Color(0xFF075E54)),
                ),
                const Divider(),
                // Add Participant (If Admin)
                ListTile(
                  leading: const CircleAvatar(backgroundColor: Color(0xFF075E54), child: Icon(Icons.add, color: Colors.white)),
                  title: const Text("Add participants"),
                  onTap: () {},
                ),
                // Participant List
                if (_isLoading) 
                   const Center(child: CircularProgressIndicator())
                else
                   ..._participants.map((p) => ListTile(
                     leading: CircleAvatar(backgroundImage: NetworkImage(p.profileImage)),
                     title: Text(p.name),
                     subtitle: const Text("Hey there! I am using WhatsApp."),
                   )),
                
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.exit_to_app, color: Colors.red),
                  title: const Text("Exit group", style: TextStyle(color: Colors.red)),
                  onTap: _exitGroup,
                ),
                ListTile(
                  leading: const Icon(Icons.thumb_down, color: Colors.red),
                  title: const Text("Report group", style: TextStyle(color: Colors.red)),
                  onTap: () {}, // Reuse report logic?
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
