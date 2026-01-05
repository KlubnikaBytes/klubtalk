import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class AudioMessageBubble extends StatefulWidget {
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
  State<AudioMessageBubble> createState() => _AudioMessageBubbleState();
}

class _AudioMessageBubbleState extends State<AudioMessageBubble> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    // Initialize with passed duration
    _duration = Duration(seconds: widget.durationSeconds);

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) {
        setState(() {
          _position = newPosition;
        });
      }
    });
    
    _audioPlayer.onDurationChanged.listen((newDuration) {
       if (newDuration !=  null && mounted) {
         setState(() => _duration = newDuration);
       }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play(UrlSource(widget.audioUrl));
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isSender ? Colors.white : Colors.black;
    
    return Container(
      width: 250,
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: widget.isSender ? const Color(0xFF7E57C2) : Colors.grey[400], // Darker purple for sender contrast
            radius: 20,
            child: IconButton(
              icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
              color: Colors.white,
              onPressed: _togglePlay,
            ),
          ),
          Expanded(
            child: SliderTheme(
               data: SliderTheme.of(context).copyWith(
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                  trackHeight: 2,
               ),
               child: Slider(
                min: 0,
                max: _duration.inSeconds.toDouble(),
                value: _position.inSeconds.toDouble().clamp(0, _duration.inSeconds.toDouble()),
                activeColor: widget.isSender ? Colors.white : const Color(0xFF9575CD),
                inactiveColor: widget.isSender ? Colors.white38 : Colors.grey[300],
                onChanged: (value) {
                  _audioPlayer.seek(Duration(seconds: value.toInt()));
                },
              ),
            ),
          ),
          Text(
            _formatDuration(_isPlaying ? _position : _duration),
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}
