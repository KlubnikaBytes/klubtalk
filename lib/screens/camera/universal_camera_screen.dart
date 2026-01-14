import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:whatsapp_clone/screens/camera/media_preview_screen.dart';
import 'dart:io';
import 'dart:typed_data';

class UniversalCameraScreen extends StatefulWidget {
  const UniversalCameraScreen({super.key});

  @override
  State<UniversalCameraScreen> createState() => _UniversalCameraScreenState();
}

class _UniversalCameraScreenState extends State<UniversalCameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isRecording = false;
  int _selectedCameraIndex = 0;
  FlashMode _flashMode = FlashMode.off;

  List<AssetEntity> _recentMedia = [];
  bool _isLoadingGallery = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    _loadGallery();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;

      _startCamera(_selectedCameraIndex);
    } catch (e) {
      debugPrint("Camera init error: $e");
    }
  }

  Future<void> _startCamera(int index) async {
    final camera = _cameras[index];
    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: true,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.jpeg : ImageFormatGroup.bgra8888,
    );

    try {
      await _controller!.initialize();
      await _controller!.setFlashMode(_flashMode);
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _selectedCameraIndex = index;
        });
      }
    } catch (e) {
      debugPrint("Camera controller error: $e");
    }
  }

  Future<void> _loadGallery() async {
    // Request permission using photo_manager
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth && !ps.hasAccess) return;

    final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      onlyAll: true,
    );

    if (albums.isNotEmpty) {
      final List<AssetEntity> media = await albums[0].getAssetListPaged(
        page: 0,
        size: 20,
      );
      if (mounted) {
        setState(() {
          _recentMedia = media;
          _isLoadingGallery = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoadingGallery = false);
    }
  }

  void _switchCamera() {
    if (_cameras.isEmpty) return;
    int newIndex = (_selectedCameraIndex + 1) % _cameras.length;
    _startCamera(newIndex);
  }

  void _toggleFlash() {
    if (_controller == null) return;
    FlashMode nextMode;
    if (_flashMode == FlashMode.off) {
      nextMode = FlashMode.torch;
    } else {
      nextMode = FlashMode.off;
    }
    _controller!.setFlashMode(nextMode);
    setState(() => _flashMode = nextMode);
  }

  Future<void> _takePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized || _isRecording) return;

    try {
      final XFile photo = await _controller!.takePicture();
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => MediaPreviewScreen(filePath: photo.path, isVideo: false)));
      }
    } catch (e) {
      debugPrint("Take photo error: $e");
    }
  }

  Future<void> _startVideo() async {
    if (_controller == null || !_controller!.value.isInitialized || _controller!.value.isRecordingVideo) return;

    try {
      await _controller!.startVideoRecording();
      setState(() => _isRecording = true);
    } catch (e) {
      debugPrint("Start video error: $e");
    }
  }

  Future<void> _stopVideo() async {
    if (_controller == null || !_isRecording) return;

    try {
      final XFile video = await _controller!.stopVideoRecording();
      setState(() => _isRecording = false);
       if (mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => MediaPreviewScreen(filePath: video.path, isVideo: true)));
      }
    } catch (e) {
      debugPrint("Stop video error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator()));

    // Get Aspect Ratio from Controller
    final size = MediaQuery.of(context).size;
    var scale = _controller!.value.aspectRatio * size.aspectRatio;
    if (scale < 1) scale = 1 / scale;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Camera Preview - Full Screen Transformation
          Transform.scale(
            scale: scale,
            child: Center(
              child: CameraPreview(_controller!),
            ),
          ),

          // 2. Top Controls (Back, Flash)
          Positioned(
            top: 40,
            left: 10,
            right: 10,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
                IconButton(
                  icon: Icon(_flashMode == FlashMode.off ? Icons.flash_off : Icons.flash_on, color: Colors.white, size: 28),
                  onPressed: _toggleFlash,
                ),
              ],
            ),
          ),

          // 3. Bottom Area: Gallery + Shutter + Switch
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.only(bottom: 20, top: 10),
              color: Colors.black.withOpacity(0.4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   // Recent Gallery Row
                  if (_recentMedia.isNotEmpty)
                    SizedBox(
                      height: 70,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _recentMedia.length,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: GestureDetector(
                              onTap: () async {
                                final File? file = await _recentMedia[index].file;
                                if (file != null && mounted) {
                                    final bool isVideo = _recentMedia[index].type == AssetType.video;
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => MediaPreviewScreen(filePath: file.path, isVideo: isVideo)));
                                }
                              },
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                child: FutureBuilder<Uint8List?>(
                                  future: _recentMedia[index].thumbnailData,
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
                                      return Image.memory(
                                        snapshot.data!,
                                        fit: BoxFit.cover,
                                        gaplessPlayback: true,
                                      );
                                    }
                                    return Container(color: Colors.grey[900]);
                                  },
                                ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  
                  const SizedBox(height: 15),

                  // Controls Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Placeholder/Action
                       IconButton(
                        icon: const Icon(Icons.photo_library, color: Colors.white, size: 28),
                        onPressed: () {
                           // Open Full Gallery if needed?
                           // For now just the icon as visual balance or future feature
                        },
                      ),
                      
                      // Shutter Button
                      GestureDetector(
                        onTap: _takePhoto,
                        onLongPress: _startVideo,
                        onLongPressUp: _stopVideo,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 70, 
                              height: 70,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 4),
                              ),
                            ),
                            if (_isRecording)
                               Container(
                                width: 35, height: 35,
                                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                               )
                            else
                               Container(
                                width: 62, height: 62,
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.0), shape: BoxShape.circle),
                               ),
                          ],
                        ),
                      ),

                      // Switch Camera
                      IconButton(
                        icon: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 28),
                        onPressed: _switchCamera,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
