
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:whatsapp_clone/screens/status/status_media_preview_screen.dart';

class CameraStatusScreen extends StatefulWidget {
  const CameraStatusScreen({super.key});

  @override
  State<CameraStatusScreen> createState() => _CameraStatusScreenState();
}

class _CameraStatusScreenState extends State<CameraStatusScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInit = false;
  bool _isRecording = false;
  bool _isFlashOn = false;
  int _selectedCameraIdx = 0;

  // Gallery Strip
  List<AssetEntity> _recentMedia = [];
  bool _isLoadingGallery = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    _fetchGallery(); // Load gallery strip
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.camera,
        Permission.microphone,
      ].request();

      if (statuses[Permission.camera] != PermissionStatus.granted) {
          if (mounted) setState(() => _errorMessage = "Camera permission denied.");
          return;
      }

      _cameras = await availableCameras();
      
      if (_cameras != null && _cameras!.isNotEmpty) {
        int frontIndex = _cameras!.indexWhere((c) => c.lensDirection == CameraLensDirection.front);
        _selectedCameraIdx = frontIndex != -1 ? frontIndex : 0;
        
        _controller = CameraController(
            _cameras![_selectedCameraIdx], 
            ResolutionPreset.high,
            enableAudio: statuses[Permission.microphone] == PermissionStatus.granted
        );
        
        await _controller!.initialize();
        if (mounted) setState(() => _isInit = true);
      } else {
        if (mounted) setState(() => _errorMessage = "No cameras found.");
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = "Init Error: $e");
    }
  }

  Future<void> _fetchGallery() async {
      try {
        final PermissionState ps = await PhotoManager.requestPermissionExtend();
        if (!ps.isAuth && !ps.hasAccess) return;

        final albums = await PhotoManager.getAssetPathList(type: RequestType.common);
        if (albums.isNotEmpty) {
          final recentAlbum = albums.first;
          final media = await recentAlbum.getAssetListRange(start: 0, end: 20);
          if (mounted) setState(() { _recentMedia = media; _isLoadingGallery = false; });
        }
      } catch (_) {}
  }

  void _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;
    _selectedCameraIdx = (_selectedCameraIdx + 1) % _cameras!.length;
    await _controller?.dispose();
    await _initCamera();
  }

  void _toggleFlash() async {
    if (_controller == null) return;
    try {
        _isFlashOn = !_isFlashOn;
        await _controller!.setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
        setState(() {});
    } catch (_) {}
  }

  Future<void> _takePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized || _controller!.value.isTakingPicture) return;
    try {
      final file = await _controller!.takePicture();
      _openPreview(File(file.path), 'image');
    } catch (_) {}
  }

  Future<void> _startVideo() async {
    if (_controller == null || !_controller!.value.isInitialized || _controller!.value.isRecordingVideo) return;
    try {
      await _controller!.startVideoRecording();
      setState(() => _isRecording = true);
    } catch (_) {}
  }

  Future<void> _stopVideo() async {
    if (_controller == null || !_isRecording) return;
    try {
      final file = await _controller!.stopVideoRecording();
      setState(() => _isRecording = false);
      _openPreview(File(file.path), 'video');
    } catch (_) {}
  }
  
  void _openPreview(File file, String type) {
     Navigator.pushReplacement(context, MaterialPageRoute(
       builder: (_) => StatusMediaPreviewScreen(file: file, type: type)
     ));
  }

  void _onGalleryItemTap(AssetEntity asset) async {
     final file = await asset.file;
     if (file != null) {
       _openPreview(file, asset.type == AssetType.video ? 'video' : 'image');
     }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) return Scaffold(backgroundColor: Colors.black, body: Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.white))));
    if (!_isInit || _controller == null) return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator()));

    final size = MediaQuery.of(context).size;
    var scale = 1.0;
    if (_controller!.value.isInitialized) {
      scale = 1 / (_controller!.value.aspectRatio * size.aspectRatio);
      if (scale < 1) scale = 1 / scale;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
           Transform.scale(
              scale: scale,
              alignment: Alignment.center,
              child: Center(child: CameraPreview(_controller!)),
           ),

          // Top Controls
          Positioned(
            top: 40, left: 10, right: 10,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 28), onPressed: () => Navigator.pop(context)),
                IconButton(icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off, color: Colors.white, size: 28), onPressed: _toggleFlash),
              ],
            ),
          ),

          // Bottom Controls & Gallery Strip
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                  // Gallery Strip
                  if (!_isLoadingGallery && _recentMedia.isNotEmpty)
                    Container(
                      height: 80,
                      margin: const EdgeInsets.only(bottom: 20),
                      child: ListView.builder(
                       scrollDirection: Axis.horizontal,
                       itemCount: _recentMedia.length,
                       padding: const EdgeInsets.symmetric(horizontal: 10),
                       itemBuilder: (context, index) {
                         final asset = _recentMedia[index];
                         return GestureDetector(
                           onTap: () => _onGalleryItemTap(asset),
                           child: Container(
                             width: 70,
                             margin: const EdgeInsets.only(right: 8),
                             decoration: BoxDecoration(border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(8)),
                             clipBehavior: Clip.antiAlias,
                             child: FutureBuilder<Uint8List?>(
                               future: asset.thumbnailDataWithSize(const ThumbnailSize.square(150)),
                               builder: (context, snapshot) => snapshot.data != null ? Image.memory(snapshot.data!, fit: BoxFit.cover) : Container(color: Colors.grey[900]),
                             ),
                           ),
                         );
                       },
                    ),
                  ),

                // Shutter & Controls
                Padding(
                  padding: const EdgeInsets.only(bottom: 40, left: 30, right: 30),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                       const SizedBox(width: 28), // Spacer for symmetry (or Gallery Icon)
                       
                       // Shutter
                       GestureDetector(
                         onTap: _takePhoto,
                         onLongPress: _startVideo,
                         onLongPressUp: _stopVideo,
                         child: Container(
                           width: 80, height: 80,
                           decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                              // Purple if recording, transparent otherwise (but WhatsApp is Red recording... User asked for "Purple shutter ring", maybe "Purple recording ring"?)
                              // User: "Purple shutter ring". Usually "Ring around shutter".
                              // Let's make the border Purple on Idle? Or Fill Purple on Recording?
                              // "Purple shutter ring" -> I'll make the border Color(0xFF7E57C2) permanently?
                              // Or simply fill color.
                              // Let's make the Border Default White, but if recording -> Fill Red? Or Purple?
                              // Prompt: "Video progress ring ... Purple shutter ring"
                              // I'll make border Purple.
                              color: _isRecording ? Colors.red : Colors.transparent
                           ),
                           child: Container(
                             margin: const EdgeInsets.all(4),
                             decoration: BoxDecoration(
                               shape: BoxShape.circle,
                               border: Border.all(color: const Color(0xFF7E57C2), width: 2) // Inner purple ring
                             ),
                           ),
                         ),
                       ),
                       
                       IconButton(icon: const Icon(Icons.cameraswitch, color: Colors.white, size: 28), onPressed: _switchCamera),
                    ],
                  ),
                ),
                
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Text("Hold for video, tap for photo", style: TextStyle(color: Colors.white70, fontSize: 12)),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
