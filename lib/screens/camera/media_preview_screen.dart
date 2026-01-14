import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:whatsapp_clone/services/media_upload_service.dart';
import 'package:whatsapp_clone/services/chat_service.dart';
import 'package:whatsapp_clone/screens/new_chat_screen.dart';
import 'package:whatsapp_clone/screens/chat_screen.dart';
import 'package:whatsapp_clone/models/contact.dart';

class MediaPreviewScreen extends StatefulWidget {
  final String filePath;
  final bool isVideo;

  const MediaPreviewScreen({super.key, required this.filePath, required this.isVideo});

  @override
  State<MediaPreviewScreen> createState() => _MediaPreviewScreenState();
}

class _MediaPreviewScreenState extends State<MediaPreviewScreen> {
  VideoPlayerController? _videoController;
  final TextEditingController _captionController = TextEditingController();
  final MediaUploadService _uploadService = MediaUploadService();
  final ChatService _chatService = ChatService();
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      _videoController = VideoPlayerController.file(File(widget.filePath))
        ..initialize().then((_) {
          setState(() {});
          _videoController!.play();
          _videoController!.setLooping(true);
        });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _captionController.dispose();
    super.dispose();
  }

  void _sendMedia() async {
    final result = await Navigator.push(
      context, 
      MaterialPageRoute(builder: (context) => const NewChatScreen(isSelectionMode: true, isMultiSelect: true))
    );

    if (result != null && result is List) {
         _uploadAndSend(List<Map<String, dynamic>>.from(result));
    }
  }

  Future<void> _uploadAndSend(List<Map<String, dynamic>> recipients) async {
    setState(() => _isUploading = true);
    
    try {
        final text = _captionController.text.trim();
        final caption = text.isNotEmpty ? text : null;

        for (var recipient in recipients) {
             String? chatId = recipient['chatId'];
             
             if (chatId == null || chatId.isEmpty) {
                // If chatId is missing (Multi-select User case), resolve it using peerId
                final String? peerId = recipient['id'] ?? recipient['peerId']; 
                if (peerId != null && peerId.isNotEmpty) {
                    try {
                        chatId = await _chatService.createOrGetChat(peerId);
                    } catch(e) {
                         print("Failed to resolve chatId for $peerId: $e");
                         continue; 
                    }
                } else {
                   print("No peerId or chatId found for recipient: $recipient");
                   continue;
                }
             }

             if (chatId == null) continue; // Should be resolved by now
             
             if (widget.isVideo) {
               await _chatService.sendVideoMessage(chatId, widget.filePath, mimeType: 'video/mp4', caption: caption);
             } else {
               await _chatService.sendImageMessage(chatId, widget.filePath, mimeType: 'image/jpeg', caption: caption);
             }
        }

        if (mounted) {
           // If single recipient, open chat. If multiple, pop to root (ChatList).
           if (recipients.length == 1) {
               final recipient = recipients.first;
               // If it's a group, we might not have 'contact', just navigate carefully
               // If group, type='group', name=groupName
               bool isGroup = recipient['isGroup'] == true;
               
               if (isGroup) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                  // We need ChatScreen to handle Group
                  // Assuming existing ChatScreen can take chatId + isGroup
                  // We need to double check ChatScreen constructor.
                  // But standard flow:
                   Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (_) => ChatScreen(
                         contact: null, // Group has no single contact
                         peerId: '',
                         chatId: recipient['chatId'],
                         isGroup: true,
                         groupName: recipient['name'],
                         groupPhoto: recipient['photo']
                      ))
                   );
               } else {
                   final contact = recipient['contact'] as Contact;
                   final peerId = recipient['peerId'] as String;
                   
                   Navigator.of(context).popUntil((route) => route.isFirst);
                   Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (_) => ChatScreen(
                         contact: contact, 
                         peerId: peerId, 
                         chatId: recipient['chatId'],
                      ))
                   );
               }
           } else {
               Navigator.of(context).popUntil((route) => route.isFirst);
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sent to multiple chats")));
           }
        }

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Send failed: $e")));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    } 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
             child: widget.isVideo 
              ? (_videoController != null && _videoController!.value.isInitialized
                  ? AspectRatio(aspectRatio: _videoController!.value.aspectRatio, child: VideoPlayer(_videoController!))
                  : const CircularProgressIndicator())
              : Image.file(File(widget.filePath)),
          ),
          Positioned(
            bottom: 0, 
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black.withOpacity(0.6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                children: [
                   Expanded(
                     child: TextField(
                       controller: _captionController,
                       style: const TextStyle(color: Colors.white),
                       decoration: const InputDecoration(
                         hintText: 'Add a caption...',
                         hintStyle: TextStyle(color: Colors.white70),
                         border: InputBorder.none,
                         prefixIcon: Icon(Icons.add_photo_alternate, color: Colors.white),
                       ),
                     ),
                   ),
                   FloatingActionButton(
                     backgroundColor: const Color(0xFF9575CD),
                     onPressed: _isUploading ? null : _sendMedia,
                     child: _isUploading 
                       ? const CircularProgressIndicator(color: Colors.white) 
                       : const Icon(Icons.send, color: Colors.white),
                   )
                ],
              ),
            ),
          ),
          Positioned(
             top: 40,
             left: 10,
             child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
          )
        ],
      ),
    );
  }
}
