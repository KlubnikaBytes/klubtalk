import 'package:flutter/material.dart';
import 'package:whatsapp_clone/config/api_config.dart';
import 'package:whatsapp_clone/widgets/audio/cross_platform_audio_player.dart';

import 'package:intl/intl.dart';

class AudioMessageBubble extends StatelessWidget {
  final Map<String, dynamic> message; // Changed from individual fields to map for flexibility
  final String audioUrl; // Keeping for compatibility or extracting from message
  final bool isSender;
  final int durationSeconds;

  const AudioMessageBubble({
    super.key,
    required this.message,
    required this.audioUrl,
    required this.isSender,
    required this.durationSeconds,
  });

  @override
  Widget build(BuildContext context) {
    // Handle relative URLs
    String fullUrl = audioUrl;
    if (audioUrl.isNotEmpty && !audioUrl.startsWith('http')) {
      fullUrl = '${ApiConfig.baseUrl}$audioUrl';
    }

    return Container(
      width: 250,
      padding: const EdgeInsets.all(8),
      // decoration: BoxDecoration(), 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          CrossPlatformAudioPlayer(
            url: fullUrl, 
            contentColor: isSender ? Colors.white : const Color(0xFF54656F),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
               Text(
                  message['timestamp'] != null 
                     ? DateFormat('h:mm a').format(DateTime.parse(message['timestamp']).toLocal())
                     : '',
                  style: TextStyle(
                    fontSize: 10,
                    color: isSender ? Colors.white70 : Colors.grey[600],
                  ),
               ),
               if (isSender) ...[
                 const SizedBox(width: 4),
                 Icon(
                   (message['status'] == 'seen' || message['status'] == 'delivered') 
                       ? Icons.done_all 
                       : Icons.done,
                   size: 14, 
                   color: message['status'] == 'seen' ? const Color(0xFF53BDEB) : Colors.white70 // White70 matches ChatScreen logic
                 )
               ]
            ],
          )
        ],
      )
    );
  }
}
