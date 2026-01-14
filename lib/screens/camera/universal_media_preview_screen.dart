import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:messaging_app/config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:messaging_app/screens/camera/chat_selection_screen.dart';
import 'package:messaging_app/models/contact.dart';
import 'package:messaging_app/services/chat_service.dart';
import 'package:messaging_app/services/media_upload_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:messaging_app/screens/chat_screen.dart';

class UniversalMediaPreviewScreen extends StatefulWidget {
  final File file;
  final String type; // 'image' or 'video'
  final String? chatId;
  final String? peerId;
  final Contact? contact;
  final bool isGroup;

  const UniversalMediaPreviewScreen({
    super.key, 
    required this.file, 
    required this.type,
    this.chatId,
    this.peerId,
    this.contact,
    this.isGroup = false,
  });

  @override
  State<UniversalMediaPreviewScreen> createState() => _UniversalMediaPreviewScreenState();
}

class _UniversalMediaPreviewScreenState extends State<UniversalMediaPreviewScreen> {
  final TextEditingController _captionController = TextEditingController();
  VideoPlayerController? _videoController;
  bool _isPlaying = false;
  bool _isSending = false;
  final ChatService _chatService = ChatService();
  final MediaUploadService _mediaService = MediaUploadService();

  @override
  void initState() {
    super.initState();
    if (widget.type == 'video') {
      _videoController = VideoPlayerController.file(widget.file)
        ..initialize().then((_) {
          setState(() {});
          _videoController!.play();
          _isPlaying = true;
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



  void _sendMessage() {
     if (widget.chatId != null) {
        _sendWithCaption();
     } else {
       Navigator.push(context, MaterialPageRoute(
         builder: (_) => ChatSelectionScreen(
           mediaFile: widget.file,
           mediaType: widget.type,
           caption: _captionController.text.trim(),
         )
       ));
     }
  }

  Future<void> _sendWithCaption() async {
     if (_isSending) return;
     setState(() => _isSending = true);
     
     try {
        // 0. Copy to Safe Directory (Fix for temp file deletion or scoped storage issues)
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${widget.file.path.split('/').last}';
        final savedFile = await widget.file.copy('${appDir.path}/$fileName');
        print("DEBUG: Copied file to safe path: ${savedFile.path}");

       // 1. Upload
       Map<String, dynamic> uploaded;
       if (widget.type == 'image') {
          uploaded = await _mediaService.uploadImage(savedFile, mimeType: 'image/jpeg');
       } else {
          uploaded = await _mediaService.uploadGenericFile(savedFile, mimeType: 'video/mp4');
       }
       print("DEBUG: Upload await returned.");
       
       String url = uploaded['url'] ?? uploaded['original'] ?? '';
       // Robustness: Handle relative paths from older backends or misconfig
       if (url.startsWith('/')) {
          url = '${ApiConfig.baseUrl}$url';
       }
       print("DEBUG: Final URL: $url");
       String? thumb = uploaded['thumbnail'];
       print("DEBUG: Thumb extracted: $thumb");
       print("DEBUG: Upload success logs: $url");

       // 2. Send Message
       print("DEBUG: Getting currentUser...");
       final user = FirebaseAuth.instance.currentUser;
       print("DEBUG: User: $user");
       final token = await user?.getIdToken();
       print("DEBUG: Token retrieved (length): ${token?.length}");
       
       print("DEBUG: Parsing messages endpoint: ${ApiConfig.messagesEndpoint}");
       final uri = Uri.parse(ApiConfig.messagesEndpoint);
       print("DEBUG: Endpoint parsed: $uri");
       
       print("DEBUG: Encoding body...");
       final body = jsonEncode({
            'chatId': widget.chatId,
            'content': _captionController.text.trim(),
            'type': widget.type,
            'originalUrl': url,
            'previewUrl': thumb,
            'mime': widget.type == 'image' ? 'image/jpeg' : 'video/mp4'
       });
       print("DEBUG: Body encoded.");

       print("DEBUG: Posting to backend...");
       final response = await http.post(
         uri,
         headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
         },
         body: body
       );
       print("DEBUG: Post returned status: ${response.statusCode}");
       
       if (response.statusCode == 201) {
          // Success
          Navigator.of(context).pop(); // preview
          Navigator.of(context).pop(); // camera
       } else {
          throw Exception("Send failed: ${response.body}");
       }

     } catch (e, stack) {
       print("Send error: $e");
       print("Stack trace: $stack");
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to send: $e")));
       setState(() => _isSending = false);
     }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
           IconButton(
             icon: const Icon(Icons.crop_rotate, color: Colors.white),
             onPressed: () {}, // Crop TODO
           ),
           IconButton(
             icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.white),
             onPressed: () {}, // Stickers TODO
           ),
           IconButton(
             icon: const Icon(Icons.title, color: Colors.white),
             onPressed: () {}, // Text Overlay TODO
           ),
           IconButton(
             icon: const Icon(Icons.edit, color: Colors.white),
             onPressed: () {}, // Draw TODO
           ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
         children: [
            // Media Preview
            Center(
              child: widget.type == 'video'
                  ? _videoController != null && _videoController!.value.isInitialized
                      ? AspectRatio(
                          aspectRatio: _videoController!.value.aspectRatio,
                          child: VideoPlayer(_videoController!),
                        )
                      : const CircularProgressIndicator()
                  : Image.file(widget.file),
            ),
            
            // Play Button Layout (Video)
            if (widget.type == 'video' && _videoController != null)
              Center(
                 child: IconButton(
                    iconSize: 50,
                    icon: Icon(_isPlaying ? Icons.pause_circle_outline : Icons.play_circle_outline, color: Colors.white70),
                    onPressed: () {
                       setState(() {
                         if (_videoController!.value.isPlaying) {
                           _videoController!.pause();
                           _isPlaying = false;
                         } else {
                           _videoController!.play();
                           _isPlaying = true;
                         }
                       });
                    },
                 ),
              ),

            // Bottom Caption & Send
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   Container(
                     color: Colors.black45,
                     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                     child: Row(
                       children: [
                          Expanded(
                            child: TextField(
                              controller: _captionController,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                hintText: "Add a caption...",
                                hintStyle: TextStyle(color: Colors.white70),
                                border: InputBorder.none,
                                prefixIcon: Icon(Icons.add_photo_alternate, color: Colors.white),
                              ),
                            ),
                          ),
                          
                          // Send Button
                          GestureDetector(
                            onTap: _sendMessage,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(
                                color: Color(0xFF25D366),
                                shape: BoxShape.circle
                              ),
                              child: const Icon(Icons.send, color: Colors.white),
                            ),
                          )
                       ],
                     ),
                   ),
                ],
              ),
            )
         ],
      ),
    );
  }
}
