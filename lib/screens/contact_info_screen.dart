import 'package:flutter/material.dart';
import 'package:whatsapp_clone/models/contact.dart';
import 'package:whatsapp_clone/services/auth_service.dart';
import 'package:whatsapp_clone/widgets/avatar_widget.dart';
import 'package:whatsapp_clone/theme/app_theme.dart';
import 'package:whatsapp_clone/services/chat_service.dart';
import 'package:intl/intl.dart';
import 'package:whatsapp_clone/main.dart' show scaffoldMessengerKey;
import 'package:whatsapp_clone/models/user_model.dart';
import 'package:whatsapp_clone/services/user_service.dart';
import 'package:whatsapp_clone/config/api_config.dart'; // For Base URL if needed, or stick to model

class ContactInfoScreen extends StatefulWidget {
  final Contact contact;
  final String peerId;
  final String chatId;
  final String userId; // Add userId

  const ContactInfoScreen({
    super.key,
    required this.contact,
    required this.peerId,
    required this.chatId,
    required this.userId, // Required now
  });

  @override
  State<ContactInfoScreen> createState() => _ContactInfoScreenState();
}

class _ContactInfoScreenState extends State<ContactInfoScreen> {
  final ChatService _chatService = ChatService();
  final UserService _userService = UserService(); // UserService
  final ScrollController _scrollController = ScrollController();
  
  // Purple Theme Colors
  final Color _primaryColor = const Color(0xFFC92136);
  final Color _backgroundColor = const Color(0xFFF5F6F8);
  final Color _iconColor = const Color(0xFFC92136);

