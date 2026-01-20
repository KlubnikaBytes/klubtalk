import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:whatsapp_clone/config/api_config.dart';
import 'package:whatsapp_clone/models/call_log_model.dart';
import 'package:whatsapp_clone/services/auth_service.dart';
import 'package:whatsapp_clone/services/contact_service.dart';
import 'package:whatsapp_clone/services/webrtc_service.dart';

class CallLogsScreen extends StatefulWidget {
  const CallLogsScreen({super.key});

  @override
  State<CallLogsScreen> createState() => _CallLogsScreenState();
}

class _CallLogsScreenState extends State<CallLogsScreen> {
  List<CallLogModel> logs = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCallLogs();
  }

  Future<void> _fetchCallLogs() async {
    try {
      final token = AuthService().token;
      final userId = AuthService().currentUserId;

      if (token == null || userId == null) {
          print("CallLogsScreen: User ID or Token is null. Cannot fetch logs.");
          setState(() => isLoading = false);
          return;
      }

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/calls/history/$userId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          
          final rawLogs = data.map((json) => CallLogModel.fromJson(json)).toList();
          final List<CallLogModel> deduplicatedLogs = [];
          
          if (rawLogs.isNotEmpty) {
             // 1. Sort by time descending to process linearly
             rawLogs.sort((a, b) => b.startedAt.compareTo(a.startedAt));
             
             CallLogModel? current = rawLogs.first;
             
             for (int i = 1; i < rawLogs.length; i++) {
                final next = rawLogs[i];
                
                // Fuzzy Match Logic
                // 1. Same participants (Check if both IDs present found in both)
                // Normalize IDs set for comparison
                final currentParts = {current!.callerId, current.receiverId};
                final nextParts = {next.callerId, next.receiverId};
                
                final sameParticipants = currentParts.containsAll(nextParts) && nextParts.containsAll(currentParts);
                
                // 2. Time Window (e.g., 10 seconds)
                final diff = current.startedAt.difference(next.startedAt).inSeconds.abs();
                final sameTime = diff <= 10;
                
                if (sameParticipants && sameTime) {
                   // MERGE: Keep the "better" one
                   // Priority: Duration > 0, then Voice > Video (assuming video is default ghost)
                   
                   bool keepCurrent = true;
                   
                   if (next.duration > 0 && current.duration == 0) {
                      keepCurrent = false; 
                   } else if (current.duration == 0 && next.duration == 0) {
                      if (next.type == 'voice' && current.type == 'video') {
                         keepCurrent = false;
                      }
                   }
                   
                   if (keepCurrent) {
                      // Keep current, discard next (do nothing, next is skipped)
                   } else {
                      // Keep next, discard current
                      current = next;
                   }
                } else {
                   // No match, push current matches deduplicated list
                   deduplicatedLogs.add(current!);
                   current = next;
                }
             }
             // Add last one 
             if (current != null) deduplicatedLogs.add(current);
          }
          
          setState(() {
            logs = deduplicatedLogs;
            isLoading = false;
          });
      }
    } catch (e) {
      print("Error fetching call logs: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (logs.isEmpty) {
      return const Center(child: Text("No recent calls"));
    }

    return ListView.builder(
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
            final isVideo = log.type == 'video';
            final isMissed = log.status == 'missed';

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.grey[200],
                backgroundImage: const AssetImage('assets/images/default_avatar.png'),
                child: const Icon(Icons.person, color: Colors.grey),
              ),
              title: Text(
                displayName,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
              ),
              subtitle: Row(
                children: [
                   Icon(
                     isMissed ? Icons.call_missed : (isMeScanner ? Icons.call_made : Icons.call_received),
                     color: Colors.red, // User requested ALL red icons
                     size: 16,
                   ),
                   const SizedBox(width: 5),
                   Text(
                     DateFormat('MMM d, h:mm a').format(log.startedAt),
                     style: const TextStyle(color: Colors.grey, fontSize: 13),
                   )
                ],
              ),
              trailing: IconButton(
                icon: Icon(isVideo ? Icons.videocam : Icons.call, color: Theme.of(context).primaryColor),
                onPressed: () {
                   // Click to Call
                   WebrtcService().initCall(otherId, isVideo);
                },
              ),
            );
          },
        );
      },
    );
  }
}
