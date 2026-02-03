import 'dart:async';
import 'package:whatsapp_clone/services/notification_service.dart'; 
import 'package:flutter/material.dart';


import 'package:file_picker/file_picker.dart';
import 'package:whatsapp_clone/services/auth_service.dart';
import 'package:whatsapp_clone/services/socket_service.dart';
import 'package:whatsapp_clone/config/api_config.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:whatsapp_clone/utils/platform_helper.dart';
import 'package:whatsapp_clone/screens/group_details_screen.dart';
import 'package:whatsapp_clone/widgets/media/image_bubble_widget.dart';
import 'package:whatsapp_clone/widgets/media/video_bubble_widget.dart';
import 'package:whatsapp_clone/widgets/media/document_bubble_widget.dart';
import 'package:whatsapp_clone/widgets/media/media_bubble_widget.dart';
import 'package:whatsapp_clone/screens/group_media_screen.dart';
import 'package:whatsapp_clone/utils/chat_session_store.dart';
import 'package:whatsapp_clone/services/search_service.dart';
import 'package:whatsapp_clone/services/contact_service.dart'; // Import ContactService
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:intl/intl.dart';
import 'package:whatsapp_clone/models/contact.dart';
import 'package:whatsapp_clone/services/chat_service.dart';
import 'package:whatsapp_clone/widgets/avatar_widget.dart';
import 'package:whatsapp_clone/widgets/voice_recorder_widget.dart';
import 'package:whatsapp_clone/widgets/audio_message_bubble.dart';
import 'package:whatsapp_clone/widgets/sticker_picker_widget.dart';
import 'package:whatsapp_clone/widgets/sticker_message_widget.dart';
import 'package:whatsapp_clone/models/user_model.dart';
import 'package:whatsapp_clone/models/sticker_model.dart';

import 'package:whatsapp_clone/screens/call/call_screen.dart';
import 'package:whatsapp_clone/screens/call/outgoing_call_screen.dart';
import 'package:whatsapp_clone/screens/contact_info_screen.dart';
import 'package:whatsapp_clone/utils/route_observer.dart';
import 'package:whatsapp_clone/main.dart' show scaffoldMessengerKey;

class ChatScreen extends StatefulWidget {
  final Contact? contact;
  final String peerId;
  final String chatId;
  final bool isGroup;
  final String? groupName;
  final String? groupPhoto;

