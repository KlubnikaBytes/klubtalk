import 'dart:async';
import 'package:flutter/material.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

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
  // --- SINGLETON PLAYBACK MANAGER ---
  // Tracks the currently playing audio element to stop it when a new one starts.
  static html.AudioElement? _activelyPlayingAudio;
  static Function? _stopActivePlayerUI;

  html.AudioElement? _webAudio;
  bool _isPlaying = false;
  double _currentPosition = 0;
  double _totalDuration = 0;
  StreamSubscription? _timeUpdateSub;
  StreamSubscription? _endedSub;
  StreamSubscription? _loadedMetadataSub;

  @override
  void initState() {
    super.initState();
    _initWebAudio();
  }

  @override
  void didUpdateWidget(CrossPlatformAudioPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If URL changed (e.g. reused widget), we MUST re-init
    if (widget.url != oldWidget.url) {
      _webAudio?.pause();
      _webAudio?.remove();
      _timeUpdateSub?.cancel();
      _endedSub?.cancel();
      _loadedMetadataSub?.cancel();
      _isPlaying = false;
      _currentPosition = 0;
      _initWebAudio();
    }
  }

  void _initWebAudio() {
    // Create the audio element IN MEMORY (or hidden).
    // We do NOT enable controls, so the browser native UI never renders.
    final divId = 'audio-${DateTime.now().millisecondsSinceEpoch}-${widget.url.hashCode}';
    
    _webAudio = html.AudioElement()
      ..src = widget.url
      ..controls = false // CRITICAL: Suppress native UI
      ..autoplay = false
      ..id = divId
      ..style.display = 'none'; // CRITICAL: Ensure invisible

    // Append to body to ensure browser resource management works, but keep hidden.
    html.document.body!.append(_webAudio!);

    // Listen to metadata to get duration
    _loadedMetadataSub = _webAudio!.onLoadedMetadata.listen((_) {
      if (mounted) {
        setState(() {
          _totalDuration = _webAudio!.duration.toDouble();
          if (_totalDuration.isInfinite || _totalDuration.isNaN) _totalDuration = 0;
        });
      }
    });

    // Listen to playback progress
    _timeUpdateSub = _webAudio!.onTimeUpdate.listen((_) {
      if (mounted && !_isSeeking) {
        setState(() {
          _currentPosition = _webAudio!.currentTime.toDouble();
        });
      }
    });

    // Reset when finished
    _endedSub = _webAudio!.onEnded.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _currentPosition = 0;
          _webAudio!.currentTime = 0;
        });
      }
    });
  }

  // Helper to stop this player from the static manager
  void _forceStop() {
    if (_webAudio != null) {
      _webAudio!.pause();
    }
    if (mounted) {
      setState(() {
        _isPlaying = false;
      });
    }
  }

  void _togglePlayPause() {
    if (_webAudio == null) return;

    if (_isPlaying) {
      // Pause current
      _webAudio!.pause();
      setState(() => _isPlaying = false);
    } else {
      // STOP OTHERS before playing
      if (_activelyPlayingAudio != null && _activelyPlayingAudio != _webAudio) {
        // Call the UI updater of the previous player
        _stopActivePlayerUI?.call();
        _activelyPlayingAudio!.pause();
      }

      // Set self as active
      _activelyPlayingAudio = _webAudio;
      _stopActivePlayerUI = _forceStop;

      _webAudio!.play();
      setState(() => _isPlaying = true);
    }
  }

  bool _isSeeking = false;

  void _onSeekStart(double value) {
    _isSeeking = true;
  }

  void _onSeekEnd(double value) {
    _isSeeking = false;
    if (_webAudio != null) {
      _webAudio!.currentTime = value;
    }
  }
  
  void _onSeekChanged(double value) {
     setState(() {
       _currentPosition = value;
     });
  }

  String _formatDuration(double seconds) {
    if (seconds.isNaN || seconds.isInfinite) return "0:00";
    int s = seconds.toInt();
    int m = s ~/ 60;
    s = s % 60;
    return '${m.toString()}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timeUpdateSub?.cancel();
    _endedSub?.cancel();
    _loadedMetadataSub?.cancel();
    
    // If we are the active player, clear the global reference so we don't hold memory
    if (_activelyPlayingAudio == _webAudio) {
      _activelyPlayingAudio = null;
      _stopActivePlayerUI = null;
    }

    _webAudio?.pause();
    _webAudio?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // UI: WhatsApp Style Inline Player
    // [Play/Pause] [---------O-------] [0:00]
    
    final duration = _totalDuration > 0 ? _totalDuration : 0.0;
    final position = _currentPosition > duration ? duration : _currentPosition;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Play/Pause Button
        GestureDetector(
          onTap: _togglePlayPause,
          child: Icon(
            _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: widget.contentColor,
            size: 32,
          ),
        ),
        
        const SizedBox(width: 8),

        // Progress Slider
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
              value: position,
              min: 0.0,
              max: duration > 0 ? duration : 1.0, // Prevent /0 or min=max
              onChangeStart: _onSeekStart,
              onChanged: _onSeekChanged,
              onChangeEnd: _onSeekEnd,
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Duration / Timer
        Text(
          _formatDuration(position),
          style: TextStyle(
            color: widget.contentColor,
            fontSize: 13,
            fontFamily: 'Helvetica', // or default
            fontWeight: FontWeight.w500,
          ),
        ),
         const SizedBox(width: 4),
      ],
    );
  }
}
