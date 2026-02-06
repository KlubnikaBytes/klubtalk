import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:whatsapp_clone/services/webrtc_service.dart';
import 'package:whatsapp_clone/services/contact_service.dart';

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
  final WebrtcService _webrtcService = WebrtcService();

  Timer? _callTimer;
  final ValueNotifier<int> _seconds = ValueNotifier(0);
  final ValueNotifier<String> _status = ValueNotifier("Connecting...");
  final ValueNotifier<bool> _micEnabled = ValueNotifier(true);
  
  late String _displayName;
  
  // No video toggle state needed strictly if we just trust service, but nice to flip icon
  // We can just query service logic or keep local toggle for UI
  
  @override
  void initState() {
    super.initState();
    _displayName = widget.peerName;
    _resolveName();
    _setupListeners();
  }

  Future<void> _resolveName() async {
    if (widget.peerId != null) {
       final name = await ContactService().resolveContactName(widget.peerId!);
       if (mounted && name != 'Unknown') {
          setState(() {
             _displayName = name;
          });
       }
    }
  }
  
  void _setupListeners() {
    // These listeners update Streams/etc, but for Video Views (srcObject), 
    // FLUTTER_WEBRTC handles texture updates internally once attached.
    // We only need to rebuild IF the renderer *object* changed (which it shouldn't in Singleton)
    // or if we switch from Audio to Video mode (widget.isVideo).
    
    // We listen to Local/Remote stream ready just to ensure UI is mounted? 
    // Actually, we don't even need to setState() for stream Ready if we passed the renderer 
    // and it was initialized. 
    // But let's keep a safe single rebuild if stream flows.
    _webrtcService.onLocalStream = (_) {
       if(mounted) setState(() {}); 
    };
    
    _webrtcService.onRemoteStream = (_) {
       if(mounted) setState(() {});
    };
    
    _webrtcService.onCallStateChange = (status) {
       print("📞 [CallScreen] onCallStateChange: '$status'"); // DEBUG LOG
       if (mounted) _status.value = status;
       if (status == "On Call") _startTimer();
       if (status == "Ended" || status == "Rejected") {
          print("🛑 [CallScreen] Received End/Reject signal. Scheduling pop..."); 
          Future.delayed(const Duration(seconds: 1), () { 
             print("🛑 [CallScreen] Popping navigation now (mounted=$mounted)");
             if (mounted) {
               if (Navigator.canPop(context)) {
                 Navigator.pop(context);
               } else {
                 print("⚠️ [CallScreen] Cannot pop! Is this the root route?");
                 // Fallback: Push to Home? 
               }
             }
          });
       }
    };
    
    // Initial State Check
    if (_webrtcService.localStream != null || _webrtcService.remoteStream != null) {
       setState(() {});
    }
  }

  void _startTimer() {
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) _seconds.value++;
    });
  }

  String _formatDuration(int seconds) {
    final m = (seconds / 60).floor().toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _webrtcService.onCallStateChange = null; 
    _webrtcService.onLocalStream = null;
    _webrtcService.onRemoteStream = null;
    _webrtcService.endCall();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The Main Scaffold and Stack are built ONCE (mostly).
    // The Video Layer depends on widget.isVideo (final).
    // Updates to Timer happen in ValueListenableBuilder.
    
    return Scaffold(
      backgroundColor: Colors.black, 
      body: Stack(
        children: [
          // 1. Video Layer (Stable)
          if (widget.isVideo) ...[
             Positioned.fill(
               child: RTCVideoView(
                 _webrtcService.remoteRenderer, 
                 objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
               ),
             ),
             Positioned(
               right: 20, 
               top: 50,
               width: 100,
               height: 150, 
               child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: RTCVideoView(
                    _webrtcService.localRenderer,
                    mirror: true,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover
                  ),
               )
             )
          ] else ...[
             Center(
               child: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundImage: NetworkImage(widget.peerAvatar.isNotEmpty && widget.peerAvatar.startsWith('http') ? widget.peerAvatar : 'https://ui-avatars.com/api/?name=$_displayName'),
                    ),
                    const SizedBox(height: 20),
                    Text(_displayName, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    // Timer / Status
                    ValueListenableBuilder<String>(
                      valueListenable: _status,
                      builder: (ctx, status, _) {
                        return ValueListenableBuilder<int>(
                          valueListenable: _seconds,
                          builder: (ctx, seconds, _) {
                             return Text(status == "On Call" ? _formatDuration(seconds) : status, 
                               style: const TextStyle(color: Colors.white70, fontSize: 16)
                             );
                          }
                        );
                      }
                    ),
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
                    Text(_displayName, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 5, color: Colors.black)])),
                    const SizedBox(height: 5),
                    ValueListenableBuilder<String>(
                      valueListenable: _status,
                      builder: (ctx, status, _) {
                        return ValueListenableBuilder<int>(
                          valueListenable: _seconds,
                          builder: (ctx, seconds, _) {
                             return Text(status == "On Call" ? _formatDuration(seconds) : status, 
                               style: const TextStyle(color: Colors.white, fontSize: 14, shadows: [Shadow(blurRadius: 5, color: Colors.black)])
                             );
                          }
                        );
                      }
                    ),
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
                   ValueListenableBuilder<bool>(
                     valueListenable: _micEnabled,
                     builder: (ctx, isMic, _) {
                       return IconButton(
                         onPressed: () {
                            _webrtcService.toggleMute();
                            _micEnabled.value = !_micEnabled.value;
                         },
                         icon: Icon(isMic ? Icons.mic : Icons.mic_off, color: Colors.white, size: 30),
                         style: IconButton.styleFrom(backgroundColor: Colors.white24, padding: const EdgeInsets.all(12)),
                       );
                     }
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
                        if (mounted && Navigator.canPop(context)) {
                           Navigator.pop(context);
                        }
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