  const ChatScreen({
    super.key,
    this.contact,
    required this.peerId,
    required this.chatId,
    this.isGroup = false,
    this.groupName, 
    this.groupPhoto
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver, RouteAware {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  Timer? _pollingTimer;
  bool _isTyping = false;
  bool _isPeerTyping = false; // New typing state
  bool _isPeerOnline = false; // New online state
  bool _isEmojiPickerVisible = false;
  bool _isStickerPickerVisible = false;
  Set<String> _blockedUserIds = {};
  
  // Visibility State
  bool _isScreenVisible = true;
  bool _isAppResumed = true;
  
  // Socket Subscriptions
  StreamSubscription? _messageSub;
  StreamSubscription? _typingSub;
  StreamSubscription? _onlineSub;
  StreamSubscription? _deliverySub;
  StreamSubscription? _seenSub;

  bool get _isPeerBlocked => _blockedUserIds.contains(widget.peerId);

  Color _backgroundColor = const Color(0xFFECE5DD);

  // Search State
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final SearchService _searchService = SearchService();
  List<Map<String, dynamic>> _searchMatches = [];
  int _currentMatchIndex = -1;
  bool _isLoadingSearch = false;

  // Dynamic Group Info
  String _displayName = '';
  String _displayAvatar = '';


  @override
  void initState() {
    super.initState();
    // Initialize with passed values
    _displayName = widget.isGroup ? (widget.groupName ?? 'Group') : (widget.contact?.name ?? 'Unknown');
    _displayAvatar = widget.isGroup ? (widget.groupPhoto ?? '') : (widget.contact?.profileImage ?? '');

    _loadMessages();
    if (widget.isGroup) _loadGroupDetails(); // Load fresh group info
    _checkBlockStatus();
    _checkBlockStatus();
    _setupSocketListeners(); // Listen to socket
    SocketService().joinChat(widget.chatId); // Join Chat Room
    
    // Initial Seen Check (Only if visible, which usually implies yes in initState unless started in bg?)
    // Actually, initState runs before build, so technically visible.
    // We defer slightly to ensure route is ready? No, immediate is fine.
    if (_isScreenVisible && _isAppResumed) {
       SocketService().markSeen(widget.chatId); 
    }
    
    // Register Lifecycle Observer
    WidgetsBinding.instance.addObserver(this);

    if (!widget.isGroup) SocketService().checkOnline(widget.peerId); // Check initial online status

    _messageController.addListener(() {
      setState(() {
        _isTyping = _messageController.text.trim().isNotEmpty;
      });
      
      // Emit Typing Event
      if (_isTyping) {
        SocketService().sendTyping(widget.chatId, widget.peerId);
      } else {
        SocketService().sendStopTyping(widget.chatId, widget.peerId); 
      }
    });

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() {
          _isEmojiPickerVisible = false;
          _isStickerPickerVisible = false;
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Register Route Observer
    try {
       final route = ModalRoute.of(context);
       if (route != null) {
          routeObserver.subscribe(this, route);
       }
    } catch (e) {
       print("ChatScreen: Failed to subscribe to route observer: $e");
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
     super.didChangeAppLifecycleState(state);
     setState(() {
         _isAppResumed = (state == AppLifecycleState.resumed);
     });
     
     if (_isAppResumed) {
         print("ChatScreen: App Resumed. Screen Visible: $_isScreenVisible");
         if (_isScreenVisible) {
             _markChatAsSeen();
         }
     }
  }

  @override
  void didPopNext() {
      // Returning to this screen (top route popped off)
      print("ChatScreen: didPopNext (Returned to screen)");
      setState(() => _isScreenVisible = true);
      if (_isAppResumed) {
          _markChatAsSeen();
      }
  }

  @override
  void didPushNext() {
      // Pushing a new route on top
      print("ChatScreen: didPushNext (Covered by another screen)");
      setState(() => _isScreenVisible = false);
  }
  
  void _markChatAsSeen() {
      if (_isPeerBlocked) return;
      print("ChatScreen: Marking chat as seen explicitly.");
      SocketService().markSeen(widget.chatId);
  }

  void _setupSocketListeners() {
    final socketService = SocketService();
    
    // 1. Messages
    _messageSub = socketService.messageStream.listen((data) {
       if (_isPeerBlocked) return; // STEP 5: Block socket events when blocked
       print("ChatScreen: Received socket message: $data"); 
       if (!mounted) return;

       // Fix: Ensure timestamp survives socket updates
       if (data['timestamp'] == null) {
          data['timestamp'] = data['createdAt'] ?? DateTime.now().toIso8601String();
       }

       if (data['chatId'] == widget.chatId) {
          // Check for existing message (Real ID or Temp ID)
          final existingIndex = _messages.indexWhere((m) {
              final mId = m['_id'];
              final dataId = data['_id'];
              final dataTempId = data['tempId'];
              
              // Match by Real ID
              if (mId == dataId) return true;
              // Match by Temp ID (if optimistic message has it as _id)
              if (dataTempId != null && mId == dataTempId) return true;
              
              return false;
          });

          if (existingIndex != -1) {
             print("ChatScreen: Updating existing message at index $existingIndex");
             setState(() {
               // PRESERVE STATUS if local is advanced
               // Order: sending < sent < delivered < seen
               final currentStatus = _messages[existingIndex]['status'];
               final incomingStatus = data['status'];
               
               // If incoming is 'sent' but we are already 'delivered' or 'seen', keep ours.
               if (incomingStatus == 'sent' && (currentStatus == 'delivered' || currentStatus == 'seen')) {
                   data['status'] = currentStatus;
               }
               // Also preserve 'delivered' if incoming is 'sent'
               
               _messages[existingIndex] = data; 
             });
          } else {
             print("ChatScreen: Inserting new message");
             setState(() {
               _messages.insert(0, data); // Insert at 0 (Newest/Bottom)
             });
             
             // Smart Scroll: Only scroll if near bottom
             if (_scrollController.hasClients && _scrollController.offset < 300) {
                 _scrollToBottom();
             } else {
                 // TODO: Show "New Message" fab/badge
                 print("ChatScreen: New message received but user is scrolled up. Not scrolling.");
             }
             
             // If I am receiving a message from someone else while on this screen, mark it as seen immediately.
             if (data['senderId'] != AuthService().currentUserId) {
                // VISIBILITY CHECK: Only mark seen if eyes are on screen
                if (_isScreenVisible && _isAppResumed) {
                    print("ChatScreen: Open chat & Visible & Resumed. Instant Blue Tick.");
                    // 1. Emit specific seen event for this message (Rule 2)
                    if (data['_id'] != null) {
                        SocketService().socket?.emit('message_seen', {
                          'chatId': widget.chatId,
                          'messageId': data['_id'] // ACK specific message
                        });
                    }
                    // 2. Fallback to chat-level seen to cover bases
                    SocketService().markSeen(widget.chatId);
                } else {
                    print("ChatScreen: Message received but screen HIDDEN/BACKGROUND. NOT marking seen.");
                }
             }
          }
       }
    });

    // 2. Typing
    _typingSub = socketService.typingStream.listen((data) {
       if (_isPeerBlocked) return; // Don't show typing for blocked users
       if (data['chatId'] == widget.chatId && data['userId'] == widget.peerId) {
          if (mounted) {
            setState(() {
              _isPeerTyping = data['isTyping'] ?? false;
            });
          }
       }
    });

    // 3. Online Status (Global or Specific)
    _onlineSub = socketService.onlineStatusStream.listen((data) {
       if (_isPeerBlocked) return; // Don't show online status for blocked users
       if (data['userId'] == widget.peerId) {
          if (mounted) {
            setState(() {
               _isPeerOnline = data['isOnline'] ?? false;
            });
          }
       }
    });

    // 4. Delivery Status (Double Tick)
    _deliverySub = socketService.deliveryStatusStream.listen((data) {
       _updateMessageStatus(
         messageId: data['messageId'], 
         tempId: data['tempId'], 
         status: 'delivered'
       );
    });

    // 5. Seen Status (Blue Tick)
    _seenSub = socketService.seenStatusStream.listen((data) {
       if (data['chatId'] == widget.chatId) {
          if (mounted) {
            print("ChatScreen: Updating seen status for chat"); 
            setState(() {
              // Mark all my text/media messages as seen
              for (var i = 0; i < _messages.length; i++) {
                 if (_messages[i]['senderId'] == AuthService().currentUserId && _messages[i]['status'] != 'seen') {
                    _messages[i]['status'] = 'seen';
                 }
              }
            });
          }
       }
    });
  }

  // Robust Status Updater
  void _updateMessageStatus({String? messageId, String? tempId, required String status}) {
      if (!mounted) return;
      
      print("ChatScreen: Received status update '$status' for msgId: $messageId, tempId: $tempId");

      setState(() {
         int index = -1;
         
         // 1. Try finding by Real ID
         if (messageId != null) {
            index = _messages.indexWhere((m) => m['_id'] == messageId);
         }
         
         // 2. If not found, try finding by Temp ID
         if (index == -1 && tempId != null) {
            index = _messages.indexWhere((m) => m['_id'] == tempId || m['tempId'] == tempId);
         }
         
         if (index != -1) {
            print("ChatScreen: FOUND message at index $index. Current status: ${_messages[index]['status']}");
            // Optimization: Only update if status is 'better' (sent -> delivered -> seen)
            // But for now, trust the server event.
            _messages[index]['status'] = status;
            
            // If we have a real ID now (e.g. from delivery event), ensure we update our local ID if it was temp
            if (messageId != null && _messages[index]['_id'] != messageId) {
               print("ChatScreen: Upgrading local temp ID ${_messages[index]['_id']} to real ID $messageId");
               _messages[index]['_id'] = messageId;
            }
         } else {
            print("ChatScreen: Warning - Message NOT FOUND for status update (ID: $messageId, Temp: $tempId). Total msgs: ${_messages.length}");
         }
      });
  }


  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);

    SocketService().leaveChat(widget.chatId); // Leave Chat Room
    _messageSub?.cancel();
    _typingSub?.cancel();
    _onlineSub?.cancel();
    _deliverySub?.cancel();
    _seenSub?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadGroupDetails() async {
    try {
      final chats = await _chatService.getMyChats();
      final currentChat = chats.firstWhere(
        (c) => (c['_id'] ?? c['id']) == widget.chatId, 
        orElse: () => {}
      );
      
      if (currentChat.isNotEmpty && mounted) {
         setState(() {
             _displayName = currentChat['groupName'] ?? currentChat['name'] ?? 'Group';
             _displayAvatar = currentChat['groupAvatar'] ?? currentChat['avatar'] ?? '';
         });
      }
    } catch (e) {
      print("Error loading group details: $e");
    }
  }

  Future<void> _checkBlockStatus() async {
     if (widget.peerId.isEmpty) return; // Don't check for groups or invalid peers
     
     try {
       final blockedList = await _chatService.getBlockedUsers();
        // print("DEBUG: Fetched blocked list: $blockedList");
       
       if (mounted) {
         setState(() {
           _blockedUserIds = blockedList.toSet();
         });
         // print("DEBUG: Checking if '${widget.peerId}' is in blocked list. Result: $_isPeerBlocked");
       }
     } catch (e) {
       print("Failed to check block status: $e");
     }
  }

  Future<void> _toggleEmojiPicker() async {
    if (_isEmojiPickerVisible) {
      _focusNode.requestFocus();
      setState(() {
        _isEmojiPickerVisible = false;
      });
    } else {
      _focusNode.unfocus();
      await Future.delayed(const Duration(milliseconds: 50)); 
      setState(() {
        _isEmojiPickerVisible = true;
        _isStickerPickerVisible = false;
      });
    }
  }

  Future<void> _toggleStickerPicker() async {
    if (_isStickerPickerVisible) {
      _focusNode.requestFocus();
      setState(() => _isStickerPickerVisible = false);
    } else {
      _focusNode.unfocus();
      await Future.delayed(const Duration(milliseconds: 50));
      setState(() {
         _isStickerPickerVisible = true;
         _isEmojiPickerVisible = false;
      });
    }
  }

  void _sendSticker(Sticker sticker) async {
     if (_isPeerBlocked) return; // STEP 6: Block sticker sending
     final tempId = DateTime.now().millisecondsSinceEpoch.toString();
     final optimisticMessage = {
       '_id': tempId,
       'chatId': widget.chatId,
       'senderId': AuthService().currentUserId,
       'type': 'sticker',
       'content': sticker.imageUrl,
       'timestamp': DateTime.now().toIso8601String(),
       'status': 'sending' 
     };

     setState(() {
       _messages.insert(0, optimisticMessage);
     });
     _scrollToBottom();
     
     try {
       // Fix: Pass tempId and handle response locally instead of reloading all
       final sentMessage = await _chatService.sendStickerMessage(widget.chatId, sticker.imageUrl, tempId: tempId);
       
       if (sentMessage != null) {
          // Fix: Ensure timestamp survives REST updates
          if (sentMessage['timestamp'] == null) {
             sentMessage['timestamp'] = sentMessage['createdAt'] ?? DateTime.now().toIso8601String();
          }

          final index = _messages.indexWhere((m) => m['_id'] == tempId);
          if (index != -1 && mounted) {
             setState(() {
               _messages[index] = sentMessage;
             });
          }
       }
     } catch (e) {
        if(mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send sticker: $e')));
           setState(() {
             _messages.removeWhere((m) => m['_id'] == tempId);
           });
        }
     }
  }

  Future<bool> _onWillPop() async {
    if (_isEmojiPickerVisible || _isStickerPickerVisible) {
      setState(() {
        _isEmojiPickerVisible = false;
        _isStickerPickerVisible = false;
      });
      return false;
    }
    return true;
  }

  Future<void> _loadMessages({bool updateLoading = true}) async {
    try {
      if (updateLoading) {
        setState(() => _isLoading = true);
      }
      final messages = await _chatService.getMessages(widget.chatId);
      if (mounted) {
        setState(() {
          _messages = messages.reversed.toList(); // Store Newest First
          _isLoading = false;
        });
        
        // Cancel notifications for these messages since we are viewing them
        for (var msg in messages) {
           if (msg['senderId'] != AuthService().currentUserId) {
              // Cancel notification for this message
              NotificationService.cancelMessageNotification(msg['_id']);
           }
        }

        if (updateLoading) {
             // If newest is at 0, and we use reverse list view, we are already at 0 scroll offset usually?
             // But force scroll to 0 (bottom) anyway
             Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
        }
      }
    } catch (e) {
      print('Error loading messages: $e');
      if (mounted && updateLoading) {
        setState(() => _isLoading = false);
      }
    }
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

  String _getFullUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '${ApiConfig.baseUrl}$path';
  }

  Future<void> _sendMessage() async {
    if (_isPeerBlocked) return; // STEP 6: Block message sending
    if (_messageController.text.trim().isEmpty) return;
    String text = _messageController.text;
    _messageController.clear();
    
    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    final optimisticMessage = {
      '_id': tempId,
      'chatId': widget.chatId,
      'senderId': AuthService().currentUserId,
      'type': 'text',
      'content': text,
      'timestamp': DateTime.now().toIso8601String(),
      'status': 'sending' 
    };

    setState(() {
      _messages.insert(0, optimisticMessage);
    });
    _scrollToBottom();
    
    try {
      // Use ChatService
      // We pass tempId to help match the socket ack
      final sentMessage = await _chatService.sendMessage(widget.chatId, text, tempId: tempId);
      
      // If REST fallback returned a message (socket disconnected case), update our optimistic one
      if (sentMessage != null) {
         print("ChatScreen: REST fallback returned message. Updating UI.");
         
         // Fix: Ensure timestamp survives REST updates
         if (sentMessage['timestamp'] == null) {
            sentMessage['timestamp'] = sentMessage['createdAt'] ?? DateTime.now().toIso8601String();
         }

         final index = _messages.indexWhere((m) => m['_id'] == tempId);
         if (index != -1) {
            setState(() {
              _messages[index] = sentMessage;
            });
         }
      } 
    } catch (e) {
      if(mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
         setState(() {
           _messages.removeWhere((m) => m['_id'] == tempId);
         });
      }
    }
  }
  
  Future<void> _handleVoiceRecording(String path, int duration) async {
      if (_isPeerBlocked) return; // STEP 6: Block voice recording
      final tempId = DateTime.now().millisecondsSinceEpoch.toString();
      final optimisticMessage = {
        '_id': tempId,
        'chatId': widget.chatId,
        'senderId': AuthService().currentUserId,
        'type': 'audio', // UI expects audio for voice bubbles usually
        'content': path, // Local path for preview
        'duration': duration, // Duration
        'timestamp': DateTime.now().toIso8601String(),
        'status': 'sending' 
      };

      setState(() {
        _messages.insert(0, optimisticMessage);
      });
      _scrollToBottom();

      try {
        await _chatService.sendVoiceMessage(widget.chatId, path, duration, tempId: tempId);
        // Do NOT reload messages. Trust socket/optimistic update.
      } catch (e) {
        if(mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
            setState(() {
              _messages.removeWhere((m) => m['_id'] == tempId);
            });
        }
      }
  }

  Future<void> _pickAndSendMedia() async {
    if (_isPeerBlocked) return; // STEP 6: Block media sending
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? media = await picker.pickMedia(); 
      if (media != null) {
          String mimeType = media.mimeType ?? lookupMimeType(media.path) ?? '';
          
          // Fallback mime detection
          if (mimeType.isEmpty) {
             try {
                final bytes = await media.readAsBytes();
                final headerBytes = bytes.take(12).toList();
                mimeType = lookupMimeType(media.path, headerBytes: headerBytes) ?? '';
             } catch (e) { print("Mime detect error: $e"); }
          }

          final tempId = DateTime.now().millisecondsSinceEpoch.toString();
          
          // **FIX: Properly detect file type including documents**
          String type = 'image'; // default
          if (mimeType.startsWith('video/')) {
            type = 'video';
          } else if (mimeType.startsWith('image/')) {
            type = 'image';
          } else {
            // Documents, PDFs, etc
            type = 'file';
          }
          
          final optimisticMessage = {
            '_id': tempId,
            'chatId': widget.chatId,
            'senderId': AuthService().currentUserId,
            'type': type,
            'content': media.path, // Local path
            'timestamp': DateTime.now().toIso8601String(),
            'status': 'sending'
          };

          setState(() {
             _messages.insert(0, optimisticMessage);
          });
          _scrollToBottom();

          // **FIX: Route to correct send function based on type**
          if (type == 'video') {
              await _chatService.sendVideoMessage(widget.chatId, media.path, mimeType: mimeType, tempId: tempId);
          } else if (type == 'file') {
              await _chatService.sendFileMessage(widget.chatId, media.path, tempId: tempId);
          } else {
              await _chatService.sendImageMessage(widget.chatId, media.path, mimeType: mimeType, tempId: tempId);
          }
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
         // TODO: Remove optimistic message on error? We might want to mark as failed instead.
         // For now, removing to be consistent with text logic.
      }
    }
  }

  Future<void> _pickAndSendFile() async {
    if (_isPeerBlocked) return; // STEP 6: Block file sending
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any, 
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final name = result.files.single.name;
        final size = result.files.single.size;
        
        final tempId = DateTime.now().millisecondsSinceEpoch.toString();
        // Optimistic UI for File
        final optimisticMessage = {
            '_id': tempId,
            'chatId': widget.chatId,
            'senderId': AuthService().currentUserId,
            'type': 'file',
            'content': path, // Local path
            'filename': name,
            'size': size,
            'timestamp': DateTime.now().toIso8601String(),
            'status': 'sending'
        };

         setState(() {
             _messages.insert(0, optimisticMessage);
          });
          _scrollToBottom();
  
        await _chatService.sendFileMessage(widget.chatId, path, tempId: tempId);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // --- MENU HELPERS ---

  void _showMuteDialog() {
    int? selectedValue = 0; // 0=8h, 1=1wk, 2=Always

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Mute notifications for..."),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               RadioListTile<int>(
                 title: const Text("8 hours"),
                 value: 0, 
                 groupValue: selectedValue, 
                 onChanged: (v) => setDialogState(() => selectedValue = v),
                 activeColor: const Color(0xFF075E54),
               ),
               RadioListTile<int>(
                 title: const Text("1 week"),
                 value: 1, 
                 groupValue: selectedValue, 
                 onChanged: (v) => setDialogState(() => selectedValue = v),
                 activeColor: const Color(0xFF075E54),
               ),
               RadioListTile<int>(
                 title: const Text("Always"),
                 value: 2, 
                 groupValue: selectedValue, 
                 onChanged: (v) => setDialogState(() => selectedValue = v),
                 activeColor: const Color(0xFF075E54),
               ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text("Cancel", style: TextStyle(color: Color(0xFF075E54)))
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                
                DateTime? until;
                if (selectedValue == 0) until = DateTime.now().add(const Duration(hours: 8));
                else if (selectedValue == 1) until = DateTime.now().add(const Duration(days: 7));
                else until = null; // Always

                try {
                   String? muteUntil = (selectedValue == 2) ? 'permanent' : until?.toIso8601String();
                   await _chatService.muteChat(widget.chatId, muteUntil);
                   if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Chat muted")));
                } catch(e) {
                   if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to mute")));
                }
              }, 
              child: const Text("OK", style: TextStyle(color: Color(0xFF075E54)))
            ),
          ],
        ),
      ),
    );
  }

  void _showDisappearingDialog() {
    int selectedValue = 0; // Default to Off (0) or maybe passed value? Assumed Off for now if unknown.
    // Ideally we fetch current state, but for now we default to 0 (Off) or 86400 etc. 
    // Let's assume 0 (Off) as default selected if we don't know.

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Disappearing messages"),
          content: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
               const Text("Make messages in this chat disappear", style: TextStyle(color: Colors.grey)),
               const SizedBox(height: 10),
               RadioListTile<int>(
                 title: const Text("24 hours"),
                 value: 86400,
                 groupValue: selectedValue,
                 onChanged: (v) => setDialogState(() => selectedValue = v!),
                 activeColor: const Color(0xFF075E54),
               ),
               RadioListTile<int>(
                 title: const Text("7 days"),
                 value: 604800,
                 groupValue: selectedValue,
                 onChanged: (v) => setDialogState(() => selectedValue = v!),
                 activeColor: const Color(0xFF075E54),
               ),
               RadioListTile<int>(
                 title: const Text("90 days"),
                 value: 7776000,
                 groupValue: selectedValue,
                 onChanged: (v) => setDialogState(() => selectedValue = v!),
                 activeColor: const Color(0xFF075E54),
               ),
               RadioListTile<int>(
                 title: const Text("Off"),
                 value: 0,
                 groupValue: selectedValue,
                 onChanged: (v) => setDialogState(() => selectedValue = v!),
                 activeColor: const Color(0xFF075E54),
               ),
             ],
          ),
          actions: [
             TextButton(
              onPressed: () async {
                 Navigator.pop(context);
                 try {
                    await _chatService.setDisappearingTimer(widget.chatId, selectedValue);
                    if(mounted) {
                       String msg = selectedValue == 0 ? "Off" : "On";
                       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Disappearing messages: $msg")));
                    }
                 } catch(e) {
                    if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to update")));
                 }
              },
              child: const Text("OK", style: TextStyle(color: Color(0xFF075E54)))
            )
          ],
        ),
      )
    );
  }

  void _showWallpaperDialog() {
     // Simple Color Picker for now as "Theme"
     final colors = [
       Colors.white, const Color(0xFFECE5DD), const Color(0xFFC92136), 
       const Color(0xFFE1F5FE), const Color(0xFFFBE9E7),
     ];
     
     showDialog(
       context: context,
       builder: (context) => AlertDialog(
         title: const Text("Chat Wallpaper"),
         content: Wrap(
           spacing: 10,
           runSpacing: 10,
           children: colors.map((c) => GestureDetector(
              onTap: () {
                String hex = '#${c.value.toRadixString(16).substring(2)}';
                _chatService.setChatTheme(widget.chatId, hex);
                setState(() {
                  _backgroundColor = c;
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Wallpaper updated")));
              },
              child: CircleAvatar(backgroundColor: c, radius: 20),
           )).toList(),
         ),
       )
     );
  }

  void _showReportDialog() {
    bool blockContact = true; // Default checked as per some WhatsApp versions, or user preference. prompt says checked? User prompt: "If checkbox checked -> block". Let's default to false or true? WhatsApp usually defaults to checked.
    // User Request: "Checkbox: [ ] Block <UserName>"
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text("Report \"${widget.isGroup ? (widget.groupName ?? 'Group') : (widget.contact?.name ?? 'Contact')}\" to WhatsApp?"), // Using "WhatsApp" as per clone context or "App"
          content: Column(
             mainAxisSize: MainAxisSize.min,
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               const Text("The last 5 messages from this contact will be forwarded to WhatsApp. No one in this chat will be notified."),
               if (!widget.isGroup) ...[
                 const SizedBox(height: 10),
                 Row(
                   children: [
                     SizedBox(
                       width: 24, 
                       height: 24,
                       child: Checkbox(
                         value: blockContact, 
                         onChanged: (v) => setState(() => blockContact = v!),
                         activeColor: const Color(0xFF075E54)
                       ),
                     ),
                     const SizedBox(width: 10),
                     Expanded(child: Text("Block ${widget.contact?.name ?? 'Contact'} and delete chat"))
                   ],
                 )
               ]
             ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(), 
              child: const Text("Cancel")
            ),
            TextButton(
              onPressed: () {
                 Navigator.of(ctx).pop(); // Close Selection Dialog
                 _submitReport(blockContact);
              },
              child: const Text("Report")
            )
          ],
        ),
      )
    );
  }

  Future<void> _submitReport(bool blockContact) async {
    // 1. Prepare Last 5 Messages
    final last5 = _messages.take(5).map((m) => {
      'senderId': m['senderId'],
      'content': m['content'] ?? m['text'],
      'timestamp': m['timestamp'],
      'type': m['type']
    }).toList();

    try {
      // 2. Send to Backend
      // Pass deleteChat: true if blocked/deleted
      await _chatService.reportChat(
        widget.chatId, 
        reportedUserId: widget.isGroup ? null : widget.peerId, 
        blockUser: widget.isGroup ? false : blockContact,
        deleteChat: widget.isGroup ? false : blockContact, // Send delete signal to backend
        reason: 'user_report',
        lastMessages: last5
      );

      if (!mounted) return;

      // 3. Show "Thank you" Popup
      showDialog(
        context: context,
        barrierDismissible: false, // User must click button
        builder: (dialogContext) => AlertDialog(
          title: const Text("Thank you for reporting"), 
          content: const Text("Our team will review this conversation."), 
          actions: [
            TextButton(
                onPressed: () {
                 // 1. Close the Thank You Dialog
                 Navigator.of(dialogContext).pop(); 
                 
                 // 2. Perform Local Deletion (State Update)
                 if (blockContact && !widget.isGroup) {
                    ChatSessionStore().deleteChat(widget.chatId);
                    if (mounted) {
                      setState(() {
                         _blockedUserIds.add(widget.peerId);
                      });
                    }
                 }
              },
              child: const Text("OK", style: TextStyle(color: Color(0xFF075E54)))
            )
          ],
        )
      );

    } catch (e) {
       print("Report Error: $e");
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to report. Please try again.")));
       }
    }
  }



  // Helper removed as it's merged into _submitReport for the specific flow
  // void _showReportConfirmationDialog... (Removed)

  void _showBlockDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Block \"${widget.contact?.name ?? 'Contact'}\"?"),
        content: const Text("You will no longer receive calls or messages."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // STEP 7: CLOSE FIRST

              bool success = false;
              try {
                await _chatService.blockUser(widget.peerId);
                success = true;
              } catch (_) {}

              if (!mounted) return;

              if (success) {
                setState(() {
                  _blockedUserIds.add(widget.peerId);
                  _isPeerOnline = false;
                  _isPeerTyping = false;
                });
                scaffoldMessengerKey.currentState?.showSnackBar(
                  const SnackBar(content: Text("You blocked this contact"))
                );
              } else {
                scaffoldMessengerKey.currentState?.showSnackBar(
                  const SnackBar(content: Text("Failed to block"))
                );
              }
            },
            child: const Text("Block", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
  
  Future<void> _unblockContact() async {
     // Separate API result from UI operations
     bool success = false;
     
     try {
       await _chatService.unblockUser(widget.peerId);
       success = true;
     } catch(e) {
       success = false;
     }
     
     if (!mounted) return;
     
     // Wait a frame to ensure any navigation is complete
     await Future.delayed(Duration.zero);
     
     if (!mounted) return;
     
     // Update state and show feedback based on actual API result
     if (success) {
       setState(() => _blockedUserIds.remove(widget.peerId));
       scaffoldMessengerKey.currentState?.showSnackBar(
         const SnackBar(content: Text("You unblocked this contact"))
       );
     } else {
       scaffoldMessengerKey.currentState?.showSnackBar(
         const SnackBar(content: Text("Failed to unblock"))
       );
     }
  }

  Widget _buildMessageInput() {
     if (_isPeerBlocked) {
       return Container(
         padding: const EdgeInsets.all(16),
         alignment: Alignment.center,
         color: Colors.white,
         child: GestureDetector(
           onTap: _unblockContact,
           child: RichText(
             text: const TextSpan(
               text: "You blocked this contact. Tap to unblock.",
               style: TextStyle(color: Colors.grey, fontSize: 14),
             ),
           ),
         ),
       );
     }
  
     return Padding(
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
                        IconButton(
                          icon: Icon(
                            _isEmojiPickerVisible ? Icons.keyboard : Icons.emoji_emotions_outlined,
                            color: Colors.grey
                          ),
                          onPressed: _toggleEmojiPicker,
                        ),
                        IconButton(
                          icon: Icon(
                             _isStickerPickerVisible ? Icons.layers : Icons.layers_outlined,
                             color: Colors.grey
                          ),
                          onPressed: _toggleStickerPicker,
                        ),
                        Expanded(
                          child: TextField(
                              controller: _messageController,
                              focusNode: _focusNode,
                              decoration: const InputDecoration(
                                hintText: 'Message',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.attach_file, color: Colors.grey), 
                          onPressed: _pickAndSendFile,
                        ),
                        if (!_isTyping) IconButton(icon: const Icon(Icons.camera_alt, color: Colors.grey), onPressed: _pickAndSendMedia),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                if (_isTyping)
                  GestureDetector(
                    onTap: _sendMessage,
                    child: const CircleAvatar(
                      backgroundColor: Color(0xFFC92136),
                      radius: 24,
                      child: Icon(Icons.send, color: Colors.white),
                    ),
                  )
                else
                  VoiceRecorderWidget(
                    onRecordingComplete: _handleVoiceRecording,
                  ),
              ],
            ),
          );
  }

  // --- SEARCH LOGIC ---

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
         _searchController.clear();
         _searchMatches = [];
         _currentMatchIndex = -1;
      }
    });
    if (_isSearching) {
       _searchFocusNode.requestFocus();
    }
  }

  void _executeSearch(String query) async {
     if (query.trim().isEmpty) return;
     setState(() => _isLoadingSearch = true);
     
     try {
       final matches = await _searchService.searchChat(widget.chatId, query);
       // Matches from backend are usually sorted by time (newest first or oldest first depends on backend)
       // We want to navigate them. 
       if (matches.isNotEmpty) {
           setState(() {
             _searchMatches = matches;
             _currentMatchIndex = 0; // Start at first match (usually newest since backend sorts desc)
             _isLoadingSearch = false;
           });
           _scrollToMatch(_currentMatchIndex);
       } else {
           setState(() {
             _searchMatches = [];
             _isLoadingSearch = false;
           });
       }
     } catch (e) {
       setState(() => _isLoadingSearch = false);
       print("Search Error: $e");
     }
  }

  void _nextMatch() {
    if (_searchMatches.isEmpty) return;
    setState(() {
      if (_currentMatchIndex < _searchMatches.length - 1) {
        _currentMatchIndex++;
      } else {
        _currentMatchIndex = 0; // Loop
      }
    });
    _scrollToMatch(_currentMatchIndex);
  }

  void _prevMatch() {
     if (_searchMatches.isEmpty) return;
     setState(() {
       if (_currentMatchIndex > 0) {
         _currentMatchIndex--;
       } else {
         _currentMatchIndex = _searchMatches.length - 1; // Loop
       }
     });
     _scrollToMatch(_currentMatchIndex);
  }

  void _scrollToMatch(int index) {
     final matchId = _searchMatches[index]['_id'];
     // _messages is Newest First. 
     // ListView is reverse: true.
     // So Index 0 is Bottom (Newest). Index N is Top (Oldest).
     // indexWhere returns index in _messages.
     
     final msgIndex = _messages.indexWhere((m) => m['_id'] == matchId);
     if (msgIndex != -1) {
        // Scroll to this index.
        _scrollController.animateTo(
           msgIndex * 70.0, // Approximate height
           duration: const Duration(milliseconds: 300), 
           curve: Curves.easeOut
        );
     } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Message not loaded in view")));
     }
  }

  Widget _buildHighlightText(String text, String query, Color textColor) {
     if (query.isEmpty) return Text(text, style: TextStyle(fontSize: 16, color: textColor));
     
     final matches = query.allMatches(text.toLowerCase());
     if (matches.isEmpty) return Text(text, style: TextStyle(fontSize: 16, color: textColor));
     
     List<TextSpan> spans = [];
     int start = 0;
     final lcText = text.toLowerCase();
     final lcQuery = query.toLowerCase();
     
     int idx = lcText.indexOf(lcQuery);
     while (idx != -1) {
        if (idx > start) {
           spans.add(TextSpan(text: text.substring(start, idx), style: TextStyle(color: textColor)));
        }
        spans.add(TextSpan(
           text: text.substring(idx, idx + query.length),
           style: const TextStyle(backgroundColor: Color(0xFFFFF176), color: Colors.black) // Highlight always black on yellow
        ));
        start = idx + query.length;
        idx = lcText.indexOf(lcQuery, start);
     }
     if (start < text.length) {
        spans.add(TextSpan(text: text.substring(start), style: TextStyle(color: textColor)));
     }
     
     return RichText(text: TextSpan(style: TextStyle(fontSize: 16, color: textColor), children: spans));
  }

  PreferredSizeWidget _buildNormalAppBar() {
    return AppBar(
        titleSpacing: 0,
        backgroundColor: const Color(0xFFC92136),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            AvatarWidget(
              imageUrl: _getFullUrl(widget.isGroup ? _displayAvatar : (widget.contact?.profileImage ?? '')), 
              radius: 18
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () {
                   if (_isPeerBlocked) return; // STEP 4: Profile must vanish
                   
                   if (widget.isGroup) {
                      Navigator.push(context, MaterialPageRoute(builder: (c) => GroupDetailsScreen(chatId: widget.chatId, groupName: widget.groupName ?? 'Group', groupIcon: widget.groupPhoto ?? '')));
                   } else if (widget.contact != null) {
Navigator.push(context, MaterialPageRoute(builder: (c) => ContactInfoScreen(contact: widget.contact!, peerId: widget.peerId, chatId: widget.chatId, userId: widget.peerId)));
                   }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isGroup ? _displayName : (widget.contact?.name ?? 'Unknown'), 
                      style: const TextStyle(fontSize: 18), 
                      overflow: TextOverflow.ellipsis
                    ),
                    if (!widget.isGroup && widget.contact != null && !_isPeerBlocked) // STEP 3: Kill online/typing status
                      _isPeerTyping 
                      ? const Text('Typing...', style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: Color(0xFFC92136))) 
                      : Text(_isPeerOnline ? 'Online' : 'Offline', 
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (!widget.isGroup && !_isPeerBlocked) ...[ // STEP 2: Hard block calls & video calls
            IconButton(
              icon: const Icon(Icons.videocam), 
              onPressed: () {
                // Removed Online Check to allow persistent calls (Push Notifications will wake them up)
                Navigator.push(
                  context, 
                  MaterialPageRoute(
                    builder: (_) => OutgoingCallScreen(
                      peerName: widget.contact?.name ?? 'Unknown',
                      peerAvatar: widget.contact?.profileImage ?? '',
                      peerId: widget.peerId,
                      isVideo: true,
                    )
                  )
                );
              }
            ),
            IconButton(
              icon: const Icon(Icons.call), 
              onPressed: () {
                // Removed Online Check
                
                Navigator.push(
                  context, 
                  MaterialPageRoute(
                    builder: (_) => OutgoingCallScreen(
                      peerName: widget.contact?.name ?? 'Unknown',
                      peerAvatar: widget.contact?.profileImage ?? '',
                      peerId: widget.peerId,
                      isVideo: false,
                    )
                  )
                );
              }
            ),
          ],
          PopupMenuButton<String>(
            onSelected: (value) {
               switch(value) {
                  case 'view_contact': 
                   if (widget.isGroup) {
                      Navigator.push(
                        context, 
                        MaterialPageRoute(
                          builder: (context) => GroupDetailsScreen(
                            chatId: widget.chatId,
                            groupName: widget.groupName ?? 'Group',
                            groupIcon: widget.groupPhoto ?? '',
                          )
                        )
                      );
                   } else if (widget.contact != null) {
                      Navigator.push(context, MaterialPageRoute(builder: (c) => ContactInfoScreen(contact: widget.contact!, peerId: widget.peerId, chatId: widget.chatId, userId: widget.peerId)));
                   }
                   break;
                 case 'search': _toggleSearch(); break;
                 case 'wallpaper': _showWallpaperDialog(); break;
                 case 'report': _showReportDialog(); break;
                 case 'block_toggle': _toggleBlock(); break;
               }
            },
            itemBuilder: (context) {
              return [
                PopupMenuItem(value: 'view_contact', child: Text(widget.isGroup ? 'Group info' : 'View contact')),
                const PopupMenuItem(value: 'search', child: Text('Search')),
                const PopupMenuItem(value: 'wallpaper', child: Text('Wallpaper')),
                if (!widget.isGroup && widget.peerId.isNotEmpty) 
                   PopupMenuItem(
                     value: 'block_toggle', 
                     child: Text(_isPeerBlocked ? 'Unblock' : 'Block')
                   ),
                const PopupMenuItem(value: 'report', child: Text('Report')),
              ];
            }
          ),
        ],
      );
  }

  void _toggleBlock() async {
     if (_isPeerBlocked) {
        // Unblock
        try {
          await _chatService.unblockUser(widget.peerId);
          if (mounted) {
             setState(() {
               _blockedUserIds.remove(widget.peerId);
             });
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Unblocked")));
          }
        } catch(e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to unblock")));
        }
     } else {
        // Block
        bool confirm = await showDialog(
           context: context,
           builder: (context) => AlertDialog(
             title: Text("Block ${widget.contact?.name ?? 'contact'}?"),
             content: const Text("Blocked contacts will no longer be able to call you or send you messages."),
             actions: [
               TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
               TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Block", style: TextStyle(color: Colors.red))),
             ],
           )
        ) ?? false;

        if (confirm) {
            try {
              await _chatService.blockUser(widget.peerId);
               if (mounted) {
                 setState(() {
                   _blockedUserIds.add(widget.peerId);
                 });
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Blocked")));
               }
            } catch(e) {
               if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to block")));
            }
        }
     }
  }

  PreferredSizeWidget _buildSearchBar() {
    return AppBar(
      backgroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.grey),
        onPressed: _toggleSearch,
      ),
      title: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        decoration: const InputDecoration(
          hintText: 'Search...',
          border: InputBorder.none,
        ),
        onSubmitted: _executeSearch,
        textInputAction: TextInputAction.search,
      ),
      actions: [
        if (_searchMatches.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
             child: Center(child: Text("${_currentMatchIndex + 1}/${_searchMatches.length}", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
          ),
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_up, color: Colors.grey),
          onPressed: _prevMatch,
        ),
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
          onPressed: _nextMatch,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
         if (_isSearching) {
            _toggleSearch();
            return false;
         }
         return _onWillPop();
      },
      child: Scaffold(
      backgroundColor: _backgroundColor,
      appBar: _isSearching ? _buildSearchBar() : _buildNormalAppBar(),
      body: Column(
        children: [
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : GestureDetector(
                    onTap: () {
                       _focusNode.unfocus();
                       setState(() => _isEmojiPickerVisible = false);
                    },
                    child: ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final data = _messages[index];
                        
                        final isMe = data['senderId'] == AuthService().currentUserId;
                        final type = data['type'] ?? 'text';
                        final content = data['content'] ?? data['text'] ?? '';
                        final mimeType = (data['mimeType'] ?? '').toString().toLowerCase();
                        
                        int duration = 0;
                        if (data['duration'] != null) {
                             if (data['duration'] is int) duration = data['duration'];
                             else if (data['duration'] is double) duration = (data['duration'] as double).toInt();
                        }


                        if (type == 'system') {
                           return Align(
                             alignment: Alignment.center,
                             child: Container(
                               margin: const EdgeInsets.symmetric(vertical: 8),
                               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                               decoration: BoxDecoration(
                                 color: const Color(0xFFFFF5C4), 
                                 borderRadius: BorderRadius.circular(8),
                                 boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 1)]
                               ),
                               child: Text(content, style: const TextStyle(fontSize: 12, color: Colors.black87), textAlign: TextAlign.center),
                             )
                           );

                        }

                        if (type == 'sticker') {
                            return Align(
                               alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                               child: StickerMessageWidget(message: data, isMe: isMe)
                            );
                        }

                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            decoration: BoxDecoration(
                              color: isMe ? const Color(0xFFC92136) : Colors.white,
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                type == 'voice' || type == 'audio' 
                                ? AudioMessageBubble(
                                    key: ValueKey(data['_id']), 
                                    message: data, // PASS MESSAGE
                                    audioUrl: content,
                                    isSender: isMe,
                                    durationSeconds: duration,
                                  ) 

                                : Builder(
                                    builder: (context) {
                                      // 🧠 MESSAGE CLASSIFICATION LOGIC
                                      // 1️⃣ CAMERA ICON MEDIA (Photo / Video)
                                      if ((type == 'image' && !mimeType.startsWith('video')) || mimeType.startsWith('image/')) {
                                         return MediaBubbleWidget(message: data, isMe: isMe);
                                      }
                                      
                                      if (type == 'video' || mimeType.startsWith('video/')) {
                                         return MediaBubbleWidget(message: data, isMe: isMe);
                                      }

                                      // 2️⃣ ATTACHMENT ICON MEDIA (Paperclip)
                                      if (type == 'file' || type == 'document') { // Removed 'audio' here as it's handled above
                                         return MediaBubbleWidget(message: data, isMe: isMe);
                                      }
                                      
                                      // Fallbacks
                                      if (mimeType.startsWith('image')) return MediaBubbleWidget(message: data, isMe: isMe);
                                      if (mimeType.startsWith('video')) return MediaBubbleWidget(message: data, isMe: isMe);
                                      
                                      if (data.containsKey('filename') || data.containsKey('url')) {
                                         return MediaBubbleWidget(message: data, isMe: isMe);
                                      }

                                      // Default Text with INLINE Timestamp
                                      // We wrap text + timestamp in a Stack/Wrap concept
                                      // 3. New Column Layout (WhatsApp Style)
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                           // Rich Text Content
                                           Padding(
                                             padding: const EdgeInsets.only(right: 48, bottom: 4),
                                             child: _buildHighlightText(
                                                content, 
                                                _isSearching ? _searchController.text : '',
                                                isMe ? Colors.white : Colors.black
                                              ),
                                           ),
                                           const SizedBox(height: 2),
                                           // Timestamp Row (Bottom Right)
                                           Row(
                                             mainAxisSize: MainAxisSize.min,
                                             mainAxisAlignment: MainAxisAlignment.end,
                                             children: [
                                                if (data['expiresAt'] != null)
                                                    Padding(
                                                      padding: const EdgeInsets.only(right: 4),
                                                      child: Icon(Icons.timer_outlined, size: 10, color: isMe ? Colors.white70 : Colors.grey[600]),
                                                    ),
                                                  Text(
                                                    DateFormat('h:mm a').format(
                                                       DateTime.parse(data['timestamp'] ?? data['createdAt'] ?? DateTime.now().toIso8601String()).toLocal()
                                                    ),
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: isMe ? Colors.white70 : Colors.grey[600],
                                                    ),
                                                  ),
                                                  if (isMe) ...[
                                                    const SizedBox(width: 4),
                                                    Icon(
                                                      (data['status'] == 'seen' || data['status'] == 'delivered') 
                                                          ? Icons.done_all 
                                                          : Icons.done,
                                                      size: 14, 
                                                      color: data['status'] == 'seen' 
                                                          ? const Color(0xFF53BDEB) 
                                                          : Colors.white70
                                                    )
                                                  ]
                                             ],
                                           )
                                        ],
                                      );
                                    }
                                  ),
                                  // Removed external SizedBox and Row for timestamp
                                ],
                              ),
                          ),
                        );
                      },
                    ),
                ),
          ),
          
          _buildMessageInput(),

            if (_isEmojiPickerVisible)
            SizedBox(
              height: 250,
              child: EmojiPicker(
                textEditingController: _messageController,
                config: Config(
                   height: 250,
                   checkPlatformCompatibility: true,
                   searchViewConfig: const SearchViewConfig(
                      backgroundColor: Color(0xFFF2F2F2),
                      buttonIconColor: Color(0xFF9575CD),
                   ),
                   emojiViewConfig: EmojiViewConfig(
                      backgroundColor: const Color(0xFFF2F2F2),
                      emojiSizeMax: 32 * (PlatformHelper.isIOS ? 1.30 : 1.0),
                   ),
                   categoryViewConfig: const CategoryViewConfig(
                      backgroundColor: Color(0xFFF2F2F2),
                      indicatorColor: Color(0xFF9575CD),
                      iconColor: Colors.grey,
                      iconColorSelected: Color(0xFF9575CD),
                      backspaceColor: Color(0xFF9575CD),
                   ),
                   bottomActionBarConfig: const BottomActionBarConfig(
                      backgroundColor: Color(0xFFF2F2F2),
                      buttonColor: Color(0xFFF2F2F2),
                      buttonIconColor: Color(0xFF9575CD),
                   ),
                   skinToneConfig: const SkinToneConfig(
                      indicatorColor: Color(0xFF9575CD),
                      dialogBackgroundColor: Colors.white,
                   ),
                ),
              ),
            ),
            
            if (_isStickerPickerVisible)
              SizedBox(
                height: 250,
                child: StickerPickerWidget(
                   onStickerSelected: _sendSticker
                )
              ),
        ],
      ),
      ));
  }
}