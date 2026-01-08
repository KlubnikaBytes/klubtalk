import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:whatsapp_clone/models/contact.dart';
import 'package:whatsapp_clone/screens/chat_screen.dart';
import 'package:whatsapp_clone/screens/new_chat_screen.dart';
import 'package:whatsapp_clone/screens/group_participant_select_screen.dart';
import 'package:whatsapp_clone/screens/settings/settings_screen.dart';
import 'package:whatsapp_clone/services/chat_service.dart';
import 'package:whatsapp_clone/widgets/avatar_widget.dart';
import 'package:intl/intl.dart';
import 'package:whatsapp_clone/utils/chat_session_store.dart';
import 'package:whatsapp_clone/utils/platform_helper.dart';

class MobileChatLayout extends StatefulWidget {
  final bool isWeb;
  final Function(Contact, String, String)? onChatSelected;

  const MobileChatLayout({
    super.key,
    this.isWeb = false,
    this.onChatSelected,
  });

  @override
  State<MobileChatLayout> createState() => _MobileChatLayoutState();
}

class _MobileChatLayoutState extends State<MobileChatLayout> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messaging App', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.camera_alt_outlined), onPressed: () {}),
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'Settings') {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
              } else if (value == 'New group') {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const GroupParticipantSelectScreen()));
              } else if (value == 'Archived') {
                Navigator.push(
                  context, 
                  MaterialPageRoute(
                    builder: (context) => Scaffold(
                      appBar: AppBar(title: const Text("Archived")),
                      body: ChatListScreen(isWeb: widget.isWeb, filter: 'archived', onChatSelected: widget.onChatSelected)
                    )
                  )
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'New group', child: Text('New group')),
              const PopupMenuItem(value: 'New community', child: Text('New community')),
              const PopupMenuItem(value: 'Archived', child: Text('Archived')),
              const PopupMenuItem(value: 'Broadcast lists', child: Text('Broadcast lists')),
              const PopupMenuItem(value: 'Linked devices', child: Text('Linked devices')),
              const PopupMenuItem(value: 'Starred', child: Text('Starred')),
              const PopupMenuItem(value: 'Payments', child: Text('Payments')),
              const PopupMenuItem(value: 'Settings', child: Text('Settings')),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
             Tab(text: 'All'),
             Tab(text: 'Unread'),
             Tab(text: 'Favorites'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
           // All Chats
           ChatListScreen(
             filter: 'all', 
             isWeb: widget.isWeb,
             onChatSelected: widget.onChatSelected,
           ),
           // Unread Chats
           ChatListScreen(
             filter: 'unread',
             isWeb: widget.isWeb,
             onChatSelected: widget.onChatSelected,
           ),
           // Favorites
           ChatListScreen(
             filter: 'favorites',
             isWeb: widget.isWeb,
             onChatSelected: widget.onChatSelected,
           ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF9575CD),
        child: const Icon(Icons.message, color: Colors.white),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NewChatScreen()),
          );
        },
      ),
    );
  }
}

class ChatListScreen extends StatefulWidget {
  final bool isWeb;
  final String filter; // 'all', 'unread', 'favorites', 'archived'
  final Function(Contact, String, String)? onChatSelected;

  const ChatListScreen({
    super.key, 
    this.isWeb = false,
    this.filter = 'all',
    this.onChatSelected,
  });

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ChatService _chatService = ChatService();
  final ChatSessionStore _store = ChatSessionStore();
  
