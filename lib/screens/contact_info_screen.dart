import 'package:flutter/material.dart';
import 'package:whatsapp_clone/models/contact.dart';
import 'package:whatsapp_clone/services/auth_service.dart';
import 'package:whatsapp_clone/widgets/avatar_widget.dart';
import 'package:whatsapp_clone/theme/app_theme.dart';
import 'package:whatsapp_clone/services/chat_service.dart';
import 'package:intl/intl.dart';
import 'package:whatsapp_clone/main.dart' show scaffoldMessengerKey;

class ContactInfoScreen extends StatefulWidget {
  final Contact contact;
  final String peerId;
  final String chatId;

  const ContactInfoScreen({
    super.key,
    required this.contact,
    required this.peerId,
    required this.chatId,
  });

  @override
  State<ContactInfoScreen> createState() => _ContactInfoScreenState();
}

class _ContactInfoScreenState extends State<ContactInfoScreen> {
  final ChatService _chatService = ChatService();
  final ScrollController _scrollController = ScrollController();
  
  // Purple Theme Colors
  final Color _primaryColor = const Color(0xFFC92136);
  final Color _backgroundColor = const Color(0xFFF5F6F8);
  final Color _iconColor = const Color(0xFFC92136);

  // State
  bool _isBlocked = false;
  List<Map<String, dynamic>> _commonGroups = [];
  bool _muteNotifications = false;
  
  @override
  void initState() {
    super.initState();
    _fetchInitialState();
    _fetchCommonGroups();
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
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildProfileInfo(),
                const SizedBox(height: 10),
                _buildMediaLinkDocs(),
                const SizedBox(height: 10),
                _buildSettingsSection(),
                const SizedBox(height: 10),
                _buildEncryptionSection(),
                const SizedBox(height: 10),
                _buildGroupsSection(),
                const SizedBox(height: 10),
                _buildActionSection(),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 350.0,
      pinned: true,
      backgroundColor: _primaryColor,
      title: Text(widget.contact.name), 
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          alignment: Alignment.bottomLeft,
          children: [
             widget.contact.profileImage.isNotEmpty
                 ? Image.network(widget.contact.profileImage, fit: BoxFit.cover, width: double.infinity, height: double.infinity)
                 : Container(color: Colors.grey[300], child: Icon(Icons.person, size: 150, color: Colors.white)),
             Container(
               decoration: BoxDecoration(
                 gradient: LinearGradient(
                   begin: Alignment.topCenter,
                   end: Alignment.bottomCenter,
                   colors: [Colors.transparent, Colors.black.withOpacity(0.5)],
                 ),
               ),
             ),
             Padding(
               padding: const EdgeInsets.all(16.0),
               child: Text(
                 widget.contact.name,
                 style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
               ),
             ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileInfo() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Text(
             "+1 123 456 7890", 
             style: const TextStyle(fontSize: 18, color: Colors.black87),
           ),
           const SizedBox(height: 4),
           const Text("Mobile", style: TextStyle(color: Colors.grey, fontSize: 13)),
           const SizedBox(height: 20),
           Row(
             mainAxisAlignment: MainAxisAlignment.spaceAround,
             children: [
                _buildActionButton(Icons.call, "Audio"),
                _buildActionButton(Icons.videocam, "Video"),
                _buildActionButton(Icons.search, "Search"),
                _buildActionButton(Icons.attach_money, "Pay"),
             ],
           ),
           const Divider(height: 30),
           Text(
             "Hey there! I am using WhatsApp.",
             style: const TextStyle(fontSize: 16, color: Colors.black87),
           ),
           const SizedBox(height: 4),
           Text(
             DateFormat('MMMM dd, yyyy').format(DateTime.now()),
             style: const TextStyle(color: Colors.grey, fontSize: 13),
           ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label) {
    return GestureDetector(
      onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$label action tapped")));
      },
      child: Column(
        children: [
          Icon(icon, color: _primaryColor, size: 28),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: _primaryColor, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildMediaLinkDocs() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
           Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
               const Text("Media, links, and docs", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
               Row(
                 children: const [
                   Text("120", style: TextStyle(color: Colors.grey, fontSize: 14)), 
                   Icon(Icons.keyboard_arrow_right, color: Colors.grey),
                 ],
               )
             ],
           ),
           const SizedBox(height: 12),
           SizedBox(
             height: 80,
             child: ListView.separated(
               scrollDirection: Axis.horizontal,
               itemCount: 6,
               separatorBuilder: (c, i) => const SizedBox(width: 8),
               itemBuilder: (c, i) {
                  return Container(
                    width: 75,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!)
                    ),
                    child: Center(
                      child: Icon(Icons.image, color: Colors.grey[400]),
                    ),
                  );
               },
             ),
           )
        ],
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          _buildListTile(
            "Mute notifications", 
            icon: Icons.notifications_off_outlined,
            onTap: _showMuteDialog,
          ),
          const Divider(height: 1, indent: 60),
          _buildListTile("Custom notifications", icon: Icons.tune),
          const Divider(height: 1, indent: 60),
          _buildListTile("Media visibility", icon: Icons.image),
           const Divider(height: 1, indent: 60),
          _buildListTile("Starred messages", icon: Icons.star_border), 
           const Divider(height: 1, indent: 60),
           _buildListTile("Translate messages", icon: Icons.translate), 
        ],
      ),
    );
  }

  Widget _buildEncryptionSection() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          _buildListTile(
            "Encryption", 
            subtitle: "Messages and calls are end-to-end encrypted. Tap to verify.",
            icon: Icons.lock_outline
          ),
          const Divider(height: 1, indent: 60),
          _buildListTile(
            "Disappearing messages", 
            subtitle: "Off",
            icon: Icons.timer_outlined,
            onTap: _showDisappearingDialog,
          ),
        ],
      ),
    );
  }
  
  Widget _buildGroupsSection() {
      return Container(
        color: Colors.white,
        child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text("${_commonGroups.length} group${_commonGroups.length != 1 ? 's' : ''} in common", style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500)),
              ),
              _buildListTile(
                 "Create group with ${widget.contact.name}", 
                 icon: Icons.group_add_outlined, 
                 isAction: true,
              ),
              const Divider(height: 1, indent: 60),
              ..._commonGroups.map((g) => ListTile(
                 leading: AvatarWidget(imageUrl: g['groupPhoto'] ?? '', radius: 20),
                 title: Text(g['groupName'] ?? 'Group'),
                 subtitle: Text("${(g['participants'] as List?)?.length ?? 0} participants"),
                 onTap: () {}, 
               )),
           ],
        ),
      );
  }

  Widget _buildActionSection() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          _buildActionTile(
            _isBlocked ? "Unblock ${widget.contact.name}" : "Block ${widget.contact.name}", 
            Icons.block, 
            Colors.red, 
            _toggleBlock
          ),
          const Divider(height: 1, indent: 60),
          _buildActionTile("Report ${widget.contact.name}", Icons.thumb_down_alt_outlined, Colors.red, _showReportDialog), 
        ],
      ),
    );
  }

  Widget _buildListTile(String title, {String? subtitle, IconData? icon, Widget? trailing, bool isAction = false, VoidCallback? onTap}) {
     return ListTile(
       leading: icon != null ? Icon(icon, color: isAction ? _primaryColor : Colors.grey[600]) : null,
       title: Text(title, style: const TextStyle(fontSize: 16)),
       subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.grey)) : null,
       trailing: trailing,
       onTap: onTap,
     );
  }

  Widget _buildActionTile(String title, IconData icon, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color, fontSize: 16)),
      onTap: onTap,
    );
  }

  // --- ACTIONS ---

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
