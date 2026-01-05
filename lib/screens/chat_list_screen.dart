import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:whatsapp_clone/models/contact.dart';
import 'package:whatsapp_clone/screens/chat_screen.dart';
import 'package:whatsapp_clone/screens/new_chat_screen.dart';
import 'package:whatsapp_clone/screens/group_participant_select_screen.dart';
import 'package:whatsapp_clone/screens/settings/settings_screen.dart';
import 'package:whatsapp_clone/services/chat_service.dart';
import 'package:whatsapp_clone/widgets/avatar_widget.dart';
import 'package:intl/intl.dart';

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

class ChatListScreen extends StatelessWidget {
  final bool isWeb;
  final String filter;
  final Function(Contact, String, String)? onChatSelected;

  const ChatListScreen({
    super.key, 
    this.isWeb = false,
    this.filter = 'all',
    this.onChatSelected,
  });

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    
    // Stream of Metadata
    Stream<QuerySnapshot> metaStream = FirebaseFirestore.instance 
      .collection('users')
      .doc(currentUid)
      .collection('chatMeta')
      .snapshots();

    // Base Query (Still fetch all relevant chats)
    Query chatsQuery = FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: currentUid)
            .orderBy('lastMessageTime', descending: true);
            
    void _showContextMenu(BuildContext context, Offset? position, String chatId, Map<String, dynamic>? meta) {
      final isFavorite = meta?['isFavorite'] == true;
      final unreadCount = meta?['unreadCount'] ?? 0;
      final isArchived = meta?['isArchived'] == true;

      final items = [
          PopupMenuItem(
            value: 'unread',
            child: Text(unreadCount > 0 ? 'Mark as read' : 'Mark as unread'),
          ),
          PopupMenuItem(
            value: 'favorite',
            child: Text(isFavorite ? 'Remove from favorites' : 'Add to favorites'),
          ),
          PopupMenuItem(
            value: 'archive',
            child: Text(isArchived ? 'Unarchive' : 'Archive'),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: Text('Delete'),
          ),
      ];

      // Helper to handle selection
      void onSelected(String value) {
         final chatService = ChatService(); // Assuming we can instantiate or get standard instance
         if (value == 'unread') {
           if (unreadCount > 0) {
             chatService.markChatAsRead(chatId);
           } else {
             chatService.markChatAsUnread(chatId);
           }
         } else if (value == 'favorite') {
           chatService.toggleFavorite(chatId, !isFavorite);
         } else if (value == 'archive') {
           // Stub for archive
         } else if (value == 'delete') {
           // Stub for delete
         }
      }

      if (position != null) {
        // Desktop / Web Right Click -> Dropdown Menu at cursor
        showMenu<String>(
          context: context,
          position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx + 1, position.dy + 1),
          items: items,
        ).then((value) {
          if (value != null) onSelected(value);
        });
      } else {
        // Mobile Long Press -> Bottom Sheet
        showModalBottomSheet(
          context: context,
          builder: (context) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: items.map((item) {
                return ListTile(
                  title: item.child,
                  onTap: () {
                    Navigator.pop(context);
                    onSelected(item.value as String);
                  },
                );
              }).toList(),
            );
          }
        );
      }
    }

    return StreamBuilder<QuerySnapshot>(
        stream: metaStream,
        builder: (context, metaSnapshot) {
          if (metaSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          Map<String, Map<String, dynamic>> metaMap = {};
          for (var doc in metaSnapshot.data?.docs ?? []) {
             metaMap[doc.id] = doc.data() as Map<String, dynamic>;
          }

          return StreamBuilder<QuerySnapshot>(
            stream: chatsQuery.snapshots(),
            builder: (context, chatSnapshot) {
               if (chatSnapshot.connectionState == ConnectionState.waiting) return const SizedBox.shrink();
               
               final allDocs = chatSnapshot.data?.docs ?? [];
               
               final docs = allDocs.where((doc) {
                 final chatId = doc.id;
                 final meta = metaMap[chatId];
                 final isUnread = (meta?['unreadCount'] ?? 0) > 0;
                 final isFavorite = meta?['isFavorite'] == true;

                 if (filter == 'unread' && !isUnread) return false;
                 if (filter == 'favorites' && !isFavorite) return false;
                 
                 return true;
               }).toList();

               if (docs.isEmpty) {
                 return Center(
                   child: Text(
                     filter == 'all' ? 'No chats yet' : 'No $filter chats', 
                     style: const TextStyle(color: Colors.grey)
                 ));
               }

               return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final chatData = docs[index].data() as Map<String, dynamic>;
              final chatId = docs[index].id;
              final participants = List<String>.from(chatData['participants'] ?? []);
              
              final meta = metaMap[chatId];
              final unreadCount = meta?['unreadCount'] ?? 0;
              final isFavorite = meta?['isFavorite'] == true;

              final isGroup = chatData['isGroup'] == true;
              
              Widget trailingWidget(String time) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(time, style: TextStyle(fontSize: 12, color: unreadCount > 0 ? const Color(0xFF25D366) : Colors.grey)),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isFavorite) const Icon(Icons.star, size: 14, color: Colors.grey),
                        if (unreadCount > 0) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFF25D366),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$unreadCount',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ]
                      ],
                    ),
                  ],
                );
              }

              if (isGroup) {
                 final groupName = chatData['groupName'] ?? 'Unknown Group';
                 final lastMsg = chatData['lastMessage'] ?? '';
                 String time = '';
                 if (chatData['lastMessageTime'] != null) {
                    Timestamp t = chatData['lastMessageTime'];
                    time = DateFormat('h:mm a').format(t.toDate());
                 }

                 return Listener(
                   onPointerDown: (event) {
                     if (event.kind == PointerDeviceKind.mouse && event.buttons == kSecondaryMouseButton) {
                       _showContextMenu(context, event.position, chatId, meta);
                     }
                   },
                   child: ListTile(
                      leading: const CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.grey,
                        child: Icon(Icons.groups, color: Colors.white),
                      ),
                      title: Text(groupName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(lastMsg, maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: trailingWidget(time),
                      onTap: () {
                        final contact = Contact(
                          name: groupName,
                          profileImage: '',
                          isOnline: false,
                        );
                        _navigateToChat(context, contact, 'group', chatId, isGroup: true);
                      },
                      onLongPress: () => _showContextMenu(context, null, chatId, meta),
                   ),
                 );
              }

              final peerId = participants.firstWhere((id) => id != currentUid, orElse: () => 'Unknown');
              
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(peerId).get(),
                builder: (context, userSnap) {
                  if (!userSnap.hasData) return const SizedBox.shrink();
                  
                  final userData = userSnap.data!.data() as Map<String, dynamic>?;
                  final name = userData?['name'] ?? 'Unknown User';
                  final avatar = userData?['profilePhotoUrl'] ?? 'https://i.pravatar.cc/150?u=$peerId';
                  
                  final lastMsg = chatData['lastMessage'] ?? '';
                  String time = '';
                  if (chatData['lastMessageTime'] != null) {
                    Timestamp t = chatData['lastMessageTime'];
                    time = DateFormat('h:mm a').format(t.toDate());
                  }

                  return Listener(
                    onPointerDown: (event) {
                       if (event.kind == PointerDeviceKind.mouse && event.buttons == kSecondaryMouseButton) {
                         _showContextMenu(context, event.position, chatId, meta);
                       }
                    },
                    child: ListTile(
                      leading: AvatarWidget(imageUrl: avatar, radius: 25),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(lastMsg, maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: trailingWidget(time),
                      onTap: () {
                        final contact = Contact(
                          name: name,
                          profileImage: avatar,
                          isOnline: true,
                        );
                        _navigateToChat(context, contact, peerId, chatId);
                      },
                      onLongPress: () => _showContextMenu(context, null, chatId, meta),
                    ),
                  );
                },
              );
            },
          );
            },
          );
        },
      );
  }

  void _navigateToChat(BuildContext context, Contact contact, String peerId, String chatId, {bool isGroup = false}) {
    if (isWeb && onChatSelected != null) {
      onChatSelected!(contact, peerId, chatId);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            contact: contact,
            peerId: peerId,
            chatId: chatId,
            isGroup: isGroup,
          ),
        ),
      );
    }
  }
}
