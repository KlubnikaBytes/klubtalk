import 'package:flutter/material.dart';
import 'package:whatsapp_clone/widgets/media/image_bubble_widget.dart';
import 'package:whatsapp_clone/widgets/media/video_bubble_widget.dart';
import 'package:whatsapp_clone/widgets/media/document_bubble_widget.dart';

class MediaBubbleWidget extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;

  const MediaBubbleWidget({
    super.key,
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Get MIME Type (Strict)
    final String type = message['type'] ?? 'file';
    final String mimeType = (message['mimeType'] ?? message['mime'] ?? '').toString().toLowerCase();

    // 2. Route
    print('📊 MediaBubbleWidget DEBUG:');
    print('   Type: $type');
    print('   MimeType: $mimeType');
    print('   Has filename: ${message.containsKey('filename')}');
    
    // VIDEO
    if (type == 'video' || mimeType.startsWith('video/')) {
      print('   → Routing to VideoBubbleWidget');
      return VideoBubbleWidget(message: message, isMe: isMe);
    }

    // IMAGE (Strict: Don't allow video mimes here ever)
    if ((type == 'image' && !mimeType.startsWith('video')) || mimeType.startsWith('image/')) {
      print('   → Routing to ImageBubbleWidget');
      return ImageBubbleWidget(message: message, isMe: isMe);
    }

    // DOCUMENTS / OTHERS
    print('   → Routing to DocumentBubbleWidget');
    return DocumentBubbleWidget(message: message, isMe: isMe);
  }
}
