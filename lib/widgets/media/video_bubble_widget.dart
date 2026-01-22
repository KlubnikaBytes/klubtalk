import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import 'package:whatsapp_clone/config/api_config.dart';
import 'dart:io';

class VideoBubbleWidget extends StatefulWidget {
  final Map<String, dynamic> message;
  final bool isMe;

  const VideoBubbleWidget({
    super.key,
    required this.message,
    required this.isMe,
  });

  @override
  State<VideoBubbleWidget> createState() => _VideoBubbleWidgetState();
}

class _VideoBubbleWidgetState extends State<VideoBubbleWidget> {
  // We don't initialize a full video player in the list for performance. 
  // We use the thumbnail if available, or just a placeholder.
  // Tap to play in full screen.

  String _getFullUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '${ApiConfig.baseUrl}$path';
  }

  void _openFullScreenVideo(BuildContext context) {
    // 1. Get Video URL
    final content = widget.message['content'] ?? widget.message['url'] ?? '';
    final videoUrl = _getFullUrl(content);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FullScreenVideoPlayer(videoUrl: videoUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Try to get preview URL
    final previewUrl = widget.message['previewUrl'] ?? '';
    final fullPreviewUrl = _getFullUrl(previewUrl);

    return GestureDetector(
      onTap: () => _openFullScreenVideo(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 250,
          height: 250,
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
               // 1. Thumbnail
               if (fullPreviewUrl.isNotEmpty)
                 Image.network(
                   fullPreviewUrl,
                   fit: BoxFit.cover,
                   errorBuilder: (c, e, s) => Container(color: Colors.black26),
                 )
               else
                 Container(color: Colors.black26),

               // 2. Play Button details
               Center(
                 child: Container(
                   padding: const EdgeInsets.all(12),
                   decoration: BoxDecoration(
                     color: Colors.black54,
                     borderRadius: BorderRadius.circular(30),
                   ),
                   child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
                 ),
               ),
               
               // 3. Duration / Size info overlay
               Positioned(
                 bottom: 8,
                 left: 8,
                 child: Row(
                   children: [
                     const Icon(Icons.videocam, color: Colors.white70, size: 16),
                     const SizedBox(width: 4),
                     Text(
                       "Video", 
                       style: const TextStyle(color: Colors.white, fontSize: 12)
                     ),
                   ],
                 ),
               ),
               
               // 4. Timestamp & Status Overlay
               Positioned(
                 bottom: 8,
                 right: 8,
                 child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                         Text(
                            DateFormat('h:mm a').format(
                               DateTime.parse(widget.message['timestamp'] ?? widget.message['createdAt'] ?? DateTime.now().toIso8601String()).toLocal()
                            ),
                            style: const TextStyle(color: Colors.white, fontSize: 10)
                         ),
                         if (widget.isMe) ...[
                           const SizedBox(width: 4),
                           Icon(
                             (widget.message['status'] == 'seen' || widget.message['status'] == 'delivered') 
                                 ? Icons.done_all 
                                 : Icons.done,
                             size: 14, 
                             color: widget.message['status'] == 'seen' ? const Color(0xFF53BDEB) : Colors.white
                           )
                         ]
                      ],
                    ),
                 ),
               )
            ],
          ),
        ),
      ),
    );
  }
}

class FullScreenVideoPlayer extends StatefulWidget {
  final String videoUrl;
  const FullScreenVideoPlayer({super.key, required this.videoUrl});

  @override
  State<FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<FullScreenVideoPlayer> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        setState(() {
          _initialized = true;
          _controller.play();
        });
      }).catchError((e) {
         print("Video Init Error: $e");
         setState(() => _error = true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: _error 
          ? const Text("Failed to load video", style: TextStyle(color: Colors.white))
          : _initialized 
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              )
            : const CircularProgressIndicator(),
      ),
      floatingActionButton: _initialized ? FloatingActionButton(
        onPressed: () {
          setState(() {
            _controller.value.isPlaying
                ? _controller.pause()
                : _controller.play();
          });
        },
        child: Icon(
          _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
        ),
      ) : null,
    );
  }
}
