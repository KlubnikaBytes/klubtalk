import 'package:flutter/material.dart';
import 'package:whatsapp_clone/services/webrtc_service.dart';
import 'package:whatsapp_clone/widgets/avatar_widget.dart';
import 'package:whatsapp_clone/screens/call/call_screen.dart';
import 'package:whatsapp_clone/services/contact_service.dart';

class OutgoingCallScreen extends StatefulWidget {
  final String peerName;
  final String peerAvatar;
  final String peerId;
  final bool isVideo;

  const OutgoingCallScreen({
    super.key,
    required this.peerName,
    required this.peerAvatar,
    required this.peerId,
    required this.isVideo,
  });

  @override
  State<OutgoingCallScreen> createState() => _OutgoingCallScreenState();
}

class _OutgoingCallScreenState extends State<OutgoingCallScreen> {
  final WebrtcService _webrtcService = WebrtcService();
  String _displayName = "";
  bool _hasNavigated = false;  // Guard to prevent multiple navigation attempts

  @override
  void initState() {
    super.initState();
    _displayName = widget.peerName;
    _startCall();
    _resolveName();
  }
  
  Future<void> _resolveName() async {
     final name = await ContactService().resolveContactName(widget.peerId);
     if (mounted && name != 'Unknown') {
        setState(() => _displayName = name);
     }
  }

  void _startCall() {
    // Initiate WebRTC Call
    _webrtcService.initCall(widget.peerId, widget.isVideo);
    
    // Listen for state changes
    _webrtcService.onCallStateChange = (status) {
       if (!mounted) return; // Safety check for callback

       if (status == "Ended" || status == "Rejected") {
          // Guard: Prevent multiple navigation attempts
          if (!_hasNavigated && mounted && Navigator.canPop(context)) {
             _hasNavigated = true;
             Navigator.pop(context);
          }
       } else if (status == "On Call") {
          // Navigate to Active Call Screen
          if (!_hasNavigated && mounted) {
             _hasNavigated = true;
             Navigator.pushReplacement(
                context, 
                MaterialPageRoute(
                   builder: (context) => CallScreen(
                      peerName: _displayName,
                      peerAvatar: widget.peerAvatar,
                      isCaller: true,
                      peerId: widget.peerId,
                      isVideo: widget.isVideo,
                   )
                )
             );
          }
       }
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101D25), // WhatsApp Call Dark BG
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 50),
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: NetworkImage(widget.peerAvatar.isNotEmpty 
                        ? widget.peerAvatar 
                        : 'https://ui-avatars.com/api/?name=$_displayName'),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _displayName,
                    style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Ringing...",
                    style: TextStyle(color: Colors.white54, fontSize: 18),
                  ),
                ],
              ),
            ),
            const Spacer(),
            
            // End Call Button
            Padding(
              padding: const EdgeInsets.only(bottom: 60),
              child: GestureDetector(
                onTap: () {
                   _webrtcService.endCall();
                   if (mounted && Navigator.canPop(context)) {
                      Navigator.pop(context);
                   }
                },
                child: const CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.redAccent,
                  child: Icon(Icons.call_end, color: Colors.white, size: 30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Prevent callbacks after widget death
    // _webrtcService.onCallStateChange = null; // DANGEROUS: Might wipe CallScreen's listener!
    super.dispose();
  }
}
