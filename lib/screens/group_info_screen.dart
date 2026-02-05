import 'package:flutter/material.dart';
import 'package:whatsapp_clone/screens/chat_screen.dart';
import 'package:whatsapp_clone/screens/group_details_screen.dart';
import 'package:whatsapp_clone/services/chat_service.dart';
import 'package:whatsapp_clone/utils/chat_session_store.dart';
import 'package:whatsapp_clone/services/socket_service.dart';
import 'package:whatsapp_clone/models/contact.dart';

class GroupInfoScreen extends StatefulWidget {
  final List<String> selectedParticipantIds;
  final bool isCommunity;

  const GroupInfoScreen({super.key, required this.selectedParticipantIds, this.isCommunity = false});

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final ChatService _chatService = ChatService();
  bool _isCreating = false;

  Future<void> _create() async {
    final name = _subjectController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please enter a ${widget.isCommunity ? "community" : "group"} subject')));
      return;
    }

    setState(() => _isCreating = true);

    try {
      if (widget.isCommunity) {
         final result = await _chatService.createCommunity(name, _descriptionController.text.trim(), widget.selectedParticipantIds);
         
         if (mounted) {
             ChatSessionStore().triggerRefresh(); // Force Home Refresh
             Navigator.popUntil(context, (route) => route.isFirst);
             // Navigate to Community Home
             Navigator.push(
                context,
                MaterialPageRoute(
                   builder: (context) => GroupDetailsScreen(
                      chatId: result['announcementsChatId'], // Just to satisfy param
                      groupName: name, 
                      isCommunity: true,
                      communityId: result['communityId']
                   )
                )
             );
         }
      } else {
         final chatId = await _chatService.createGroupChat(name, widget.selectedParticipantIds, description: _descriptionController.text.trim());
         
         // Fix Sync: Trigger refresh and join socket immediately
         SocketService().joinChat(chatId);
         ChatSessionStore().triggerRefresh();

         if (mounted) {
            Navigator.popUntil(context, (route) => route.isFirst); 
            final groupContact = Contact(name: name, profileImage: '', isOnline: false);
            Navigator.push(context, MaterialPageRoute(builder: (c) => ChatScreen(contact: groupContact, peerId: 'group', chatId: chatId, isGroup: true)));
         }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error creating ${widget.isCommunity ? "community" : "group"}: $e')));
        setState(() => _isCreating = false);
      }
    }
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
             Text(widget.isCommunity ? 'New Community' : 'New Group', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
             Text(widget.isCommunity ? 'Community info' : 'Add subject', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
           ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Row(
               children: [
                 Container(
                   decoration: BoxDecoration(
                     color: Colors.grey[300],
                     borderRadius: BorderRadius.circular(30),
                   ),
                   padding: const EdgeInsets.all(12),
                   child: const Icon(Icons.camera_alt, color: Colors.grey, size: 30),
                 ),
                 const SizedBox(width: 15),
                 Expanded(
                   child: TextField(
                     controller: _subjectController,
                     decoration: InputDecoration(
                       hintText: widget.isCommunity ? 'Community name' : 'Type group subject here...',
                       contentPadding: EdgeInsets.zero,
                     ),
                     maxLength: 25,
                   ),
                 ),
                 const Icon(Icons.emoji_emotions_outlined, color: Colors.grey),
               ],
             ),
             if (widget.isCommunity) ...[
                const SizedBox(height: 20),
                TextField(
                   controller: _descriptionController,
                   decoration: const InputDecoration(
                     hintText: 'Community Description (optional)',
                     border: OutlineInputBorder(),
                     contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                   ),
                   maxLines: 3,
                ),
             ],
             const SizedBox(height: 20),
             Text(widget.isCommunity ? 'Groups: ${widget.selectedParticipantIds.length}' : 'Participants: ${widget.selectedParticipantIds.length}', style: const TextStyle(color: Colors.grey)),
             
             const Spacer(),
             
             if (_isCreating) const Center(child: CircularProgressIndicator())
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFC92136),
        onPressed: _isCreating ? null : _create,
        child: const Icon(Icons.check, color: Colors.white),
      ),
    );
  }
}