  // State
  bool _isBlocked = false;
  List<Map<String, dynamic>> _commonGroups = [];
  bool _muteNotifications = false;
  UserModel? _user; // User Model for dynamic data
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _fetchInitialState();
    _fetchCommonGroups();
    _fetchUserData(); // Fetch user data
  }

  Future<void> _fetchUserData() async {
    final user = await _userService.getUserProfile(widget.userId);
    if (mounted) {
       setState(() {
         _user = user;
         _isLoading = false;
       });
    }
  }

  Future<void> _fetchInitialState() async {
    try {
      final blockedUsers = await _chatService.getBlockedUsers();
      if (mounted) {
        setState(() {
          _isBlocked = blockedUsers.contains(widget.peerId);
        });
      }
    } catch (e) {
      print("Error fetching initial state: $e");
    }
  }

  Future<void> _fetchCommonGroups() async {
     try {
       final allChats = await _chatService.getMyChats();
       final common = allChats.where((chat) {
          final isGroup = chat['isGroup'] == true;
          if (!isGroup) return false;
          
          final participants = chat['participants'];
          if (participants is List) {
             return participants.any((p) {
                if (p is Map) return p['_id'] == widget.peerId || p['firebaseUid'] == widget.peerId;
                return p == widget.peerId;
             });
          }
          return false;
       }).toList();
       
       if (mounted) {
         setState(() {
           _commonGroups = common;
         });
       }
     } catch (e) {
       print("Error fetching common groups: $e");
     }
  }

  @override
  Widget build(BuildContext context) {
    // Resolve Image URL
    final String? backendAvatar = _user?.profilePhotoUrl;
    final String? contactAvatar = widget.contact.profileImage;
    String displayImage = '';
    
    if (backendAvatar != null && backendAvatar.isNotEmpty) {
      displayImage = ApiConfig.getFullImageUrl(backendAvatar);
    } else if (contactAvatar != null && contactAvatar.isNotEmpty) {
       displayImage = ApiConfig.getFullImageUrl(contactAvatar);
    }

    // Resolve Name (Prioritize Saved Contact Name)
    final String displayName = widget.contact.name.isNotEmpty 
        ? widget.contact.name 
        : (_user?.name ?? 'Unknown');

    // Resolve Phone
    final String displayPhone = _user?.phoneNumber.isNotEmpty == true 
        ? "+${_user!.phoneNumber}" 
        : "+91 XXXXX XXXXX"; // Fallback or maybe widget.contact doesn't have phone easily accessible here without lookup, but usually we prefer backend phone if available.

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Contact Info", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            
            // 1. Profile Photo
            Center(
              child: CircleAvatar(
                radius: 55,
                backgroundColor: Colors.grey[200],
                backgroundImage: displayImage.isNotEmpty ? NetworkImage(displayImage) : null,
                child: displayImage.isEmpty ? const Icon(Icons.person, size: 60, color: Colors.grey) : null,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 2. Display Name
            Text(
              displayName,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 8),
            
            // 3. Phone Number
            Text(
              displayPhone,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 20),
            const Divider(thickness: 0.5),
            const SizedBox(height: 10),
            
            // 4. Actions (Block & Report)
            ListTile(
              leading: const Icon(Icons.block, color: Colors.red),
              title: Text(_isBlocked ? "Unblock Contact" : "Block Contact", style: const TextStyle(color: Colors.red, fontSize: 16)),
              onTap: _toggleBlock,
            ),
            
            ListTile(
              leading: const Icon(Icons.thumb_down_alt_outlined, color: Colors.red),
              title: const Text("Report Contact", style: TextStyle(color: Colors.red, fontSize: 16)),
              onTap: _showReportDialog,
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // --- ACTIONS (Logic Preserved) ---


  
  // ... Keeping _toggleBlock and _showReportDialog ...


  void _showMuteDialog() {
    int? selectedValue = 0; 
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
                 value: 0, groupValue: selectedValue, onChanged: (v) => setDialogState(() => selectedValue = v),
                 activeColor: _primaryColor,
               ),
               RadioListTile<int>(
                 title: const Text("1 week"),
                 value: 1, groupValue: selectedValue, onChanged: (v) => setDialogState(() => selectedValue = v),
                 activeColor: _primaryColor,
               ),
               RadioListTile<int>(
                 title: const Text("Always"),
                 value: 2, groupValue: selectedValue, onChanged: (v) => setDialogState(() => selectedValue = v),
                 activeColor: _primaryColor,
               ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel", style: TextStyle(color: _primaryColor))),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                   DateTime? until;
                   if (selectedValue == 0) until = DateTime.now().add(const Duration(hours: 8));
                   else if (selectedValue == 1) until = DateTime.now().add(const Duration(days: 7));
                   String? muteUntil = (selectedValue == 2) ? 'permanent' : until?.toIso8601String();
                   await _chatService.muteChat(widget.chatId, muteUntil);
                   if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Notifications muted")));
                } catch(e) {
                   if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to mute")));
                }
              }, 
              child: Text("OK", style: TextStyle(color: _primaryColor))
            ),
          ],
        ),
      ),
    );
  }

  void _showDisappearingDialog() {
    int selectedValue = 0; 
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
               RadioListTile<int>(title: const Text("24 hours"), value: 86400, groupValue: selectedValue, onChanged: (v) => setDialogState(() => selectedValue = v!), activeColor: _primaryColor),
               RadioListTile<int>(title: const Text("7 days"), value: 604800, groupValue: selectedValue, onChanged: (v) => setDialogState(() => selectedValue = v!), activeColor: _primaryColor),
               RadioListTile<int>(title: const Text("90 days"), value: 7776000, groupValue: selectedValue, onChanged: (v) => setDialogState(() => selectedValue = v!), activeColor: _primaryColor),
               RadioListTile<int>(title: const Text("Off"), value: 0, groupValue: selectedValue, onChanged: (v) => setDialogState(() => selectedValue = v!), activeColor: _primaryColor),
             ],
          ),
          actions: [
             TextButton(
              onPressed: () async {
                 Navigator.pop(context);
                 try {
                    await _chatService.setDisappearingTimer(widget.chatId, selectedValue);
                    if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Disappearing messages updated")));
                 } catch(e) {}
              },
              child: Text("OK", style: TextStyle(color: _primaryColor))
            )
          ],
        ),
      )
    );
  }

  void _toggleBlock() async {
     if (_isBlocked) {
        // Unblock - Separate API result from UI operations
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
        
        if (success) {
          setState(() => _isBlocked = false);
          scaffoldMessengerKey.currentState?.showSnackBar(const SnackBar(content: Text("Unblocked")));
        } else {
          scaffoldMessengerKey.currentState?.showSnackBar(const SnackBar(content: Text("Failed to unblock")));
        }
     } else {
        // Confirm Block
         showDialog(
           context: context,
           builder: (context) => AlertDialog(
             title: Text("Block ${widget.contact.name}?"),
             content: const Text("Blocked contacts will no longer be able to call you or send you messages."),
             actions: [
               TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel", style: TextStyle(color: _primaryColor))),
               TextButton(
                 onPressed: () async {
                   // Separate API result from UI operations
                   bool success = false;
                   
                   try {
                     await _chatService.blockUser(widget.peerId);
                     success = true;
                   } catch(e) {
                     success = false;
                   }
                   
                   if (!mounted) return;
                   
                   // Close dialog first
                   Navigator.pop(context);
                   
                   // Wait a frame to ensure dialog is fully closed
                   await Future.delayed(Duration.zero);
                   
                   if (!mounted) return;
                   
                   // Update state and show feedback based on actual API result
                   if (success) {
                     setState(() => _isBlocked = true);
                     scaffoldMessengerKey.currentState?.showSnackBar(const SnackBar(content: Text("Blocked")));
                   } else {
                     scaffoldMessengerKey.currentState?.showSnackBar(const SnackBar(content: Text("Failed to block")));
                   }
                 },
                 child: const Text("Block", style: TextStyle(color: Colors.red)),
               )
             ],
           )
         );
     }
  }

  void _showReportDialog() {
     bool blockContact = true; 
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text("Report \"${widget.contact.name}\" to WhatsApp?"), 
          content: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
               const Text("The last 5 messages will be forwarded. No one in this chat will be notified."),
               const SizedBox(height: 10),
               Row(
                 children: [
                   Checkbox(value: blockContact, onChanged: (v) => setState(() => blockContact = v!), activeColor: _primaryColor),
                   Expanded(child: Text("Block ${widget.contact.name} and delete chat"))
                 ],
               )
             ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Cancel", style: TextStyle(color: _primaryColor))),
            TextButton(
              onPressed: () async {
                 Navigator.pop(ctx); 
                 try {
                    await _chatService.reportChat(widget.chatId, reportedUserId: widget.peerId, blockUser: blockContact, deleteChat: blockContact, reason: 'user_report');
                    if (mounted) {
                       showDialog(
                         context: context, 
                         builder: (c) => AlertDialog(title: const Text("Reported"), content: const Text("Thank you for your report."), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("OK"))])
                       );
                    }
                 } catch(e) {}
              },
              child: Text("Report", style: TextStyle(color: _primaryColor))
            )
          ],
        ),
      )
    );
  }
}
