
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:whatsapp_clone/services/status_service.dart';

class StatusMediaPreviewScreen extends StatefulWidget {
  final File file;
  final String type; // 'image' or 'video'

  const StatusMediaPreviewScreen({super.key, required this.file, required this.type});

  @override
  State<StatusMediaPreviewScreen> createState() => _StatusMediaPreviewScreenState();
}

class _StatusMediaPreviewScreenState extends State<StatusMediaPreviewScreen> {
  final TextEditingController _captionController = TextEditingController();
  final StatusService _statusService = StatusService();
  VideoPlayerController? _videoController;
  bool _isSending = false;

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

  Future<void> _send() async {
     setState(() => _isSending = true);
     try {
       await _statusService.createMediaStatus(
         file: widget.file,
         isVideo: widget.type == 'video',
         caption: _captionController.text.trim()
       );
       
       if (mounted) {
         Navigator.pop(context); // Close Preview
         Navigator.pop(context); // Close Camera
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
