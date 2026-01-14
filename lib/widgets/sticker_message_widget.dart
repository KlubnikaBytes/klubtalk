import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

class StickerMessageWidget extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;

  const StickerMessageWidget({super.key, required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    // 🧠 Sticker Parsing Logic
    // Content should be the URL
    final String url = message['content'] ?? message['url'] ?? '';
    final String timestamp = message['timestamp'] ?? DateTime.now().toIso8601String();
    final DateTime time = DateTime.parse(timestamp).toLocal();
    final String timeStr = DateFormat('h:mm a').format(time);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      // NO BUBBLE: Transparent background, no padding, no decoration
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          GestureDetector(
             onLongPress: () {
                // TODO: Show context menu (Favorite/Delete)
             },
             child: CachedNetworkImage(
               imageUrl: url,
               width: 140, // Nice reasonable size for stickers
               height: 140,
               fit: BoxFit.contain,
               placeholder: (context, url) => Container(
                   width: 140, height: 140, 
                   alignment: Alignment.center,
                   child: const CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9575CD)))
               ),
               errorWidget: (context, url, error) => const Icon(Icons.broken_image, size: 50, color: Colors.grey),
             ),
          ),
          // Time layout similar to WhatsApp: Floating slightly or just below?
          // WhatsApp stickers have time floating at bottom right corner usually with a shadow or background if needed.
          // But simpler implementation is just below.
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 4, left: 4),
            child: Row(
               mainAxisSize: MainAxisSize.min,
               children: [
                 Text(
                   timeStr,
                   style: const TextStyle(fontSize: 10, color: Colors.grey),
                 ),
                 if (isMe) ...[
                   const SizedBox(width: 4),
                   const Icon(Icons.done_all, size: 14, color: Colors.blueAccent) // Blue ticks for now
                 ]
               ],
            ),
          )
        ],
      ),
    );
  }
}
