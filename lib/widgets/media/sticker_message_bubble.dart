
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';

class StickerMessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;

  const StickerMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final content = message['content'] ?? message['originalUrl'] ?? '';
    final String timestamp = message['timestamp'] != null 
        ? DateFormat('h:mm a').format(DateTime.parse(message['timestamp']).toLocal()) 
        : '';
    
    // Check for Lottie mime type
    final bool isLottie = (message['mime'] == 'application/json') || (content.endsWith('.json'));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
           GestureDetector(
             onLongPress: () {
               // Options: Save, Favorite, etc.
             },
             child: Container(
               width: 140,
               height: 140,
               color: Colors.transparent,
               child: isLottie 
                 ? Lottie.network(
                     content,
                     width: 140,
                     height: 140,
                     fit: BoxFit.contain,
                     errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.broken_image, size: 40, color: Colors.grey);
                     },
                   )
                 : CachedNetworkImage(
                     imageUrl: content,
                     fit: BoxFit.contain,
                     placeholder: (_, __) => const Padding(
                        padding: EdgeInsets.all(40.0),
                        child: CircularProgressIndicator(strokeWidth: 2),
                     ),
                     errorWidget: (_, __, ___) => const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                   ),
             ),
           ),
           Padding(
             padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
             child: Text(
               timestamp,
               style: const TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.bold),
             ),
           )
        ],
      ),
    );
  }
}
