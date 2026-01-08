import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class CrossPlatformAudioPlayer extends StatefulWidget {
  final String url;

  const CrossPlatformAudioPlayer({super.key, required this.url});

  @override
  State<CrossPlatformAudioPlayer> createState() => _CrossPlatformAudioPlayerState();
}

class _CrossPlatformAudioPlayerState extends State<CrossPlatformAudioPlayer> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<PlayerState>? _stateSubscription;
  StreamSubscription<Duration>? _durationSubscription;

  @override
  void initState() {
    super.initState();
    _initMobileAudio();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _stateSubscription?.cancel();
    _durationSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _initMobileAudio() async {
    // Listen to state changes
    _stateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    // Listen to position changes
    _positionSubscription = _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    });

    // Listen to duration changes
    _durationSubscription = _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() {
          _totalDuration = duration;
        });
      }
    });

    try {
      // Audioplayers v5/v6 uses UrlSource
      await _audioPlayer.setSource(UrlSource(widget.url));
    } catch (e) {
      debugPrint("Mobile Audio Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Audio cannot be played on this device')),
        );
      }
    }
  }

  void _togglePlayPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton.icon(
          icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
          label: Text(_isPlaying ? "Pause" : "Play"),
          onPressed: _togglePlayPause,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF075E54), // WhatsApp Green
            foregroundColor: Colors.white,
          ),
        ),
        Slider(
          min: 0,
          max: _totalDuration.inMilliseconds.toDouble(),
          value: _currentPosition.inMilliseconds.clamp(0, _totalDuration.inMilliseconds).toDouble(),
          activeColor: const Color(0xFF075E54),
          inactiveColor: Colors.grey[300],
          onChanged: (value) async {
            final position = Duration(milliseconds: value.toInt());
            await _audioPlayer.seek(position);
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatDuration(_currentPosition), style: const TextStyle(fontSize: 12)),
              Text(_formatDuration(_totalDuration), style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }
}
