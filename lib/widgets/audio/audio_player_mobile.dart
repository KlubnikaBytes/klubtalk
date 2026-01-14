import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class CrossPlatformAudioPlayer extends StatefulWidget {
  final String url;
  final Color contentColor;

  const CrossPlatformAudioPlayer({
    super.key,
    required this.url,
    this.contentColor = const Color(0xFF54656F), // Default WhatsApp Gray
  });

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
  bool _isSeeking = false;

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
      if (mounted && !_isSeeking) {
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
      // Don't show snackbar immediately on load as it might spam if multiple bubbles exist
    }
  }

  void _togglePlayPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.resume();
    }
  }

  void _onSeekStart(double value) {
    _isSeeking = true;
  }

  void _onSeekChanged(double value) {
    setState(() {
      _currentPosition = Duration(milliseconds: value.toInt());
    });
  }

  void _onSeekEnd(double value) async {
    _isSeeking = false;
    final position = Duration(milliseconds: value.toInt());
    await _audioPlayer.seek(position);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    // If implementation needs hours:
    // return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
     final durationMs = _totalDuration.inMilliseconds.toDouble();
     final positionMs = _currentPosition.inMilliseconds.toDouble();
     final safePosition = positionMs > durationMs ? durationMs : positionMs;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: _togglePlayPause,
          child: Icon(
            _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: widget.contentColor,
            size: 32,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              trackHeight: 4,
              thumbColor: widget.contentColor,
              activeTrackColor: widget.contentColor,
              inactiveTrackColor: widget.contentColor.withOpacity(0.3),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: Slider(
              min: 0,
              max: durationMs > 0 ? durationMs : 1.0, 
              value: safePosition.clamp(0, durationMs > 0 ? durationMs : 1.0),
              onChangeStart: _onSeekStart,
              onChanged: _onSeekChanged,
              onChangeEnd: _onSeekEnd,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          _formatDuration(_currentPosition), 
          style: TextStyle(
            color: widget.contentColor, 
            fontSize: 13,
            fontWeight: FontWeight.w500,
          )
        ),
         const SizedBox(width: 4),
      ],
    );
  }
}
