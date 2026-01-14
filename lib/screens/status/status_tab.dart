
import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:whatsapp_clone/models/status_model.dart';
import 'package:whatsapp_clone/services/status_service.dart';
import 'package:whatsapp_clone/widgets/avatar_widget.dart';

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
      return const Center(child: CircularProgressIndicator(color: Color(0xFF7E57C2)));
    }

    return ListView(
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
          ))
        ],
        
        if (_statusService.recentUpdates.isEmpty && _statusService.viewedUpdates.isEmpty)
           const Padding(
             padding: EdgeInsets.all(30),
             child: Center(child: Text("No recent updates", style: TextStyle(color: Colors.grey))),
           )
      ],
    );
  }

  Widget _buildMyStatusTile() {
    final myStatus = _statusService.myStatus;

    return ListTile(
      leading: Stack(
        children: [
          _StatusRing(
            count: myStatus?.statuses.length ?? 0,
            isViewed: false, 
            isEmpty: myStatus == null || myStatus.statuses.isEmpty,
            child: AvatarWidget(
              imageUrl: myStatus?.userAvatar ?? '', 
              radius: 26, 
            ),
          ),
          if (myStatus == null || myStatus.statuses.isEmpty)
            Positioned(
              bottom: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.add_circle, color: Color(0xFF7E57C2), size: 20),
              )
            )
        ],
      ),
      title: const Text("My Status", style: TextStyle(fontWeight: FontWeight.bold)),
      subtitle: const Text("Tap to add status update"),
      onTap: () {
         if (myStatus != null && myStatus.statuses.isNotEmpty) {
             Navigator.push(context, MaterialPageRoute(
               builder: (_) => StatusViewerScreen(userStatus: myStatus, onViewStatus: (id) {}) // My status logic
             ));
         } else {
           _showCreateOptions(context);
         }
      },
      trailing: IconButton(
        icon: const Icon(Icons.camera_alt, color: Color(0xFF7E57C2)),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CameraStatusScreen())),
      ),
    );
  }

  void _showCreateOptions(BuildContext context) {
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
               leading: const CircleAvatar(backgroundColor: Color(0xFF7E57C2), child: Icon(Icons.camera_alt, color: Colors.white)),
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

  const StatusTile({super.key, required this.userStatus, required this.isViewed});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _StatusRing(
        count: userStatus.statuses.length,
        isViewed: isViewed,
        child: AvatarWidget(imageUrl: userStatus.userAvatar ?? '', radius: 26),
      ),
      title: Text(userStatus.userName, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(_formatTime(userStatus.lastUpdate)),
      onTap: () {
         Navigator.push(context, MaterialPageRoute(
           builder: (_) => StatusViewerScreen(
             userStatus: userStatus,
             onViewStatus: StatusService().viewStatus
           )
         ));
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
  final Widget child;

  const _StatusRing({required this.count, required this.isViewed, required this.child, this.isEmpty = false});

  @override
  Widget build(BuildContext context) {
    if (isEmpty) return child;

    return CustomPaint(
      painter: _RingPainter(count: count, color: isViewed ? Colors.grey : const Color(0xFF7E57C2)),
      child: Container(
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
