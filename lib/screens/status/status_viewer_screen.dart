
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:whatsapp_clone/models/status_model.dart';
import 'package:whatsapp_clone/services/status_service.dart';
import 'package:whatsapp_clone/widgets/avatar_widget.dart';

class StatusViewerScreen extends StatefulWidget {
  final UserStatus userStatus;
  final Function(String statusId) onViewStatus;

  const StatusViewerScreen({
    super.key, 
    required this.userStatus,
    required this.onViewStatus,
  });

  @override
  State<StatusViewerScreen> createState() => _StatusViewerScreenState();
}

class _StatusViewerScreenState extends State<StatusViewerScreen> with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animController;
  VideoPlayerController? _videoController;
  
  int _currentIndex = 0;
  final Duration _imageDuration = const Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _animController = AnimationController(vsync: this);
    
    _loadStory(0);
    
    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onStoryComplete();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  void _loadStory(int index) {
    _currentIndex = index;
    final status = widget.userStatus.statuses[index];
    
    // Mark Viewed
    widget.onViewStatus(status.id);

    _videoController?.dispose();
    _videoController = null;
    
    if (status.type == 'video') {
       _videoController = VideoPlayerController.networkUrl(Uri.parse(status.content))
         ..initialize().then((_) {
            if (mounted) {
              setState(() {});
              _videoController!.play();
              _animController.duration = _videoController!.value.duration;
              _animController.forward(from: 0);
            }
         });
    } else { // Image or Text
       _animController.duration = _imageDuration;
       _animController.forward(from: 0);
    }
    setState(() {});
  }

  void _onStoryComplete() {
    if (_currentIndex < widget.userStatus.statuses.length - 1) {
       _loadStory(_currentIndex + 1);
    } else {
       Navigator.pop(context); // Close viewer (or auto-nav to next user if implemented)
    }
  }

  void _onTapDown(TapDownDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (details.globalPosition.dx < screenWidth / 3) {
       // Previous
       if (_currentIndex > 0) {
          _loadStory(_currentIndex - 1);
       } else {
          _loadStory(0); // Restart first
       }
    } else {
       // Next
       _onStoryComplete();
    }
  }
  
  void _pause() {
     _animController.stop();
     _videoController?.pause();
  }

  void _resume() {
     _animController.forward();
     _videoController?.play();
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.userStatus.statuses[_currentIndex];
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: _onTapDown,
        onLongPress: _pause,
        onLongPressUp: _resume,
        onVerticalDragEnd: (details) {
           if (details.primaryVelocity! > 0) Navigator.pop(context); // Swipe Down to close
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Content
            _buildContent(status),
            
            // Text Content Overlay (if text status)
            if (status.type == 'text')
               Center(
                 child: Padding(
                   padding: const EdgeInsets.symmetric(horizontal: 40),
                   child: Text(
                     status.content,
                     textAlign: TextAlign.center,
                     style: TextStyle(
                        fontSize: 32, 
                        color: Colors.white,
                        fontFamily: status.caption, // Using caption field for font or map it? Model has font field? 
                        // Ah, schema has font but Status model needs update if accessed. 
                        // For now default.
                     ),
                   ),
                 ),
               ),

            // Top Overlay
            Positioned(
              top: 40, left: 10, right: 10,
              child: Column(
                children: [
                   // Progress Bars
                   Row(
                     children: widget.userStatus.statuses.asMap().entries.map((entry) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: _buildProgressBar(entry.key),
                          ),
                        );
                     }).toList(),
                   ),
                   const SizedBox(height: 10),
                   // User Info
                   Row(
                     children: [
                        AvatarWidget(imageUrl: widget.userStatus.userAvatar ?? '', radius: 20),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             Text(widget.userStatus.userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                             Text(_formatTime(status.createdAt), style: const TextStyle(color: Colors.white70, fontSize: 12))
                          ],
                        )
                     ],
                   )
                ],
              ),
            ),
            
            // Caption Overlay (if media)
            if (status.caption != null && status.type != 'text')
               Positioned(
                 bottom: 20, left: 0, right: 0,
                 child: Text(
                    status.caption!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 18, backgroundColor: Colors.black45),
                 ),
               )
          ],
        ),
      ),
    );
  }

  Widget _buildContent(Status status) {
    if (status.type == 'text') {
       // Parse hex color
       Color bgColor = const Color(0xFF7E57C2);
       try {
          if (status.backgroundColor.startsWith('#')) {
             bgColor = Color(int.parse(status.backgroundColor.replaceAll('#', '0xFF')));
          }
       } catch (_) {}
       return Container(color: bgColor);
    } 
    
    if (status.type == 'video') {
       if (_videoController != null && _videoController!.value.isInitialized) {
          return Center(
             child: AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: VideoPlayer(_videoController!)
             ),
          );
       }
       return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    return CachedNetworkImage(
       imageUrl: status.content,
       fit: BoxFit.contain, // WhatsApp fits contain with black bg usually
       placeholder: (_,__) => const Center(child: CircularProgressIndicator(color: Colors.white)),
       errorWidget: (_,e,trace) => const Icon(Icons.broken_image, color: Colors.white),
    );
  }

  Widget _buildProgressBar(int index) {
      if (index < _currentIndex) {
         return Container(height: 2, color: Colors.white);
      } else if (index > _currentIndex) {
         return Container(height: 2, color: Colors.white24);
      } else {
         return AnimatedBuilder(
           animation: _animController,
           builder: (context, child) {
              return LinearProgressIndicator(
                 value: _animController.value,
                 backgroundColor: Colors.white24,
                 valueColor: const AlwaysStoppedAnimation(Colors.white),
                 minHeight: 2,
              );
           },
         );
      }
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return "${diff.inMinutes} minutes ago";
    return "${diff.inHours} hours ago";
  }
}