  List<Map<String, dynamic>> _chats = [];
  bool _isLoading = true;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _loadChats();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) => _loadChats(updateLoading: false));
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadChats({bool updateLoading = true}) async {
    try {
      if (updateLoading && mounted) setState(() => _isLoading = true);
      
      final chats = await _chatService.getMyChats();
      
      if (mounted) {
        setState(() {
          _chats = chats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && updateLoading) setState(() => _isLoading = false);
    }
  }

  void _handleAction(String chatId, String action, Map<String, dynamic> chatData) async {
    switch (action) {
      case 'archive':
        await _chatService.toggleArchive(chatId);
        _loadChats(updateLoading: false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Chat archived")));
        break;
      case 'unarchive':
         await _chatService.toggleArchive(chatId);
         _loadChats(updateLoading: false);
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Chat unarchived")));
         break;
      case 'mute':
        _store.muteChat(chatId);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Notifications muted")));
        break;
      case 'unmute':
        _store.unmuteChat(chatId);
        break;
      case 'favorite':
        await _chatService.toggleFavorite(chatId); 
        _loadChats(updateLoading: false);
        break;
      case 'mark_unread':
        _store.markUnread(chatId);
        break;
      case 'mark_read':
        _store.markRead(chatId);
        break;
      case 'delete':
        _store.deleteChat(chatId);
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Chat deleted")));
        break;
       case 'exit_group':
        _store.deleteChat(chatId);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Exited group")));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    // Listen to store changes to trigger rebuilds
    return AnimatedBuilder(
      animation: Listenable.merge([
        _store.archivedChatIds,
        _store.mutedChatIds,
        _store.markedUnreadChatIds,
        _store.deletedChatIds
      ]),
      builder: (context, child) {
        
        final currentUid = FirebaseAuth.instance.currentUser?.uid;
        
        // 1. Filter Logic
        final docs = _chats.where((chatData) {
           final chatId = chatData['_id'] ?? chatData['id'];
           if (_store.isDeleted(chatId)) return false;

           final isArchivedLocal = _store.isArchived(chatId);
           final isArchivedServer = (chatData['isArchivedSelf'] as bool? ?? false);
           // PRIORITIZE SERVER: If server says archived, it is archived. 
           // If local says archived (legacy/offline), we can respect it OR drop it.
           // Since we are enforcing backend persistence, we should rely on server state from _loadChats.
           // However, to keep UI snappy, we reload chats after action.
           final isArchived = isArchivedServer; 

           // ARCHIVED TAB: Show ONLY archived
           if (widget.filter == 'archived') {
             return isArchived;
           }

           // OTHER TABS: Show ONLY NON-archived
           if (isArchived) return false;

           final isFavorite = (chatData['isFavoriteSelf'] as bool?) ?? false;
           
           var unreadCount = (chatData['unreadCountSelf'] as num?)?.toInt() ?? 0;
           if (_store.isMarkedUnread(chatId)) unreadCount = 1; 
           // If manually marked "read" but backend says unread? 
           // We can track markRead in store too if needed, but for now markUnread is priority.
           
           if (widget.filter == 'unread') {
             if (unreadCount == 0 && !_store.isMarkedUnread(chatId)) return false;
           }

           if (widget.filter == 'favorites' && !isFavorite) return false;
           
           return true;
        }).toList();

        // 2. Count Archived for "Archived Row"
        int archivedCount = 0;
        if (widget.filter == 'all') {
             // We need to count how many archived chats exist totally
             archivedCount = _chats.where((c) {
                 final cid = c['_id'] ?? c['id'];
                 return !_store.isDeleted(cid) && (c['isArchivedSelf'] as bool? ?? false);
             }).length;
        }

        /* 
           If No Chats:
           But if we have archived chats and we are in 'All', we should still show the Archived Row even if docs (main chats) is empty?
           Yes. The Archived Row is item 0.
        */
        if (docs.isEmpty && archivedCount == 0 && widget.filter != 'archived') {
          return Center(
            child: Text(
              widget.filter == 'all' ? 'No chats' : 'No ${widget.filter} chats', 
              style: const TextStyle(color: Colors.grey)
          ));
        }
        
        // 3. ListView
        return ListView.builder(
          itemCount: docs.length + (archivedCount > 0 && widget.filter == 'all' ? 1 : 0),
          itemBuilder: (context, index) {
            
            // Render Archived Row at Top (Only in 'All' tab)
            if (widget.filter == 'all' && archivedCount > 0 && index == 0) {
               return ListTile(
                 leading: const Padding(
                   padding: EdgeInsets.only(left: 8.0),
                   child: Icon(Icons.archive_outlined, color: Color(0xFF075E54)),
                 ),
                 title: const Text("Archived", style: TextStyle(fontWeight: FontWeight.bold)),
                 trailing: Text("$archivedCount", style: const TextStyle(color: Color(0xFF075E54))),
                 onTap: () {
                    Navigator.push(
                      context, 
                      MaterialPageRoute(
                        builder: (context) => Scaffold(
                          appBar: AppBar(title: const Text("Archived")),
                          body: ChatListScreen(isWeb: widget.isWeb, filter: 'archived', onChatSelected: widget.onChatSelected)
                        )
                      )
                    );
                 },
               );
            }

            final chatIndex = (widget.filter == 'all' && archivedCount > 0) ? index - 1 : index;
            final chatData = docs[chatIndex];
            final chatId = chatData['_id'] ?? chatData['id'];
            
            final participants = List<String>.from(chatData['participants'] ?? []);
            final participantsDetails = List<Map<String, dynamic>>.from(chatData['participantsDetails'] ?? []);
            
            final isFavorite = (chatData['isFavoriteSelf'] as bool?) ?? false;
            bool isMuted = false;
            if (chatData['muteUntil'] is Map && currentUid != null) {
                final untilVal = chatData['muteUntil'][currentUid];
                if (untilVal == 'permanent') {
                   isMuted = true;
                } else if (untilVal is String) {
                   final date = DateTime.tryParse(untilVal);
                   if (date != null && date.isAfter(DateTime.now())) {
                      isMuted = true;
                   }
                }
            }
            
            var unreadCount = (chatData['unreadCountSelf'] as num?)?.toInt() ?? 0;
            if (_store.isMarkedUnread(chatId)) unreadCount = unreadCount > 0 ? unreadCount : 1;
            
            // Determine Archive State for Menu
            final isArchived = widget.filter == 'archived' || (chatData['isArchivedSelf'] as bool? ?? false); 

            final isGroup = chatData['isGroup'] == true;
            
            // Name/Avatar Logic
            String name = '', avatarUrl = '', lastMsgText = '';
            if (isGroup) {
                 name = chatData['groupName'] ?? 'Group';
                 avatarUrl = '';
            } else {
                 final peerId = participants.firstWhere((id) => id != currentUid, orElse: () => 'Unknown');
                 final peerData = participantsDetails.firstWhere((u) => u['firebaseUid'] == peerId, orElse: () => {});
                 name = peerData['name'] ?? 'Unknown';
                 avatarUrl = peerData['avatar'] ?? '';
                 if (avatarUrl.isEmpty) avatarUrl = 'https://ui-avatars.com/api/?name=$name';
            }

            if (chatData['lastMessage'] is Map) {
                final lm = chatData['lastMessage'];
                lastMsgText = lm['text'] ?? '';
                if (lastMsgText.isEmpty) {
                     if (lm['type'] == 'image') lastMsgText = '📷 Photo';
                     if (lm['type'] == 'voice') lastMsgText = '🎙️ Voice message';
                }
            } else if (chatData['lastMessage'] is String) lastMsgText = chatData['lastMessage'];
            
            // Time
            String timeStr = '';
            if (chatData['lastMessageTime'] != null) {
                try { timeStr = DateFormat('h:mm a').format(DateTime.parse(chatData['lastMessageTime']).toLocal()); } catch (_) {}
            }

            // ... (Inside ListView.builder) ...
            
            return GestureDetector(
               onLongPress: PlatformHelper.isMobile 
                  ? () => _showChatMenu(context, chatId, chatData, isGroup, isFavorite, unreadCount > 0, isArchived)
                  : null,
               onSecondaryTapUp: (details) {
                   if (PlatformHelper.isWeb) {
                      _showChatMenu(context, chatId, chatData, isGroup, isFavorite, unreadCount > 0, isArchived, position: details.globalPosition);
                   }
               },
               child: ListTile(
                   // ... (Keep existing ListTile details: leading, title, subtitle, trailing, onTap)
                   leading: AvatarWidget(imageUrl: avatarUrl, radius: 25),
                   title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                   subtitle: Row(
                      children: [
                        if (isMuted) const Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.volume_off, size: 14, color: Colors.grey)),
                        Expanded(child: Text(lastMsgText, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                   ),
                   trailing: Column(
                     mainAxisAlignment: MainAxisAlignment.center,
                     crossAxisAlignment: CrossAxisAlignment.end,
                     children: [
                       Text(timeStr, style: TextStyle(fontSize: 12, color: unreadCount > 0 ? const Color(0xFF25D366) : Colors.grey)),
                       const SizedBox(height: 4),
                       Row(
                         mainAxisSize: MainAxisSize.min,
                         children: [
                           if (isFavorite) const Icon(Icons.star, size: 14, color: Colors.grey),
                           if (unreadCount > 0) ...[
                             const SizedBox(width: 4),
                             Container(
                               padding: const EdgeInsets.all(6),
                               decoration: const BoxDecoration(color: Color(0xFF25D366), shape: BoxShape.circle),
                               child: Text('$unreadCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                             )
                           ]
                         ],
                       )
                     ],
                   ),
                   onTap: () {
                      if (unreadCount > 0) _store.markRead(chatId);
                      final contact = Contact(name: name, profileImage: avatarUrl, isOnline: true);
                      final peerId = !isGroup ? participants.firstWhere((id) => id != currentUid, orElse: () => '') : '';
                      _navigateToChat(context, contact, peerId, chatId, isGroup: isGroup);
                   },
                 ),
            );
          },
        );
      }
    );
  }

  // Unified Menu Logic
  void _showChatMenu(BuildContext context, String chatId, Map<String, dynamic> chatData, bool isGroup, bool isFavorite, bool isUnread, bool isArchived, {Offset? position}) {
      final items = _buildMenuItems(isGroup, isFavorite, isUnread, isArchived, widget.filter);

      if (PlatformHelper.isMobile) {
          showModalBottomSheet(
            context: context,
            builder: (context) => Column(
              mainAxisSize: MainAxisSize.min,
              children: items.map((item) {
                 return ListTile(
                   leading: Icon(item['icon'] as IconData, color: item['isDestructive'] == true ? Colors.red : null),
                   title: Text(item['label'] as String, style: TextStyle(color: item['isDestructive'] == true ? Colors.red : null)),
                   onTap: () {
                      Navigator.pop(context);
                      _handleAction(chatId, item['value'] as String, chatData);
                   },
                 );
              }).toList(),
            ),
          );
      } else {
         // Desktop / Web Context Menu
         final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
         showMenu(
           context: context,
           position: RelativeRect.fromRect(
             (position ?? Offset.zero) & const Size(0, 0),
             Offset.zero & overlay.size,
           ),
           items: items.map((item) => PopupMenuItem(
             value: item['value'],
             child: Text(item['label'] as String, style: TextStyle(color: item['isDestructive'] == true ? Colors.red : null)),
           )).toList(),
         ).then((value) {
            if (value != null) _handleAction(chatId, value as String, chatData);
         });
      }
  }

  List<Map<String, dynamic>> _buildMenuItems(bool isGroup, bool isFavorite, bool isUnread, bool isArchived, String contextFilter) {
      final List<Map<String, dynamic>> items = [];

      // Context-Specific Rules
      // Unread Tab: Mark Read, Archive
      if (contextFilter == 'unread') {
         items.add({'label': 'Mark as read', 'value': 'mark_read', 'icon': Icons.mark_chat_read});
         items.add({'label': 'Archive chat', 'value': 'archive', 'icon': Icons.archive});
         return items;
      }
      
      // Archived Tab: Unarchive, Mark Unread/Read, Mute, Delete
      if (contextFilter == 'archived') {
         items.add({'label': 'Unarchive chat', 'value': 'unarchive', 'icon': Icons.unarchive});
         items.add(isUnread 
            ? {'label': 'Mark as read', 'value': 'mark_read', 'icon': Icons.mark_chat_read}
            : {'label': 'Mark as unread', 'value': 'mark_unread', 'icon': Icons.mark_chat_unread}
         );
         items.add({'label': 'Mute notifications', 'value': 'mute', 'icon': Icons.volume_off});
         items.add({'label': 'Delete chat', 'value': 'delete', 'icon': Icons.delete, 'isDestructive': true});
         return items;
      }

      // Favourites Tab: Remove Fav, Mute, Archive
      if (contextFilter == 'favorites') {
         items.add({'label': 'Remove from favourites', 'value': 'favorite', 'icon': Icons.star_border});
         items.add({'label': 'Mute notifications', 'value': 'mute', 'icon': Icons.volume_off});
         items.add({'label': 'Archive chat', 'value': 'archive', 'icon': Icons.archive});
         return items;
      }

      // Default (All Chats)
      // Normal Group/Chat logic
      items.add(isUnread 
            ? {'label': 'Mark as read', 'value': 'mark_read', 'icon': Icons.mark_chat_read}
            : {'label': 'Mark as unread', 'value': 'mark_unread', 'icon': Icons.mark_chat_unread}
      );
      
      items.add(isFavorite 
          ? {'label': 'Remove from favourites', 'value': 'favorite', 'icon': Icons.star_border}
          : {'label': 'Add to favourites', 'value': 'favorite', 'icon': Icons.star}
      );

      items.add(isArchived 
          ? {'label': 'Unarchive chat', 'value': 'unarchive', 'icon': Icons.unarchive}
          : {'label': 'Archive chat', 'value': 'archive', 'icon': Icons.archive}
      );

      items.add({'label': 'Mute notifications', 'value': 'mute', 'icon': Icons.volume_off});

      if (isGroup) {
         items.add({'label': 'Exit group', 'value': 'exit_group', 'icon': Icons.exit_to_app, 'isDestructive': true});
      } else {
         items.add({'label': 'Delete chat', 'value': 'delete', 'icon': Icons.delete, 'isDestructive': true});
      }

      return items;
  }

  void _navigateToChat(BuildContext context, Contact contact, String peerId, String chatId, {bool isGroup = false}) {
    if (widget.isWeb && widget.onChatSelected != null) {
      widget.onChatSelected!(contact, peerId, chatId);
    } else {
       Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(contact: contact, peerId: peerId, chatId: chatId, isGroup: isGroup)));
    }
  }
}
