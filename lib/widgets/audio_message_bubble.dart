import 'package:flutter/material.dart';
import 'package:whatsapp_clone/config/api_config.dart';
import 'package:whatsapp_clone/widgets/audio/cross_platform_audio_player.dart';

class AudioMessageBubble extends StatelessWidget {
  final String audioUrl;
  final bool isSender;
  final int durationSeconds;

  const AudioMessageBubble({
    super.key,
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
      // decoration: BoxDecoration(), // REPLACED: Removed background color to use parent's (Purple/White)
      child: CrossPlatformAudioPlayer(
        url: fullUrl, 
        contentColor: isSender ? Colors.white : const Color(0xFF54656F),
      ),
    );
  }
}
