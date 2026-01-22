import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionHelper {
  static Future<bool> requestContactPermission() async {
    final status = await Permission.contacts.request();
    return status.isGranted;
  }

  static Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  static Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Requests storage permissions based on Android version.
  /// Android 13+ (SDK 33) uses granular media permissions.
  /// Older versions use READ_EXTERNAL_STORAGE.
  static Future<bool> requestMediaPermissions({bool video = false, bool audio = false}) async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      
      if (androidInfo.version.sdkInt >= 33) {
        // Android 13+
        Map<Permission, PermissionStatus> statuses;
        if (video) {
           statuses = await [
            Permission.videos,
            Permission.photos, // Often needed together for gallery pickers
          ].request();
        } else if (audio) {
           statuses = await [
            Permission.audio,
          ].request();
        } else {
           // Images only
           statuses = await [
            Permission.photos,
          ].request();
        }
        
        // Return true if all requested are granted
        return statuses.values.every((s) => s.isGranted);
      } else {
        // Android < 13
        final status = await Permission.storage.request();
        return status.isGranted;
      }
    }
    // iOS or others
    return true;
  }

  static Future<bool> requestManageExternalStorage() async {
     // Usually not needed for simple media apps on Android 11+ unless a file manager
     // But strictly speaking, for "All Files" access:
     if (Platform.isAndroid) {
        return await Permission.manageExternalStorage.request().isGranted;
     }
     return true;
  }
}
