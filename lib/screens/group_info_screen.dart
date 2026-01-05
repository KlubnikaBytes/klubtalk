import 'package:flutter/material.dart';
import 'package:whatsapp_clone/screens/chat_screen.dart';
import 'package:whatsapp_clone/services/chat_service.dart';
import 'package:whatsapp_clone/models/contact.dart';

class GroupInfoScreen extends StatefulWidget {
  final List<String> selectedParticipantIds;

  const GroupInfoScreen({super.key, required this.selectedParticipantIds});

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  final TextEditingController _subjectController = TextEditingController();
  final ChatService _chatService = ChatService();
  bool _isCreating = false;

  Future<void> _createGroup() async {
    final name = _subjectController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a group subject')));
      return;
    }

    setState(() => _isCreating = true);

    try {
      // Create Group in Firestore
      final chatId = await _chatService.createGroupChat(name, widget.selectedParticipantIds);
      
      if (mounted) {
        // Navigate to Chat Screen
        // Replace strictly to remove creation screens from back stack
        Navigator.popUntil(context, (route) => route.isFirst); 
        
        final groupContact = Contact(
          name: name,
          profileImage: '', // Placeholder
          isOnline: false, // Groups don't have online status
        );
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              contact: groupContact,
              peerId: 'group', // dummy
              chatId: chatId,
              isGroup: true,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error creating group: $e')));
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF9575CD),
        foregroundColor: Colors.white,
        title: const Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             Text('New Group', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
             Text('Add subject', style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
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
                     decoration: const InputDecoration(
                       hintText: 'Type group subject here...',
                       contentPadding: EdgeInsets.zero,
                     ),
                     maxLength: 25,
                   ),
                 ),
                 const Icon(Icons.emoji_emotions_outlined, color: Colors.grey),
               ],
             ),
             const SizedBox(height: 20),
             Text('Participants: ${widget.selectedParticipantIds.length}', style: const TextStyle(color: Colors.grey)),
             
             const Spacer(),
             
             if (_isCreating) const Center(child: CircularProgressIndicator())
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF9575CD),
        onPressed: _isCreating ? null : _createGroup,
        child: const Icon(Icons.check, color: Colors.white),
      ),
    );
  }
}
