// import 'dart:io'; // Removed for Web compatibility
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

class VoiceRecorderWidget extends StatefulWidget {
  final Function(String path, int duration) onRecordingComplete;

  const VoiceRecorderWidget({
    super.key,
    required this.onRecordingComplete,
  });

  @override
  State<VoiceRecorderWidget> createState() => _VoiceRecorderWidgetState();
}

class _VoiceRecorderWidgetState extends State<VoiceRecorderWidget> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  DateTime? _startTime;

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        String? path;
        
        if (!kIsWeb) {
          final location = await getApplicationDocumentsDirectory();
          final name = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
          path = '${location.path}/$name';
        }
        // On Web, path is ignored and a Blob is created automatically.

        await _audioRecorder.start(const RecordConfig(), path: path ?? '');

        setState(() {
          _isRecording = true;
          _startTime = DateTime.now();
        });
        print('Started recording (Web: $kIsWeb)');
      } else {
        if (kDebugMode) print('Permission denied');
      }
    } catch (e) {
      if (kDebugMode) print('Error starting record: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      if (!_isRecording) return;
      
      final path = await _audioRecorder.stop();
      final duration = DateTime.now().difference(_startTime!).inSeconds;

      setState(() {
        _isRecording = false;
      });

      if (path != null) {
        print('Recording stopped, saved to $path');
        widget.onRecordingComplete(path, duration);
      }
    } catch (e) {
       if (kDebugMode) print('Error stopping record: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        if (kIsWeb) {
          // Toggle for Web
          if (_isRecording) {
            await _stopRecording();
          } else {
            await _startRecording();
          }
        } else {
          // Hint for Mobile
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Hold to record'), duration: Duration(milliseconds: 500))
          );
        }
      },
      onLongPress: kIsWeb ? null : _startRecording,
      onLongPressEnd: kIsWeb ? null : (_) => _stopRecording(),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF9575CD), // Purple
          shape: BoxShape.circle,
          boxShadow: [
             if (_isRecording)
               BoxShadow(
                 color: Colors.red.withOpacity(0.5),
                 blurRadius: 10,
                 spreadRadius: 5
               )
          ]
        ),
        child: Icon(
          _isRecording ? Icons.stop : Icons.mic,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
}
