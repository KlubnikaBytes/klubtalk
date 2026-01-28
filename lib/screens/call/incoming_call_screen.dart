import 'package:flutter/material.dart';
import 'package:whatsapp_clone/screens/call/call_screen.dart';
import 'package:whatsapp_clone/services/webrtc_service.dart';
import 'package:whatsapp_clone/services/socket_service.dart';
import 'package:whatsapp_clone/services/contact_service.dart';

class IncomingCallScreen extends StatefulWidget {
  final String callerName;
  final String callerAvatar;
  final String callType; // 'audio' or 'video'
  final Map<String, dynamic> callData; // Full socket payload

  const IncomingCallScreen({
    super.key,
    required this.callerName,
    required this.callerAvatar,
    required this.callType,
    required this.callData,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  String _displayName = "";
  bool _isAccepting = false; // Fix: duplicate logic / pop safety

  @override
  void initState() {
    super.initState();
    _displayName = widget.callerName; // Initial fallback
    _resolveName();
  }

  Future<void> _resolveName() async {
     try {
       String? peerId = widget.callData['from'];
       if (peerId != null) {
          String name = await ContactService().resolveContactName(peerId);
          if (mounted && name != 'Unknown') {
             setState(() => _displayName = name);
          }
       }
     } catch (e) {
       print("Error resolving name: $e");
     }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, 
      onPopInvoked: (didPop) async {
        if (didPop) return;
        // Fix: If we are midway accepting, DO NOT REJECT
        if (_isAccepting) return; 

        // Handle Back Button as Reject
        WebrtcService().rejectCall(widget.callData['from']);
        if(mounted) Navigator.pop(context);
      },
      child: Scaffold(
      backgroundColor: const Color(0xFF101D25), // WhatsApp Call Dark BG
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 50),
            // Caller Info
            CircleAvatar(
              radius: 50,
              backgroundImage: NetworkImage(widget.callerAvatar.isNotEmpty 
                  ? widget.callerAvatar 
                  : 'https://ui-avatars.com/api/?name=$_displayName'),
            ),
            const SizedBox(height: 20),
            Text(
              _displayName,
              style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.normal),
            ),
            const SizedBox(height: 10),
            Text(
              "Incoming ${widget.callType == 'video' ? 'Video' : 'Voice'} Call",
              style: const TextStyle(color: Colors.white54, fontSize: 16),
            ),
             const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                 Icon(widget.callType == 'video' ? Icons.videocam : Icons.call, color: Colors.white54, size: 20),
                 const SizedBox(width: 8),
                 Text(
                   "WhatsApp ${widget.callType == 'video' ? 'Video' : 'Voice'} Call",
                   style: const TextStyle(color: Colors.white54, fontSize: 16),
                 ),
              ],
            ),
            
            const Spacer(),
            
            // Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   // Reject (Red)
                   Column(
                     children: [
                         GestureDetector(
                          onTap: () {
                             if (_isAccepting) return;
                             WebrtcService().rejectCall(widget.callData['from']);
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
                        const SizedBox(height: 8),
                        const Text("Decline", style: TextStyle(color: Colors.white54))
                      ],
                    ),
                    
                    // Accept (Green)
                    Column(
                      children: [
                         GestureDetector(
                          onTap: () async {
                             if (_isAccepting) return;
                             setState(() => _isAccepting = true); // Lock

                             try {
                               // Initialize incoming call first
                               await WebrtcService().handleIncomingCall(widget.callData);

                               if(mounted) {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CallScreen(
                                        peerName: _displayName,
                                        peerAvatar: widget.callerAvatar,
                                        isCaller: false,
                                        isVideo: widget.callType == 'video',
                                      )
                                    )
                                  );
                               }
                             } catch (e) {
                               print("Failed to accept call: $e");
                               setState(() => _isAccepting = false); // Unlock
                               WebrtcService().endCall(); 
                               ScaffoldMessenger.of(context).showSnackBar(
                                 SnackBar(content: Text("Failed to connect: $e"))
                               );
                             }
                          },
                          child: const CircleAvatar(
                            radius: 35,
                            backgroundColor: Colors.green,
                            child: Icon(Icons.call, color: Colors.white, size: 30),
                          ),
                        ),
                       const SizedBox(height: 8),
                       const Text("Accept", style: TextStyle(color: Colors.white54))
                     ],
                   )
                ],
              ),
            )
          ],
        ),
      ),
    )
    );
  }
}
