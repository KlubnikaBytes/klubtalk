import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'dart:io' show File; // Import selectively if needed, but risky for web. 
// Better: Don\'t import dart:io at all if possible.
// Actually, for deleteSync we need File.
// We'll use a Conditional Import if strict, but for now let's wrap logic.
// Flutter Web *can* import dart:io but will fail at runtime if used. 
// We will try not to use 'File' type on Web.

class VoiceRecorderService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  Future<bool> checkPermission() async {
    // Permission handler works on mobile. On web, record package handles it or browser prompt.
    if (kIsWeb) return true; 

    final status = await Permission.microphone.status;
    if (status.isGranted) return true;
    final result = await Permission.microphone.request();
    return result.isGranted;
  }

  Future<void> startRecording() async {
    try {
      bool hasPerm = await checkPermission();
      // On web, hasPermission check from package might be needed
      if ((kIsWeb) || (await _audioRecorder.hasPermission())) {
        String path = '';
        
        if (!kIsWeb) {
           final directory = await getTemporaryDirectory();
           path = '${directory.path}/temp_recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
        } else {
           // Web: we interpret empty string or specific name?
           // Record package 5.0.0 signature: start(config, {required path})
           // Passing 'recording.m4a' might be safer than empty string on web
           path = 'recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
        }
        
        // Ensure encoder is supported. On web, AAC might not be supported on all browsers?
        // Let's use auto/default for web if possible, but package config is const.
        // We will try standard first.
        await _audioRecorder.start(const RecordConfig(), path: path);
        _isRecording = true;
      }
    } catch (e) {
      print("Error starting record: $e");
    }
  }

  Future<String?> stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      _isRecording = false;
      return path;
    } catch (e) {
      print("Error stopping record: $e");
      return null;
    }
  }

  Future<void> cancelRecording() async {
     final path = await _audioRecorder.stop();
     _isRecording = false;
     if (!kIsWeb && path != null) {
       // Only delete on mobile
       try {
         final file = File(path);
         if (file.existsSync()) {
           file.deleteSync();
         }
       } catch (e) {
         print("Error deleting temp file: $e");
       }
     }
  }
  
  void dispose() {
    _audioRecorder.dispose();
  }
}
