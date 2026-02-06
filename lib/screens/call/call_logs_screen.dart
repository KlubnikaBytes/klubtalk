import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:whatsapp_clone/config/api_config.dart';
import 'package:whatsapp_clone/models/call_log_model.dart';
import 'package:whatsapp_clone/services/auth_service.dart';
import 'package:whatsapp_clone/services/contact_service.dart';
import 'package:whatsapp_clone/services/webrtc_service.dart';
import 'package:whatsapp_clone/services/socket_service.dart'; // Added SocketService import
import 'package:whatsapp_clone/screens/call/outgoing_call_screen.dart';
import 'dart:async'; // For StreamSubscription

class CallLogsScreen extends StatefulWidget {
  const CallLogsScreen({super.key});

  @override
  State<CallLogsScreen> createState() => _CallLogsScreenState();
}

class _CallLogsScreenState extends State<CallLogsScreen> {
  List<CallLogModel> logs = [];
  bool isLoading = true;
  StreamSubscription? _socketSub;

  @override
  void dispose() {
    _socketSub?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchCallLogs();
    
    // Auto-refresh on socket events (call end/reject)
    _socketSub = SocketService().callStream.listen((data) {
       final event = data['event'];
       if (event == 'video_call_end' || event == 'video_call_reject' || event == 'incoming-call' || event == 'call_saved') {
          print("🔄 CallLogsScreen: Received $event. Refreshing logs...");
          // Add small delay to allow backend to write to DB
          Future.delayed(const Duration(seconds: 1), _fetchCallLogs);
       }
    });
  }

  Future<void> _fetchCallLogs() async {
    try {
      final token = AuthService().token;
      final userId = AuthService().currentUserId;

      if (token == null || userId == null) {
          if (mounted) setState(() => isLoading = false);
          return;
      }

      print("📋 CallLogsScreen: Fetching logs for userId: $userId");
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/calls/history/$userId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      print("📋 CallLogsScreen: Response status: ${response.statusCode}");

      if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          print("📋 CallLogsScreen: Fetched ${data.length} raw logs");
          print("📋 RAW DATA SAMPLE: ${data.isNotEmpty ? jsonEncode(data[0]) : 'Empty'}"); // DEBUG LOG
          
          final rawLogs = data.map((json) => CallLogModel.fromJson(json)).toList();
          final List<CallLogModel> deduplicatedLogs = [];
          
          
          if (rawLogs.isNotEmpty) {
             // 1. Sort by time descending
             rawLogs.sort((a, b) => b.startedAt.compareTo(a.startedAt));
             
             // DEBUG: Print top 3 logs
             for (var i=0; i< (rawLogs.length > 3 ? 3 : rawLogs.length); i++) {
                 print("   [$i] ${rawLogs[i].startedAt} - ${rawLogs[i].callerPhone} -> ${rawLogs[i].receiverPhone}");
             }

             // SIMPLIFIED: No deduplication for verification
             deduplicatedLogs.addAll(rawLogs);
          }
          
          if (mounted) {
             setState(() {
               logs = deduplicatedLogs;
               isLoading = false;
             });
          }
      }
    } catch (e) {
      print("Error fetching call logs: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(backgroundColor: Colors.white, body: Center(child: CircularProgressIndicator()));
    }

    if (logs.isEmpty) {
      return const Scaffold(backgroundColor: Colors.white, body: Center(child: Text("No recent calls")));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: ListView.builder(
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        final isMeScanner = log.callerId == AuthService().currentUserId;
        
        // Determine the "Other Party"
        final otherPhone = isMeScanner ? log.receiverPhone : log.callerPhone;
        final otherId = isMeScanner ? log.receiverId : log.callerId;

        return FutureBuilder<String>(
          future: ContactService().getContactNameFromPhone(otherPhone), 
          builder: (context, snapshot) {
            final displayName = snapshot.data ?? otherPhone;
            
            // Explicit Type Logic
            final isVideo = log.type == 'video'; 
            
            // explicit Status Logic
            final isMissed = log.status == 'missed' || log.status == 'rejected' || log.status == 'declined';
            final isCompleted = log.status == 'completed';
            
            // Color Logic
            final statusColor = isMissed ? Colors.red : Colors.green;
            
            // Icon Logic for Status Arrow
            IconData statusIcon;
            if (isMissed) {
               statusIcon = Icons.call_missed;
            } else if (isMeScanner) {
               statusIcon = Icons.call_made; 
            } else {
               statusIcon = Icons.call_received;
            }

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.grey[200],
                backgroundImage: const AssetImage('assets/images/strawberry_icon.png'),
                child: const Icon(Icons.person, color: Colors.grey),
              ),
              title: Text(
                displayName,
                style: TextStyle(
                   fontWeight: FontWeight.bold, 
                   color: isMissed ? Colors.red : Colors.black
                ),
              ),
              subtitle: Row(
                children: [
                   Icon(
                     statusIcon,
                     color: statusColor,
                     size: 16,
                   ),
                   const SizedBox(width: 5),
                   Text(
                     DateFormat('MMM d, h:mm a').format(log.startedAt.toLocal()),
                     style: const TextStyle(color: Colors.grey, fontSize: 13),
                   )
                ],
              ),
              trailing: IconButton(
                icon: Icon(
                    isVideo ? Icons.videocam : Icons.call, // Strict Icon type
                    color: const Color(0xFFC92136)
                ),
                onPressed: () {
                   // Click to Call - Strict routing based on log type
                   // WebrtcService().initCall(otherId, isVideo); 
                   
                   // FIX: Navigation to Outgoing Call Screen (WhatsApp Style)
                   Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OutgoingCallScreen(
                          peerName: displayName,
                          peerAvatar: '', // todo: could fetch avatar url if we had it easily, can rely on placeholder
                          peerId: otherId,
                          isVideo: isVideo,
                        )
                      )
                   );
                },
              ),
            );
          },
        );
      },
    ),
    );
  }
}
