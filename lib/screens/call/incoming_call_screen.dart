import 'package:flutter/material.dart';
import 'package:whatsapp_clone/screens/call/call_screen.dart';
import 'package:whatsapp_clone/services/webrtc_service.dart';

class IncomingCallScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101D25), // WhatsApp Call Dark BG
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 50),
            // Caller Info
            CircleAvatar(
              radius: 50,
              backgroundImage: NetworkImage(callerAvatar.isNotEmpty ? callerAvatar : 'https://ui-avatars.com/api/?name=$callerName'),
            ),
            const SizedBox(height: 20),
            Text(
              callerName,
              style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.normal),
            ),
            const SizedBox(height: 10),
            const Text(
              "Incoming WebWhatsapp Call",
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
             const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                 Icon(callType == 'video' ? Icons.videocam : Icons.call, color: Colors.white54, size: 20),
                 const SizedBox(width: 8),
                 Text(
                   "WhatsApp ${callType == 'video' ? 'Video' : 'Voice'} Call",
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
                            // Emit Reject
                            WebrtcService().endCall(); // Or reject socket logic
                            Navigator.pop(context);
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
                            // initialize service with incoming data
                            // First pop this screen, then push CallScreen? Or Replace?
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CallScreen(
                                  peerName: callerName,
                                  peerAvatar: callerAvatar,
                                  isCaller: false,
                                  isVideo: callType == 'video',
                                )
                              )
                            );
                            
                            // Trigger WebRTC answer logic
                            await WebrtcService().handleIncomingCall(callData);
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
    );
  }
}
