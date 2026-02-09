import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:whatsapp_clone/models/status_model.dart';
import 'package:whatsapp_clone/services/status_service.dart';
import 'package:whatsapp_clone/widgets/avatar_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';

// Screens
import 'package:whatsapp_clone/screens/status/text_status_screen.dart';
import 'package:whatsapp_clone/screens/status/camera_status_screen.dart';
import 'package:whatsapp_clone/screens/status/status_media_preview_screen.dart';
import 'package:whatsapp_clone/screens/status/status_viewer_screen.dart';

class StatusTab extends StatefulWidget {
  const StatusTab({super.key});

  @override
  State<StatusTab> createState() => _StatusTabState();
}

class _StatusTabState extends State<StatusTab> {
  final StatusService _statusService = StatusService();

  @override
  void initState() {
    super.initState();
    _statusService.fetchFeed();
    _statusService.initSocketListeners(); // Bind Socket Events
    _statusService.addListener(_update);
  }

  @override
  void dispose() {
    _statusService.removeListener(_update);
    super.dispose();
  }

  void _update() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_statusService.isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFC92136)));
    }

    return Scaffold( 
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: _statusService.fetchFeed,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 80), // Space for FAB
          children: [
            // 1. My Status
            _buildMyStatusTile(),
            
            const SizedBox(height: 10),
            
            // 2. Recent Updates
            if (_statusService.recentUpdates.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text("Recent updates", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13)),
              ),
              ..._statusService.recentUpdates.map((userStatus) => StatusTile(
                userStatus: userStatus,
                isViewed: false,
                onUpdate: _statusService.fetchFeed,
              ))
            ],

            // 3. Viewed Updates
            if (_statusService.viewedUpdates.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text("Viewed updates", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13)),
              ),
              ..._statusService.viewedUpdates.map((userStatus) => StatusTile(
                userStatus: userStatus,
                isViewed: true,
                onUpdate: _statusService.fetchFeed,
              ))
            ],
            
            // 4. Muted Updates
            if (_statusService.mutedUpdates.isNotEmpty) ...[
               _buildMutedUpdates(),
            ],

            if (_statusService.recentUpdates.isEmpty && _statusService.viewedUpdates.isEmpty && _statusService.mutedUpdates.isEmpty)
               const Padding(
                 padding: EdgeInsets.all(30),
                 child: Center(child: Text("No recent updates", style: TextStyle(color: Colors.grey))),
               )
          ],
        ),
      ),
    );
  }

  Widget _buildMutedUpdates() {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: const Text("Muted updates", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
        children: _statusService.mutedUpdates.map((s) => StatusTile(
          userStatus: s, 
          isViewed: false, // Muted usually appear somewhat dim, but logic is same
          onUpdate: _statusService.fetchFeed
        )).toList(),
      ),
    );
  }

  Widget _buildMyStatusTile() {
    final myStatus = _statusService.myStatus;
    final hasStatus = myStatus != null && myStatus.statuses.isNotEmpty;
    
    // Thumbnail Logic: Last status content if image/video, else Profile Pic
    Widget? thumbnail;
    if (hasStatus) {
       final last = myStatus!.statuses.last;
       if (last.type == 'image') {
          thumbnail = CachedNetworkImage(imageUrl: last.content, fit: BoxFit.cover, width: 50, height: 50);
       } else if (last.type == 'video') {
          // Video: Show generic or profile pic with icon? 
          // WhatsApp shows video thumb. We don't have it.
          // Fallback to Profile Pic but maybe add an icon overlay?
          // Or just Profile Pic.
       }
    }

    return ListTile(
      leading: Stack(
        children: [
          _StatusRing(
            count: myStatus?.statuses.length ?? 0,
            isViewed: false, 
            isEmpty: !hasStatus,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: thumbnail ?? AvatarWidget(
                imageUrl: myStatus?.userAvatar ?? '', 
                radius: 26, 
              ),
            ),
          ),
          if (!hasStatus)
            Positioned(
              bottom: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.add_circle, color: Color(0xFFC92136), size: 20),
              )
            )
        ],
      ),
      title: const Text("My Status", style: TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(hasStatus ? "Tap to view updates" : "Tap to add status update"),
      onTap: () {
         if (hasStatus) {
             Navigator.push(context, MaterialPageRoute(
               builder: (_) => StatusViewerScreen(
                   allStatuses: [myStatus!], 
                   initialIndex: 0, 
                   onViewStatus: (id) => _statusService.viewStatus(id)
               )
             ));
         } else {
           // Fix: Directly open Camera
           Navigator.push(context, MaterialPageRoute(builder: (_) => const CameraStatusScreen()));
         }
      },
      trailing: PopupMenuButton<String>(
        onSelected: (val) {
           if (val == 'camera') {
             Navigator.push(context, MaterialPageRoute(builder: (_) => const CameraStatusScreen()));
           } else if (val == 'text') {
             Navigator.push(context, MaterialPageRoute(builder: (_) => const TextStatusScreen()));
           }
        },
        itemBuilder: (_) => [
           const PopupMenuItem(value: 'camera', child: Text("Camera")),
           const PopupMenuItem(value: 'text', child: Text("Text Status")),
        ],
        child: const Padding(
           padding: EdgeInsets.all(8.0),
           child: Icon(Icons.more_horiz, color: Color(0xFFC92136)),
        ),
      ),
    );
  }

  void _showCreateOptions(BuildContext context) {
    // Kept for other entry points if needed, but FAB/MyStatus now bypass it.
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
           color: Colors.white,
           borderRadius: BorderRadius.vertical(top: Radius.circular(20))
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             const SizedBox(height: 10),
             ListTile(
               leading: const CircleAvatar(backgroundColor: Color(0xFFC92136), child: Icon(Icons.camera_alt, color: Colors.white)),
               title: const Text('Camera'),
               onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CameraStatusScreen()));
               },
             ),
             ListTile(
               leading: const CircleAvatar(backgroundColor: Colors.pink, child: Icon(Icons.image, color: Colors.white)),
               title: const Text('Gallery'),
               onTap: () async {
                  Navigator.pop(context);
                  final picker = ImagePicker();
                  final XFile? media = await picker.pickMedia();
                  if (media != null && context.mounted) {
                      final type = media.path.endsWith('.mp4') ? 'video' : 'image';
                      Navigator.push(context, MaterialPageRoute(builder: (_) => StatusMediaPreviewScreen(file: File(media.path), type: type)));
                  }
               },
             ),
             ListTile(
               leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.edit, color: Colors.white)),
               title: const Text('Text'),
               onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const TextStatusScreen()));
               },
             ),
             const SizedBox(height: 20),
          ],
        ),
      )
    );
  }
}

