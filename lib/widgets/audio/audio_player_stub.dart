import 'package:flutter/material.dart';

class CrossPlatformAudioPlayer extends StatefulWidget {
  final String url;
  final Color contentColor;

  const CrossPlatformAudioPlayer({
    super.key, 
    required this.url,
    this.contentColor = const Color(0xFF54656F),
  });

  @override
  State<CrossPlatformAudioPlayer> createState() => throw UnimplementedError();
}
