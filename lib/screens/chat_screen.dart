import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:whatsapp_clone/models/contact.dart';
import 'package:whatsapp_clone/services/chat_service.dart';
import 'package:whatsapp_clone/services/voice_recorder_service.dart';
import 'package:whatsapp_clone/widgets/audio_message_bubble.dart';
import 'package:whatsapp_clone/widgets/avatar_widget.dart';
import 'package:whatsapp_clone/widgets/sent_message_bubble.dart';
import 'package:whatsapp_clone/widgets/received_message_bubble.dart';
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  final Contact contact;
  final String peerId;
  final String chatId; // Explicit Chat ID
  final bool isGroup;

  const ChatScreen({
    super.key,
    required this.contact,
    required this.peerId,
    required this.chatId,
    this.isGroup = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  final VoiceRecorderService _voiceRecorder = VoiceRecorderService();
  final ScrollController _scrollController = ScrollController();
  
  bool _isTyping = false;
  bool _isRecording = false;
  DateTime? _recordStartTime;
  
  @override
  void initState() {
    super.initState();
    _messageController.addListener(() {
      setState(() {
        _isTyping = _messageController.text.trim().isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _voiceRecorder.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.minScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    String text = _messageController.text;
    _messageController.clear();
    await _chatService.sendMessage(widget.chatId, text);
    _scrollToBottom();
  }

  // Voice Logic
  Future<void> _startRecording() async {
    bool hasPermission = await _voiceRecorder.checkPermission();
    if (!hasPermission) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Microphone permission denied')));
      return;
    }
    
    await _voiceRecorder.startRecording();
    setState(() {
      _isRecording = true;
      _recordStartTime = DateTime.now();
    });
  }

  Future<void> _stopRecordingAndSend() async {
    if (!_isRecording) return;
    
    print("Stopping recording...");
    final path = await _voiceRecorder.stopRecording();
    print("Recording stopped. Path: $path");
    
    setState(() => _isRecording = false);

    if (path != null && _recordStartTime != null) {
      final duration = DateTime.now().difference(_recordStartTime!);
      print("Duration: ${duration.inSeconds}s");
      
      if (duration.inSeconds < 1) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Voice message too short')));
        return;
      }
      
      try {
        await _chatService.sendVoiceMessage(widget.chatId, path, duration.inSeconds);
        print("Voice message sent successfully");
        _scrollToBottom();
      } catch (e) {
        print("Failed to send voice message: $e");
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
      }
    } else {
      print("Path was null or start time missing");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECE5DD),
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: const Color(0xFF9575CD),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            AvatarWidget(imageUrl: widget.contact.profileImage, radius: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.contact.name, style: const TextStyle(fontSize: 18), overflow: TextOverflow.ellipsis),
                  if (!widget.isGroup)
                    Text(widget.contact.isOnline ? 'Online' : 'Offline', 
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.videocam), onPressed: () {}),
          IconButton(icon: const Icon(Icons.call), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final docs = snapshot.data!.docs;
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == FirebaseAuth.instance.currentUser?.uid;
                    final type = data['type'] ?? 'text'; // Default to text

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          color: isMe ? const Color(0xFF9575CD) : Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(10),
                            topRight: const Radius.circular(10),
                            bottomLeft: isMe ? const Radius.circular(10) : Radius.zero,
                            bottomRight: isMe ? Radius.zero : const Radius.circular(10),
                          ),
                          boxShadow: [
                             BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 2, offset: const Offset(0, 1))
                          ],
                        ),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        child: type == 'audio' 
                        ? AudioMessageBubble(
                            audioUrl: data['audioUrl'] ?? '', 
                            isSender: isMe,
                            durationSeconds: data['duration'] ?? 0,
                          ) 
                        : Text(
                          data['text'] ?? '',
                          style: TextStyle(
                            fontSize: 16,
                            color: isMe ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          
          // INPUT AREA
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1))],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        IconButton(icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.grey), onPressed: () {}),
                        Expanded(
                          child: _isRecording 
                          ? const Text('Recording audio...', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
                          : TextField(
                              controller: _messageController,
                              decoration: const InputDecoration(
                                hintText: 'Message',
                                border: InputBorder.none,
                              ),
                            ),
                        ),
                        if (!_isRecording) ...[
                          IconButton(icon: const Icon(Icons.attach_file, color: Colors.grey), onPressed: () {}),
                          if (!_isTyping) IconButton(icon: const Icon(Icons.camera_alt, color: Colors.grey), onPressed: () {}),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                GestureDetector(
                   onTap: () async {
                     if (_isTyping) {
                       _sendMessage();
                     } else if (kIsWeb) {
                        // WEB / DESKTOP: Click to Start / Stop
                        if (_isRecording) {
                           await _stopRecordingAndSend();
                        } else {
                           await _startRecording();
                        }
                     } else {
                       // MOBILE: Tap does nothing or shows hint
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hold to record'), duration: Duration(seconds: 1)));
                     }
                   },
                   // MOBILE ONLY: Long Press
                   onLongPressStart: (details) async {
                     if (!kIsWeb && !_isTyping) await _startRecording();
                   },
                   onLongPressEnd: (details) async {
                     if (!kIsWeb && _isRecording) await _stopRecordingAndSend();
                   },
                   child: CircleAvatar(
                    backgroundColor: const Color(0xFF9575CD),
                    radius: 24,
                    child: Icon(
                      _isTyping ? Icons.send : (_isRecording ? Icons.stop : Icons.mic), 
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