class StatusTile extends StatelessWidget {
  final UserStatus userStatus;
  final bool isViewed;
  final VoidCallback? onUpdate;

  const StatusTile({super.key, required this.userStatus, required this.isViewed, this.onUpdate});

  @override
  Widget build(BuildContext context) {
    // Determine thumbnail
    Widget? thumbnail;
    if (userStatus.statuses.isNotEmpty) {
       final last = userStatus.statuses.last;
       if (last.type == 'image') {
          thumbnail = CachedNetworkImage(
            imageUrl: last.content, 
            fit: BoxFit.cover, 
            width: 50, 
            height: 50,
            placeholder: (_,__) => Container(color: Colors.grey[200]),
            errorWidget: (_,__,___) => const Icon(Icons.error),
          );
       } else if (last.type == 'text') {
           // Text Status Thumbnail
           Color bgColor = const Color(0xFF7E57C2);
           try {
             if (last.backgroundColor.startsWith('#')) {
               bgColor = Color(int.parse(last.backgroundColor.replaceAll('#', '0xFF')));
             }
           } catch (_) {}
           thumbnail = Container(
             color: bgColor,
             child: Center(child: Text(last.content, style: const TextStyle(fontSize: 8, color: Colors.white), overflow: TextOverflow.ellipsis)),
           );
       }
    }

    return ListTile(
      leading: _StatusRing(
        count: userStatus.statuses.length,
        isViewed: isViewed,
        isMuted: userStatus.isMuted,
        child: ClipRRect(
           borderRadius: BorderRadius.circular(26),
           child: thumbnail ?? AvatarWidget(imageUrl: userStatus.userAvatar ?? '', radius: 26)
        ),
      ),
      title: Text(userStatus.userName, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(_formatTime(userStatus.lastUpdate)),
           onTap: () {
          // Pass the list this status belongs to (Recent, Viewed, Muted?)
          // We need to know which list context we are in.
          // For simplicity, we can merge all relevant lists or pass the specific list context.
          // Since we want next/prev in the same "section", let's reconstruct the list context.
          
          List<UserStatus> contextList;
          if (isViewed) {
             contextList = StatusService().viewedUpdates;
          } else if (userStatus.isMuted) {
             contextList = StatusService().mutedUpdates;
          } else {
             contextList = StatusService().recentUpdates;
          }
          
          final index = contextList.indexOf(userStatus);
          
          Navigator.push(context, MaterialPageRoute(
           builder: (_) => StatusViewerScreen(
             allStatuses: contextList,
             initialIndex: index != -1 ? index : 0,
             onViewStatus: StatusService().viewStatus
           )
         )).then((_) => onUpdate?.call());
      },
      onLongPress: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(userStatus.isMuted ? "Unmute ${userStatus.userName}?" : "Mute ${userStatus.userName}?"),
             content: Text(userStatus.isMuted 
                ? "New status updates from ${userStatus.userName} will appear under recent updates." 
                : "New status updates from ${userStatus.userName} will appear under muted updates."),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  if (userStatus.isMuted) {
                    StatusService().unmuteUser(userStatus.userId).then((_) => onUpdate?.call());
                  } else {
                    StatusService().muteUser(userStatus.userId).then((_) => onUpdate?.call());
                  }
                },
                child: Text(userStatus.isMuted ? "Unmute" : "Mute"),
              ),
            ],
          ),
        );
      },
    );
  }
  
  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return "${diff.inMinutes} minutes ago";
    if (diff.inHours < 24) return "${diff.inHours} hours ago";
    return "Yesterday";
  }
}

class _StatusRing extends StatelessWidget {
  final int count;
  final bool isViewed;
  final bool isEmpty;
  final bool isMuted;
  final Widget child;

  const _StatusRing({
    required this.count, 
    required this.isViewed, 
    required this.child, 
    this.isEmpty = false,
    this.isMuted = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isEmpty) return child;

    return CustomPaint(
      painter: _RingPainter(
        count: count, 
        color: isMuted ? Colors.grey : (isViewed ? Colors.grey : const Color(0xFFC92136))
      ),
      child: Container(
        width: 52, height: 52,
        padding: const EdgeInsets.all(4), 
        child: child,
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final int count;
  final Color color;

  _RingPainter({required this.count, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final double gap = count > 1 ? pi / (10 * count) : 0; 
    final double sweepAngle = (2 * pi - (count * gap)) / count;
    final Rect rect = Rect.fromLTWH(0, 0, size.width, size.height);

    if (count == 1) {
       canvas.drawArc(rect, 0, 2 * pi, false, paint);
    } else {
       for (int i = 0; i < count; i++) {
         double startAngle = -pi / 2 + i * (sweepAngle + gap);
         canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
       }
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) => oldDelegate.count != count || oldDelegate.color != color;
}
