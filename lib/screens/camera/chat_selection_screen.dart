import 'dart:io';
import 'package:flutter/material.dart';
import 'package:messaging_app/services/chat_service.dart';
import 'package:messaging_app/services/media_upload_service.dart';
import 'package:whatsapp_clone/screens/chat_screen.dart';
import 'package:whatsapp_clone/models/contact.dart';
import 'package:whatsapp_clone/services/auth_service.dart';
import 'package:whatsapp_clone/services/contact_service.dart';
import 'package:whatsapp_clone/screens/chat_list_screen.dart'; // Reuse logic if possible, or simple list
import 'package:whatsapp_clone/widgets/common/skeletons.dart';

class ChatSelectionScreen extends StatefulWidget {
  final File mediaFile;
  final String mediaType;
  final String caption;

  const ChatSelectionScreen({
    super.key,
    required this.mediaFile,
    required this.mediaType,
    required this.caption
  });

  @override
  State<ChatSelectionScreen> createState() => _ChatSelectionScreenState();
}

class _ChatSelectionScreenState extends State<ChatSelectionScreen> {
  final ChatService _chatService = ChatService();
  final MediaUploadService _mediaService = MediaUploadService();

  List<Map<String, dynamic>> _recentChats = [];
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    try {
      final chats = await _chatService.getMyChats();
      // Filter out deleted/archived if needed, but WhatsApp shows all recent
      if (mounted) {
         setState(() {
           _recentChats = chats;
           _isLoading = false;
         });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendToChat(String chatId, String peerId, Contact contact, bool isGroup) async {
    if (_isSending) return;
    setState(() => _isSending = true);
    
    try {
      // 1. Upload Media
      // We can use the existing sendMediaMessage flow, or upload manually then send.
      // Ideally reusing ChatScreen's logic is best, but we are outside ChatScreen.
      // We'll upload using MediaUploadService and then call ChatService.sendMessage
      
      String? originalUrl;
      String? thumbnailUrl; // We might skip thumb for fast impl or generate it
      
      // NOTE: ChatService expects pre-uploaded URL usually, or handles it?
      // Looking at ChatScreen, it usually uploads then sends.
      // Let's rely on media_upload_service.
      
      // Determine paths
      // Actually, let's use a simpler approach: 
      // Upload -> Get URL -> Send Message
      
      final currentUid = AuthService().currentUserId;
      if (currentUid == null) return;
      
      // Upload
      // Using a generic upload function if available, or we assume VPS/Firebase based on previous context.
      // Previous context mentioned VPS for media. 
      // Let's use `MediaUploadService`.
      
      if (widget.mediaType == 'image') {
          // Compress/Upload
           final uploaded = await _mediaService.uploadImage(widget.mediaFile, mimeType: 'image/jpeg'); 
           if (uploaded != null) {
              originalUrl = uploaded['original'];
              thumbnailUrl = uploaded['thumbnail']; // If available
           }
      } else {
          // Video
           final uploaded = await _mediaService.uploadGenericFile(widget.mediaFile, mimeType: 'video/mp4');
           if (uploaded != null) {
             originalUrl = uploaded['url'];
              thumbnailUrl = uploaded['thumbnail'];
           }
      }

      if (originalUrl == null) throw Exception("Upload failed");

      // 2. Send Message
      if (widget.mediaType == 'image') {
         await _chatService.sendImageMessage(chatId, widget.mediaFile, mimeType: 'image/jpeg');
      } else if (widget.mediaType == 'video') {
         await _chatService.sendVideoMessage(chatId, widget.mediaFile, mimeType: 'video/mp4');
      } else {
         // Fallback using raw send if needed, but the dedicated methods are safer
         await _chatService.sendMessage(chatId, widget.caption); 
      }

      // 3. Navigate to Chat (Pop all camera screens)
      if (mounted) {
         Navigator.of(context).pushAndRemoveUntil(
           MaterialPageRoute(
             builder: (_) => ChatScreen(
                chatId: chatId,
                peerId: peerId,
                contact: contact,
                isGroup: isGroup
             )
           ),
           (route) => route.isFirst, // Go back to Home then push Chat
         );
      }
      
    } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to send: $e")));
       setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Send to...", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: _isLoading 
         ? const ChatListSkeleton() 
         : Stack(
           children: [
             ListView.builder(
               itemCount: _recentChats.length,
               itemBuilder: (context, index) {
                  final chat = _recentChats[index];
                  final chatId = chat['_id'] ?? chat['id'];
                  final isGroup = chat['isGroup'] == true;
                  final currentUid = AuthService().currentUserId;
                  
                  // Setup Name/Avatar
                   String name = 'Chat';
                   String avatar = '';
                   String peerId = '';
                   
                   if (isGroup) {
                      name = chat['groupName'] ?? 'Group';
                      avatar = chat['groupPhoto'] ?? '';
                   } else {
                      final participants = List<String>.from(chat['participants'] ?? []);
                      peerId = participants.firstWhere((id) => id != currentUid, orElse: () => '');
                      final details = List<Map<String,dynamic>>.from(chat['participantsDetails'] ?? []);
                      final peerData = details.firstWhere((d) => d['firebaseUid'] == peerId, orElse: () => {});
                      name = peerData['name'] ?? 'Unknown';
                      avatar = peerData['avatar'] ?? '';
                      if (avatar.isEmpty) avatar = 'https://ui-avatars.com/api/?name=$name';
                   }

                   final contact = Contact(name: name, profileImage: avatar, isOnline: true);
                   
                   return ListTile(
                     leading: CircleAvatar(
                       backgroundImage: NetworkImage(avatar),
                       radius: 24,
                     ),
                     title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                     subtitle: isGroup ? const Text("Group") : null,
                     trailing: _isSending ? null : const Icon(Icons.send, color: Color(0xFF25D366)),
                     onTap: () => _sendToChat(chatId, peerId, contact, isGroup),
                   );
               },
             ),
             if (_isSending)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                )
           ],
         ),
       floatingActionButton: FloatingActionButton(
         child: const Icon(Icons.search),
         onPressed: () {
           // TODO: Open full contact picker
         },
       ),
    );
  }
}
