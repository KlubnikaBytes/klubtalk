
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
import 'package:whatsapp_clone/models/sticker_model.dart';

import 'package:whatsapp_clone/screens/call/call_screen.dart';

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

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  Timer? _pollingTimer;
  bool _isTyping = false;
  bool _isEmojiPickerVisible = false;
  bool _isStickerPickerVisible = false;
  Set<String> _blockedUserIds = {};

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

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _checkBlockStatus();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
       _loadMessages(updateLoading: false);
    });

    _messageController.addListener(() {
      setState(() {
        _isTyping = _messageController.text.trim().isNotEmpty;
      });
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
  void dispose() {
    _pollingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _checkBlockStatus() async {
     if (widget.peerId.isEmpty) return; // Don't check for groups or invalid peers
     
     try {
       final blockedList = await _chatService.getBlockedUsers();
       print("DEBUG: Fetched blocked list: $blockedList");
       
       if (mounted) {
         setState(() {
           _blockedUserIds = blockedList.toSet();
         });
         print("DEBUG: Checking if '${widget.peerId}' is in blocked list. Result: $_isPeerBlocked");
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
     final tempId = DateTime.now().millisecondsSinceEpoch.toString();
     final optimisticMessage = {
       '_id': tempId,
       'chatId': widget.chatId,
       'senderId': FirebaseAuth.instance.currentUser?.uid,
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
       await _chatService.sendStickerMessage(widget.chatId, sticker.imageUrl);
       _loadMessages(updateLoading: false);
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
          _messages = messages;
          _isLoading = false;
        });
        if (updateLoading) {
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
    if (_messageController.text.trim().isEmpty) return;
    String text = _messageController.text;
    _messageController.clear();
    
    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    final optimisticMessage = {
      '_id': tempId,
      'chatId': widget.chatId,
      'senderId': FirebaseAuth.instance.currentUser?.uid,
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
      await _chatService.sendMessage(widget.chatId, text);
      _loadMessages(updateLoading: false);
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
      try {
        await _chatService.sendVoiceMessage(widget.chatId, path, duration);
        _loadMessages(updateLoading: false);
        _scrollToBottom();
      } catch (e) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
      }
  }

  Future<void> _pickAndSendMedia() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? media = await picker.pickMedia(); 
      if (media != null) {
          print("DEBUG: Media Path: ${media.path}");
          print("DEBUG: XFile Mime: ${media.mimeType}");
          
          String mimeType = media.mimeType ?? lookupMimeType(media.path) ?? '';
          print("DEBUG: Initial Resolved Mime: $mimeType");
          
          // Fallback: Read header bytes if mimeType is still unknown
          if (mimeType.isEmpty) {
             try {
                final bytes = await media.readAsBytes(); // Read file to check magic numbers
                final headerBytes = bytes.take(12).toList();
                mimeType = lookupMimeType(media.path, headerBytes: headerBytes) ?? '';
                print("DEBUG: Detected Mime from bytes: $mimeType");
             } catch (e) {
                print("DEBUG: Failed to read bytes for mime detection: $e");
             }
          }

          print("DEBUG: Final MimeType: $mimeType");

          if (mimeType.startsWith('video/')) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Uploading video...')));
              await _chatService.sendVideoMessage(widget.chatId, media.path, mimeType: mimeType);
          } else if (mimeType.startsWith('image/')) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Uploading image...')));
              await _chatService.sendImageMessage(widget.chatId, media.path, mimeType: mimeType);
          } else {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unsupported media type: $mimeType for ${media.path}')));
             return;
          }

          _loadMessages(updateLoading: false);
          _scrollToBottom();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _pickAndSendFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any, 
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Uploading file...')));
        
        await _chatService.sendFileMessage(widget.chatId, path);
        
        _loadMessages(updateLoading: false);
        _scrollToBottom();
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
       Colors.white, const Color(0xFFECE5DD), const Color(0xFFDCF8C6), 
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
        content: const Text("Blocked contacts will no longer be able to call you or send you messages."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close Dialog
              try {
                await _chatService.blockUser(widget.peerId);
                if(mounted) {
                  setState(() => _blockedUserIds.add(widget.peerId));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You blocked this contact")));
                }
              } catch(e) {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to block")));
              }
            },
            child: const Text("Block", style: TextStyle(color: Colors.red)),
          )
        ],
      )
    );
  }
  
  Future<void> _unblockContact() async {
     try {
       await _chatService.unblockUser(widget.peerId);
       setState(() => _blockedUserIds.remove(widget.peerId));
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You unblocked this contact")));
     } catch(e) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to unblock")));
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
                      backgroundColor: Color(0xFF9575CD),
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
     // Find index in _messages
     // _messages is sorted? usually newest at index 0 if reverse is true?
     // ListView is reverse: true. So index 0 is bottom (newest).
     // Backend returns matches. If backend sorts timestamp desc, match 0 is newest.
     
     final msgIndex = _messages.indexWhere((m) => m['_id'] == matchId);
     if (msgIndex != -1) {
        // Scroll to this index.
        // Rough estimation: 70 pixels per message
        _scrollController.animateTo(
           msgIndex * 70.0, 
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
        backgroundColor: const Color(0xFF9575CD),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            AvatarWidget(imageUrl: (widget.isGroup ? widget.groupPhoto : widget.contact?.profileImage) ?? '', radius: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.isGroup ? (widget.groupName ?? 'Group') : (widget.contact?.name ?? 'Unknown'), style: const TextStyle(fontSize: 18), overflow: TextOverflow.ellipsis),
                  if (!widget.isGroup && widget.contact != null)
                    Text(widget.contact!.isOnline ? 'Online' : 'Offline', 
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (!widget.isGroup) ...[
            IconButton(
              icon: const Icon(Icons.videocam), 
              onPressed: () {
                Navigator.push(
                  context, 
                  MaterialPageRoute(
                    builder: (context) => CallScreen(
                      peerName: widget.isGroup ? (widget.groupName ?? 'Group') : (widget.contact?.name ?? 'Unknown'),
                      peerAvatar: (widget.isGroup ? widget.groupPhoto : widget.contact?.profileImage) ?? '',
                      isCaller: true,
                      peerId: widget.peerId, // This is the firebaseUid of the other user
                      isVideo: true,
                    )
                  )
                );
              }
            ),
            IconButton(
              icon: const Icon(Icons.call), 
              onPressed: () {
                Navigator.push(
                  context, 
                  MaterialPageRoute(
                    builder: (context) => CallScreen(
                      peerName: widget.isGroup ? (widget.groupName ?? 'Group') : (widget.contact?.name ?? 'Unknown'),
                      peerAvatar: (widget.isGroup ? widget.groupPhoto : widget.contact?.profileImage) ?? '',
                      isCaller: true,
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
                   } else {
                      // Navigate to Contact Info
                   }
                   break;
                 case 'media': 
                   if (widget.isGroup) {
                      Navigator.push(
                        context, 
                        MaterialPageRoute(
                          builder: (context) => GroupMediaScreen(
                            chatId: widget.chatId,
                            groupName: widget.groupName ?? 'Group',
                          )
                        )
                      );
                   }
                   break;
                 case 'search': _toggleSearch(); break;
                 case 'mute': _showMuteDialog(); break;
                 case 'disappearing': _showDisappearingDialog(); break;
                 case 'wallpaper': _showWallpaperDialog(); break;
                 case 'more': break;
                 case 'report': _showReportDialog(); break;
                 case 'block': _showBlockDialog(); break;
               }
            },
            itemBuilder: (context) {
              return [
                PopupMenuItem(value: 'view_contact', child: Text(widget.isGroup ? 'Group info' : 'View contact')),
                PopupMenuItem(value: 'media', child: Text(widget.isGroup ? 'Group media' : 'Media, links, and docs')),
                const PopupMenuItem(value: 'search', child: Text('Search')),
                const PopupMenuItem(value: 'mute', child: Text('Mute notifications')),
                const PopupMenuItem(value: 'disappearing', child: Text('Disappearing messages')),
                const PopupMenuItem(value: 'wallpaper', child: Text('Wallpaper')),
                const PopupMenuItem(value: 'report', child: Text('Report')),
                if (!widget.isGroup && widget.peerId.isNotEmpty) const PopupMenuItem(value: 'block', child: Text('Block')),
                const PopupMenuItem(value: 'more', child: Text('More')), 
              ];
            }
          ),
        ],
      );
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
                        final reversedIndex = _messages.length - 1 - index;
                        final data = _messages[reversedIndex];
                        
                        final isMe = data['senderId'] == FirebaseAuth.instance.currentUser?.uid;
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                type == 'voice' 
                                ? AudioMessageBubble(
                                    key: ValueKey(data['_id']), 
                                    audioUrl: content,
                                    isSender: isMe,
                                    durationSeconds: duration,
                                  ) 

                                : Builder(
                                    builder: (context) {
                                      // 🧠 MESSAGE CLASSIFICATION LOGIC
                                      // 1️⃣ CAMERA ICON MEDIA (Photo / Video)
                                      // STRICT: Only render as Image if type is image OR mime is image (and not video)
                                      if ((type == 'image' && !mimeType.startsWith('video')) || mimeType.startsWith('image/')) {
                                         return MediaBubbleWidget(message: data, isMe: isMe);
                                      }
                                      
                                      // STRICT: Only render as Video if type is video OR mime is video
                                      if (type == 'video' || mimeType.startsWith('video/')) {
                                         return MediaBubbleWidget(message: data, isMe: isMe);
                                      }

                                      // 2️⃣ ATTACHMENT ICON MEDIA (Paperclip) -> Document Bubble
                                      if (type == 'file' || type == 'document' || type == 'audio') {
                                         return MediaBubbleWidget(message: data, isMe: isMe);
                                      }
                                      
                                      // Fallback for mixed cases (e.g. file sent as image via old endpoint but mime is distinct)
                                      if (mimeType.startsWith('image')) return MediaBubbleWidget(message: data, isMe: isMe);
                                      if (mimeType.startsWith('video')) return MediaBubbleWidget(message: data, isMe: isMe);
                                      
                                      // Final Fallback for unclassified files
                                      if (data.containsKey('filename') || data.containsKey('url')) {
                                         return MediaBubbleWidget(message: data, isMe: isMe);
                                      }

                                      // Default Text
                                      return _buildHighlightText(
                                        content, 
                                        _isSearching ? _searchController.text : '',
                                        isMe ? Colors.white : Colors.black
                                      );
                                    }
                                  ),

                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (data['expiresAt'] != null)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 4),
                                        child: Icon(Icons.timer_outlined, size: 10, color: isMe ? Colors.white70 : Colors.grey[600]),
                                      ),
                                    Text(
                                      data['timestamp'] != null 
                                        ? DateFormat('h:mm a').format(DateTime.parse(data['timestamp']).toLocal())
                                        : '',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isMe ? Colors.white70 : Colors.grey[600],
                                      ),
                                    ),
                                    if (isMe) ...[
                                      const SizedBox(width: 4),
                                      const Icon(Icons.done_all, size: 14, color: Colors.white70)
                                    ]
                                  ],
                                )
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
