import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:whatsapp_clone/services/webrtc_service.dart';

class CallScreen extends StatefulWidget {
  final String peerName;
  final String peerAvatar; // URL or Initials
  final bool isCaller;
  final String? peerId; // Used if caller
  final bool isVideo; // Initial mode

  const CallScreen({
    super.key,
    required this.peerName,
    required this.peerAvatar,
    this.isCaller = false,
    this.peerId,
    this.isVideo = false,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  final WebrtcService _webrtcService = WebrtcService(); // Singleton

  Timer? _callTimer;
  int _seconds = 0;
  String _status = "Initializing...";
  bool _micEnabled = true;
  bool _videoEnabled = true;

  @override
  void initState() {
    super.initState();
    _initRenderers();
  }
  
  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    
    _webrtcService.onLocalStream = (stream) {
      setState(() => _localRenderer.srcObject = stream);
    };
    
    _webrtcService.onRemoteStream = (stream) {
      setState(() => _remoteRenderer.srcObject = stream);
    };
    
    _webrtcService.onCallStateChange = (status) {
       if (mounted) setState(() => _status = status);
       if (status == "On Call") _startTimer();
       if (status == "Ended" || status == "Rejected") {
          Future.delayed(const Duration(seconds: 1), () { 
             if(mounted) Navigator.pop(context); 
          });
       }
    };
    
    // Start Call Logic
    if (widget.isCaller && widget.peerId != null) {
       _webrtcService.initCall(widget.peerId!, widget.isVideo);
       setState(() => _status = "Calling...");
    } else {
       // Answer logic handled by IncomingCallScreen before pushing this, 
       // but wait - we typically push THIS screen then handle answer.
       // Actually Incoming calls usually passed via 'IncomingCallScreen' 
       // which then navigates here upon ACCEPT.
       // So if !isCaller, we assume call is connected or connecting.
       // We rely on WebrtcService state if already set up.
    }
  }

  void _startTimer() {
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _seconds++);
    });
  }

  String get _formattedDuration {
    final m = (_seconds / 60).floor().toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _callTimer?.cancel();
    // End call if not already? Or assume service handles global state?
    // Usually end call on dispose if active.
    _webrtcService.endCall();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Dark for calls
      body: Stack(
        children: [
          // 1. Video Layer (Remote = Full, Local = PIP)
          if (widget.isVideo) ...[
             // Remote (Full Screen)
             Positioned.fill(
               child: RTCVideoView(
                 _remoteRenderer, 
                 objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
               ),
             ),
             // Local (PIP)
             Positioned(
               right: 20, 
               top: 50,
               width: 100,
               height: 150, 
               child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: RTCVideoView(
                    _localRenderer,
                    mirror: true,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover
                  ),
               )
             )
          ] else ...[
             // Audio UI (Avatar centered)
             Center(
               child: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundImage: NetworkImage(widget.peerAvatar.isNotEmpty && widget.peerAvatar.startsWith('http') ? widget.peerAvatar : 'https://ui-avatars.com/api/?name=${widget.peerName}'),
                    ),
                    const SizedBox(height: 20),
                    Text(widget.peerName, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text(_status == "On Call" ? _formattedDuration : _status, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                 ],
               ),
             )
          ],

          // 2. Overlay Info (Name/Status) if Video
          if (widget.isVideo)
             Positioned(
               top: 50, left: 0, right: 0,
               child: Column(
                 children: [
                    Text(widget.peerName, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 5, color: Colors.black)])),
                    const SizedBox(height: 5),
                    Text(_status == "On Call" ? _formattedDuration : _status, style: const TextStyle(color: Colors.white, fontSize: 14, shadows: [Shadow(blurRadius: 5, color: Colors.black)])),
                 ],
               ),
             ),
             
          // 3. Controls
          Positioned(
            bottom: 40, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              decoration: const BoxDecoration(
                 color: Colors.black54,
                 borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30))
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                   IconButton(
                     onPressed: () {
                        _webrtcService.toggleMute();
                        setState(() => _micEnabled = !_micEnabled);
                     },
                     icon: Icon(_micEnabled ? Icons.mic : Icons.mic_off, color: Colors.white, size: 30),
                     style: IconButton.styleFrom(backgroundColor: Colors.white24, padding: const EdgeInsets.all(12)),
                   ),
                   if (widget.isVideo)
                     IconButton(
                       onPressed: _webrtcService.switchCamera,
                       icon: const Icon(Icons.cameraswitch, color: Colors.white, size: 30),
                       style: IconButton.styleFrom(backgroundColor: Colors.white24, padding: const EdgeInsets.all(12)),
                     ),
                   IconButton(
                     onPressed: () {
                        _webrtcService.endCall();
                        Navigator.pop(context);
                     },
                     icon: const Icon(Icons.call_end, color: Colors.white, size: 30),
                     style: IconButton.styleFrom(backgroundColor: Colors.redAccent, padding: const EdgeInsets.all(15)),
                   ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
