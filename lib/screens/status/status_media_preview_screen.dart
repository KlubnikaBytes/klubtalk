
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:whatsapp_clone/services/status_service.dart';
import 'package:whatsapp_clone/screens/status/status_privacy_screen.dart';

class StatusMediaPreviewScreen extends StatefulWidget {
  final File file;
  final String type; // 'image' or 'video'
  final bool comeFromCamera;

  const StatusMediaPreviewScreen({
    super.key, 
    required this.file, 
    required this.type,
    this.comeFromCamera = false,
  });

  @override
  State<StatusMediaPreviewScreen> createState() => _StatusMediaPreviewScreenState();
}

class _StatusMediaPreviewScreenState extends State<StatusMediaPreviewScreen> {
  final TextEditingController _captionController = TextEditingController();
  final StatusService _statusService = StatusService();
  VideoPlayerController? _videoController;
  bool _isSending = false;

  // Privacy
  String _privacy = 'contacts';
  List<String> _allowedUsers = [];
  List<String> _excludedUsers = [];

  @override
  void initState() {
    super.initState();
    if (widget.type == 'video') {
      _videoController = VideoPlayerController.file(widget.file)
        ..initialize().then((_) => setState(() {}))
        ..setLooping(true)
        ..play();
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _openPrivacy() async {
     final result = await Navigator.push(context, MaterialPageRoute(
       builder: (_) => StatusPrivacyScreen(
         currentPrivacy: _privacy, 
         currentAllowed: _allowedUsers, 
         currentExcluded: _excludedUsers
       )
     ));
     
     if (result != null && result is Map) {
        setState(() {
           _privacy = result['privacy'];
           _allowedUsers = result['allowed'];
           _excludedUsers = result['excluded'];
        });
     }
  }

  Future<void> _send() async {
     setState(() => _isSending = true);
     try {
       await _statusService.createMediaStatus(
         file: widget.file,
         isVideo: widget.type == 'video',
         caption: _captionController.text.trim(),
         privacy: _privacy,
         allowedUsers: _allowedUsers,
         excludedUsers: _excludedUsers
       );
       
       if (mounted) {
         Navigator.pop(context); // Always close preview
         if (widget.comeFromCamera && Navigator.canPop(context)) {
            Navigator.pop(context); // Also close camera if it's there
         }
       }
     } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed: $e")));
     } finally {
       if (mounted) setState(() => _isSending = false);
     }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Media Preview
          Center(
             child: widget.type == 'video'
               ? (_videoController != null && _videoController!.value.isInitialized
                   ? AspectRatio(
                       aspectRatio: _videoController!.value.aspectRatio,
                       child: VideoPlayer(_videoController!)
                     )
                   : const CircularProgressIndicator())
               : Image.file(widget.file)
          ),

          // Top Bar
          Positioned(
            top: 40, left: 10,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          
          // Privacy Chip (Above caption)
          Positioned(
            bottom: 80, left: 10,
            child: GestureDetector(
                onTap: _openPrivacy,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24)
                  ),
                  child: Row(
                    children: [
                       Text(
                         _privacy == 'contacts' ? 'Status (Contacts)' 
                         : (_privacy == 'exclude' ? 'Status (Excluded)' : 'Status (Selected)'),
                         style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)
                       ),
                       const SizedBox(width: 4),
                       const Icon(Icons.arrow_drop_down, color: Colors.white, size: 16)
                    ],
                  ),
                ),
              )
          ),
          
          // Bottom Caption & Send
          Positioned(
            bottom: 20, left: 10, right: 10,
            child: Row(
               children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(25)
                      ),
                      child: TextField(
                        controller: _captionController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Add a caption...',
                          hintStyle: TextStyle(color: Colors.white70),
                          border: InputBorder.none
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FloatingActionButton(
                    backgroundColor: const Color(0xFF7E57C2),
                    onPressed: _isSending ? null : _send,
                    child: _isSending 
                       ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                       : const Icon(Icons.send, color: Colors.white),
                  )
               ],
            ),
          )
        ],
      ),
    );
  }
}
