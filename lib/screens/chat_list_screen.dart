import 'dart:async';
import 'package:flutter/material.dart';
import 'package:whatsapp_clone/services/auth_service.dart';
import 'package:whatsapp_clone/services/socket_service.dart';
import 'package:whatsapp_clone/models/contact.dart';
import 'package:whatsapp_clone/services/contact_service.dart'; // Import ContactService
import 'package:whatsapp_clone/screens/chat_screen.dart' hide SizedBox;
import 'package:whatsapp_clone/screens/new_chat_screen.dart';
import 'package:whatsapp_clone/screens/group_participant_select_screen.dart';
import 'package:whatsapp_clone/screens/settings/settings_screen.dart';
import 'package:whatsapp_clone/services/chat_service.dart';
import 'package:whatsapp_clone/widgets/avatar_widget.dart';
import 'package:intl/intl.dart';
import 'package:whatsapp_clone/utils/chat_session_store.dart';
import 'package:whatsapp_clone/utils/platform_helper.dart';

import 'package:whatsapp_clone/services/search_service.dart';
import 'package:whatsapp_clone/widgets/global_search_overlay.dart';
import 'package:whatsapp_clone/screens/camera/universal_camera_screen.dart';
import 'package:whatsapp_clone/screens/status/status_tab.dart';
import 'package:whatsapp_clone/screens/status/camera_status_screen.dart';
import 'package:whatsapp_clone/screens/status/text_status_screen.dart';
import 'package:whatsapp_clone/screens/call/incoming_call_screen.dart';
import 'package:whatsapp_clone/screens/call/call_logs_screen.dart';
import 'package:whatsapp_clone/widgets/navigation_panel.dart';
import 'package:whatsapp_clone/screens/communities/my_communities_screen.dart';
import 'package:whatsapp_clone/screens/communities/create_community_screen.dart';

class MobileChatLayout extends StatefulWidget {
  final bool isWeb;
  final Function(Contact, String, String)? onChatSelected; // contact, peerId, chatId

  const MobileChatLayout({
    super.key,
    this.isWeb = false,
    this.onChatSelected,
  });

  @override
  State<MobileChatLayout> createState() => _MobileChatLayoutState();
}

class _MobileChatLayoutState extends State<MobileChatLayout> {
  // Navigation State
  int _selectedNavIndex = 0; // 0: Chats, 1: Updates, 2: Calls, 3: Communities, 4: Profile
  bool _isPanelOpen = false;
  
  // Search State
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final SearchService _searchService = SearchService();
  final ChatService _chatService = ChatService();
  
  Map<String, dynamic> _searchResults = {};
  bool _isLoadingSearch = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  String _chatFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_isSearching && _searchController.text.trim().isNotEmpty) {
        _performSearch(_searchController.text.trim());
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isLoadingSearch = true);
    try {
      final results = await _searchService.searchGlobal(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoadingSearch = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingSearch = false);
    }
  }

  void _startSearch() {
    setState(() {
      _isSearching = true;
      _searchResults = {};
    });
    _searchFocusNode.requestFocus();
  }

  void _closeSearch() {
    if (_isSearching) {
      setState(() {
        _isSearching = false;
        _searchController.clear();
        _searchResults = {};
      });
      _searchFocusNode.unfocus();
    }
  }

  Future<bool> _onWillPop() async {
    if (_isSearching) {
      _closeSearch();
      return false;
    }
    return true;
  }

  void _handleSearchResultTap(String type, Map<String, dynamic>? data) async {
    if (data == null) return;
    
    String? chatId;
    String name = 'Unknown';
    String image = '';
    String peerId = '';
    bool isGroup = false;

    if (type == 'contact') {
      // Find or Create Chat
      peerId = data['firebaseUid'];
      name = data['name'];
      image = data['avatar'] ?? '';
      try {
        chatId = await _chatService.createOrGetChat(peerId);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to open chat")));
        return;
      }
    } else if (type == 'chat') {
       chatId = data['_id'];
       isGroup = true;
       name = data['groupName'];
       image = data['groupPhoto'] ?? '';
    } else if (type == 'message') {
       chatId = data['_id']; // Wait, message search returns message object.
       // We need chat details. In my controller I populated chatId.
       final chatObj = data['chatId']; // This is populated
       if (chatObj is Map<String, dynamic>) {
           chatId = chatObj['_id'];
           isGroup = chatObj['isGroup'] == true;
           if (isGroup) {
               name = chatObj['groupName'];
           } else {
               // Resolve peer name? For now use Sender Name or generic.
               final sender = data['senderId'];
               name = (sender is Map) ? sender['name'] : 'Chat';
           }
       } else {
           // Fallback if not populated correctly
           chatId = data['chatId']; // string
       }
    }

    if (chatId != null) {
        // Navigate
        final contact = Contact(name: name, profileImage: image, isOnline: true);
        if (widget.isWeb && widget.onChatSelected != null) {
           widget.onChatSelected!(contact, peerId, chatId!);
        } else {
           Navigator.push(context, MaterialPageRoute(builder: (c) => ChatScreen(
              contact: contact, peerId: peerId, chatId: chatId!, isGroup: isGroup
           )));
        }
        // TODO: If message, pass highlight ID or scroll to it.
        // The user wants click message -> open chat and scroll to message.
        // We will pass `scrollToMessageId` to ChatScreen?
        // I need to update ChatScreen to accept `scrollToMessageId` or similar.
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Stack(
        children: [
          Scaffold(
            appBar: _isSearching ? _buildSearchBar() : _buildNormalAppBar(),
            body: Stack(
              children: [
                // Render screen based on selected navigation index
                _buildCurrentScreen(),
                
                if (_isSearching)
                  Positioned.fill(
                    child: GlobalSearchOverlay(
                      results: _searchResults, 
                      isLoading: _isLoadingSearch, 
                      onResultTap: _handleSearchResultTap
                    ),
                  ),
              ],
            ),
            floatingActionButton: _isSearching ? null : _buildFab(),
          ),
          
          // Navigation Panel
          NavigationPanel(
            isOpen: _isPanelOpen,
            onClose: () => setState(() => _isPanelOpen = false),
            selectedIndex: _selectedNavIndex,
            onNavigate: (index) {
              setState(() {
                _selectedNavIndex = index;
                _isPanelOpen = false;
              });
            },
            userName: AuthService().currentUser?['name'] ?? 'User',
            userPhone: AuthService().currentUser?['phone'] ?? '',
            userAvatar: AuthService().currentUser?['avatar'] ?? '',
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentScreen() {
    switch (_selectedNavIndex) {
      case 0: // Chats
        return Column(
          children: [
            // Sub-Navbar (Filters)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
              color: Colors.white,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('All', 'all'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Unread', 'unread'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Favourites', 'favorites'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Groups', 'groups'),
                  ],
                ),
              ),
            ),
            
            // Filtered List
            Expanded(
              child: ChatListScreen(
                filter: _chatFilter, 
                isWeb: widget.isWeb, 
                onChatSelected: widget.onChatSelected
              )
            ),
          ],
        );
      
      case 1: // Updates
        return const StatusTab();
      
      case 2: // Calls
        return const CallLogsScreen();

      case 3: // Communities
        return const MyCommunitiesScreen(); // Need import
      
      case 4: // Profile
        return const SettingsScreen();
      
      default:
        return const Center(child: Text('Unknown screen'));
    }
  }

  Widget? _buildFab() {
    final index = _selectedNavIndex;
    
    // Tab 0: Chats -> New Chat
    if (index == 0) {
      return FloatingActionButton(
        backgroundColor: const Color(0xFFC92136),
       child: Padding(
          padding: const EdgeInsets.all(12.0), 
          child: Image.asset(
            'assets/images/new_chat_icon.png', 
            color: Colors.white, // Ensure white tint
          ),
        ),
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const NewChatScreen()));
        },
      );
    }
    
    // Tab 1: Updates -> Camera
    if (index == 1) {
       return Column(
         mainAxisSize: MainAxisSize.min,
         children: [
            SizedBox(
              height: 40,
              width: 40,
              child: FloatingActionButton(
                heroTag: "btnTextStatus",
                backgroundColor: Colors.grey[200],
                elevation: 4,
                child: const Icon(Icons.edit, color: Colors.black87),
                onPressed: () {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => const TextStatusScreen()));
                },
              ),
            ),
            const SizedBox(height: 16),
            FloatingActionButton(
              heroTag: "btnCameraStatus",
              backgroundColor: const Color(0xFFC92136), 
              child: const Icon(Icons.camera_alt, color: Colors.white),
              onPressed: () {
                 Navigator.push(context, MaterialPageRoute(builder: (_) => const CameraStatusScreen()));
              },
            ),
         ],
       );
    }

    // Tab 2: Calls -> New Call
    if (index == 2) {
       return FloatingActionButton(
          backgroundColor: const Color(0xFFC92136),
          child: const Icon(Icons.add_call, color: Colors.white),
          onPressed: () {
             Navigator.push(context, MaterialPageRoute(builder: (context) => const NewChatScreen(isCallSelection: true)));
          },
       );
    }

    // Tab 3: Communities -> New Community (Optional, or rely on screen button)
    if (index == 3) {
       return FloatingActionButton(
         backgroundColor: const Color(0xFFC92136),
         child: const Icon(Icons.group_add, color: Colors.white),
         onPressed: () {
           Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateCommunityScreen())).then((_) {
              // Refresh logic if needed, but MyCommunitiesScreen handles its own data fetch on init/nav
           });
         },
       );
    }

    return null;
  }

  PreferredSizeWidget _buildNormalAppBar() {
    // Dynamic title based on selected screen
    String getTitle() {
      switch (_selectedNavIndex) {
        case 0: return 'Chats';
        case 1: return 'Updates';
        case 2: return 'Calls';
        case 3: return 'Communities';
        case 4: return 'Profile';
        default: return 'Messaging App';
      }
    }

    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.menu),
        onPressed: () => setState(() => _isPanelOpen = true),
      ),
      title: Text(getTitle(), style: const TextStyle(fontWeight: FontWeight.bold)),
      actions: [
        IconButton(
          icon: const Icon(Icons.camera_alt_outlined), 
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UniversalCameraScreen()))
        ),
        IconButton(icon: const Icon(Icons.search), onPressed: _startSearch),
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'Settings') {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
            } else if (value == 'New group') {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const GroupParticipantSelectScreen()));
            } else if (value == 'New community') {
               Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateCommunityScreen()));
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
            const PopupMenuItem(value: 'Settings', child: Text('Settings')),
          ],
        ),
      ],

    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _chatFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _chatFilter = isSelected ? 'all' : value; // Toggle off to 'all' if tapped again? Or just select.
          // WhatsApp behavior: selecting "Unread" filters. Selecting "All" resets.
          // If I tap "Unread" again, does it deselect? Yes usually.
          if (isSelected && value != 'all') _chatFilter = 'all';
          else _chatFilter = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFC92136).withOpacity(0.1) : Colors.grey[200], // Red tint if selected, Grey if not
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isSelected ? const Color(0xFFC92136) : Colors.transparent),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFFC92136) : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildSearchBar() {
    return AppBar(
      backgroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.grey),
        onPressed: _closeSearch,
      ),
      title: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        decoration: const InputDecoration(
          hintText: 'Search...',
          border: InputBorder.none,
          hintStyle: TextStyle(color: Colors.grey),
        ),
        style: const TextStyle(color: Colors.black),
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

  StreamSubscription? _socketSub;

  @override
  void initState() {
    super.initState();
    _loadChats();
    
    // Listen for global refreshes (e.g., from Archive screen)
    _store.refreshTrigger.addListener(() {
       if (mounted) _loadChats(updateLoading: false);
    });
    
    // Real-time updates via Socket
    _socketSub = SocketService().messageStream.listen((data) {
        // When a new message arrives, we can either re-fetch all chats 
        // OR manually move the chat to top. 
        // For accurate sorting and "lastMessage" details, re-fetching is safest unless we optimize.
        // Optimization: Update local list.
        _handleNewMessageSocket(data);
    });
    
    // --- INCOMING CALL LISTENER ---
    SocketService().callStream.listen((data) {
       if (data['event'] == 'incoming-call') {
          final callData = data['data']; // { from, callType, offer }
          print("Incoming Call Received: $callData");
          
          if (!mounted) return;
          
          // Fetch Caller Info? 
          // Ideally we fetch caller name/avatar OR pass it in the payload.
          // For now, use "Unknown" or fetch if we have a contact cache.
          // Since we don't have caller details in payload, we must assume callerId is usable.
          final callerId = callData['from'];
          
          // Navigate to Incoming Call Screen
          Navigator.push(
            context, 
            MaterialPageRoute(
              builder: (_) => IncomingCallScreen(
                 callerName: "User $callerId", // TODO: Fetch Name
                 callerAvatar: "", // TODO: Fetch Avatar
                 callType: callData['callType'],
                 callData: callData,
              )
            )
          );
       }
    });

    // --- CONNECTION STATUS LISTENER (Sync on Resume) ---
    SocketService().connectionStateStream.listen((isConnected) {
        if (isConnected && mounted) {
            print("ChatListScreen: Socket reconnected. Refreshing chats...");
            _loadChats(updateLoading: false);
        }
    });
  }

  void _handleNewMessageSocket(Map<String, dynamic> messageData) {
      // Find chat
      final chatId = messageData['chatId'];
      final existingIndex = _chats.indexWhere((c) => (c['_id'] ?? c['id']) == chatId);
      
      if (existingIndex != -1) {
          if (mounted) {
             setState(() {
                var chat = _chats.removeAt(existingIndex);
                chat['lastMessage'] = messageData; // Update content
                chat['lastMessageTime'] = messageData['createdAt'] ?? DateTime.now().toIso8601String();
                
                // Increment Unread Count (Socket doesn't send full chat, so we do it locally)
                // Only if WE are not the sender
                if (messageData['senderId'] != AuthService().currentUserId) {
                   int current = (chat['unreadCount'] as num?)?.toInt() ?? 0;
                   chat['unreadCount'] = current + 1;
                }
                
                _chats.insert(0, chat); // Move to top
             });
          }
      } else {
          // New chat? Re-fetch to be safe
          _loadChats(updateLoading: false);
      }
  }

  @override
  void dispose() {
    _socketSub?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadChats({bool updateLoading = true}) async {
    try {
      if (updateLoading && mounted) setState(() => _isLoading = true);
      
      final chats = await _chatService.getMyChats();
      // User requested NOT to hide blocked chats, so we display all.
      
      if (mounted) {
        setState(() {
          _chats = chats;
          _isLoading = false;
        });
        
        // RELEASE DEBUG: Show Success Count
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Debug: Loaded ${chats.length} chats'), duration: const Duration(seconds: 2)),
        );
      }
    } catch (e, stack) {
      print("Error loading chats: $e");
      if (mounted && updateLoading) setState(() => _isLoading = false);
      
      // RELEASE DEBUG: Show Error
      if (mounted) {
         showDialog(
           context: context,
           builder: (context) => AlertDialog(
             title: const Text("Chat Load Error"),
             content: SingleChildScrollView(child: Text("Error: $e\n\nStack: $stack")),
             actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))
             ],
           )
         );
      }
    }
  }

  void _handleAction(String chatId, String action, Map<String, dynamic> chatData) async {
    switch (action) {
      case 'archive':
        // Optimistic Update
        setState(() {
           final index = _chats.indexWhere((c) => (c['_id'] ?? c['id']) == chatId);
           if (index != -1) {
              _chats[index]['isArchivedSelf'] = true;
           }
        });
        await _chatService.toggleArchive(chatId);
        _store.triggerRefresh(); // Notify other screens (e.g. Main list)
        _loadChats(updateLoading: false); // Background refresh self
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Chat archived")));
        break;
      case 'unarchive':
         // Optimistic Update
         setState(() {
           final index = _chats.indexWhere((c) => (c['_id'] ?? c['id']) == chatId);
           if (index != -1) {
              _chats[index]['isArchivedSelf'] = false;
           }
        });
         await _chatService.toggleArchive(chatId);
         _store.triggerRefresh(); // Notify other screens
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: AnimatedBuilder(
      animation: Listenable.merge([
        _store.archivedChatIds,
        _store.mutedChatIds,
        _store.markedUnreadChatIds,
        _store.deletedChatIds
      ]),
      builder: (context, child) {
        
        final currentUid = AuthService().currentUserId;
        
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
           
           var unreadCount = (chatData['unreadCount'] as num?)?.toInt() ?? 0;
           if (_store.isMarkedUnread(chatId)) unreadCount = 1; 
           // If manually marked "read" but backend says unread? 
           // We can track markRead in store too if needed, but for now markUnread is priority.
           
           if (widget.filter == 'unread') {
             if (unreadCount == 0 && !_store.isMarkedUnread(chatId)) return false;
           }

           if (widget.filter == 'favorites' && !isFavorite) return false;
           
           final isGroup = chatData['isGroup'] == true;
           
           if (widget.filter == 'groups' && !isGroup) return false;
           
           // For now, Communities are treated as Groups or empty (since no isCommunity flag logic yet)
           // If we want to strictly differentiate, we'd need a flag. 
           // For this UI task, we'll assume currently creating communities marks isGroup=true.
           // To avoid overlap, maybe communities implies isGroup=true AND valid groupName? 
           // Let's just create an empty set for communities for now to avoid confusion unless we have data.
           // User asked not to change backend. 
           if (widget.filter == 'communities') return false; // Placeholder

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
            
            final rawParticipants = chatData['participants'] as List<dynamic>? ?? [];
            final participantsDetails = rawParticipants.whereType<Map<String, dynamic>>().toList();
            
            final participants = rawParticipants.map((p) {
               if (p is Map) return (p['_id'] ?? '').toString();
               return p.toString();
            }).toList();
            
            final isFavorite = (chatData['isFavoriteSelf'] as bool?) ?? false;
            
            // ... (keep existing mute logic if matching lines, or I can just target the block above)
            
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
            
            // Unread Count (Backend + Local override check)
            var unreadCount = (chatData['unreadCount'] as num?)?.toInt() ?? 0;
            // Note: _store.isMarkedUnread is a manual override "Mark as unread". 
            // If backend says 0 but user marked unread, show 1.
            if (_store.isMarkedUnread(chatId)) unreadCount = unreadCount > 0 ? unreadCount : 1;
            
            // Determine Archive State for Menu
            final isArchived = widget.filter == 'archived' || (chatData['isArchivedSelf'] as bool? ?? false); 

            final isGroup = chatData['isGroup'] == true;
            
            // Name/Avatar Logic
            String name = '', avatarUrl = '';
            if (isGroup) {
                 name = chatData['groupName'] ?? 'Group';
                 avatarUrl = chatData['groupAvatar'] ?? chatData['groupPhoto'] ?? '';
            } else {
                 final peerId = participants.firstWhere((id) => id != currentUid, orElse: () => 'Unknown');
                 // Match by _id or firebaseUid
                 final peerData = participantsDetails.firstWhere(
                    (u) => (u['_id'] == peerId || u['firebaseUid'] == peerId), 
                    orElse: () => {}
                 );
                 avatarUrl = peerData['avatar'] ?? '';
            }

            // Prepare Future for Name Resolution
            Future<String> resolveName() async {
                if (isGroup) return chatData['groupName'] ?? 'Group';
                final peerId = participants.firstWhere((id) => id != currentUid, orElse: () => 'Unknown');
                 final peerData = participantsDetails.firstWhere(
                    (u) => (u['_id'] == peerId || u['firebaseUid'] == peerId), 
                    orElse: () => {}
                 );
                 final phone = peerData['phone'] ?? '';
                 // If we have local name cache in peerData? 
                 // Actually peerData has 'name' from backend populate. 
                 // But user wants "Contacts" name.
                 if (phone.isEmpty) return peerData['name'] ?? 'Unknown';
                 
                 // Use ContactService strict resolver
                 return await ContactService().getContactNameFromPhone(phone);
            }

            // Last Message Formatting
            String lastMsgText = '';
            if (chatData['lastMessage'] is Map) {
                final lm = chatData['lastMessage'];
                final content = lm['content'] ?? '';
                final type = lm['type'] ?? 'text';
                
                String preview = content;
                if (type == 'image') preview = '📷 Photo';
                if (type == 'video') preview = '🎥 Video';
                if (type == 'audio' || type == 'voice') preview = '🎙️ Voice message';
                if (type == 'file' || type == 'document') {
                  final filename = lm['filename'] ?? 'Document';
                  preview = '📄 $filename';
                }
                
                // Add Sender Name Prefix
                String senderPrefix = '';
                final senderId = lm['senderId'];
                if (senderId == currentUid) {
                    senderPrefix = 'You: ';
                } else if (isGroup) {
                    // Try to finding sender name in participants
                    // This is rough because we only have 'name' and 'phone' in participantsDetails
                    // We can try to resolve it? Or just use First Name.
                    // For now, let's keep it simple or user might complain "Who sent this?"
                    // Let's rely on standard UI (Name: Message)
                    // We need to resolve senderId to Name.
                    final senderData = participantsDetails.firstWhere(
                        (u) => (u['_id'] == senderId || u['firebaseUid'] == senderId),
                        orElse: () => {}
                    );
                    if (senderData.isNotEmpty) {
                       senderPrefix = "${senderData['name']?.split(' ').first ?? 'User'}: ";
                    } else {
                       senderPrefix = "User: ";
                    }
                }
                
                lastMsgText = "$senderPrefix$preview";

            } else if (chatData['lastMessage'] is String) {
                lastMsgText = chatData['lastMessage'];
            }
            
            // Time
            String timeStr = '';
            if (chatData['lastMessageTime'] != null) {
                try { 
                    final date = DateTime.parse(chatData['lastMessageTime']).toLocal();
                    final now = DateTime.now();
                    if (date.year == now.year && date.month == now.month && date.day == now.day) {
                        timeStr = DateFormat('h:mm a').format(date);
                    } else if (now.difference(date).inDays < 2) {
                        timeStr = 'Yesterday';
                    } else {
                        timeStr = DateFormat('dd/MM/yy').format(date);
                    }
                } catch (_) {}
            }

            return FutureBuilder<String>(
               future: resolveName(),
               builder: (context, snapshot) {
                  final displayName = snapshot.data ?? (isGroup ? (chatData['groupName'] ?? 'Group') : 'Loading...');
                  // If avatar is empty, use display name to generate
                  final finalAvatarUrl = (avatarUrl.isNotEmpty) ? avatarUrl : 'https://ui-avatars.com/api/?name=$displayName';

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
                       leading: AvatarWidget(imageUrl: finalAvatarUrl, radius: 25),
                       title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                       subtitle: Row(
                          children: [
                            if (isMuted) const Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.volume_off, size: 14, color: Colors.grey)),
                            Expanded(
                                child: Text(
                                    lastMsgText, 
                                    maxLines: 1, 
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: unreadCount > 0 ? Colors.black87 : Colors.grey,
                                        fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal
                                    )
                                )
                            ),
                          ],
                       ),
                       trailing: Column(
                         mainAxisAlignment: MainAxisAlignment.center,
                         crossAxisAlignment: CrossAxisAlignment.end,
                         children: [
                           Text(timeStr, style: TextStyle(
                               fontSize: 12, 
                               color: unreadCount > 0 ? const Color(0xFF25D366) : Colors.grey,
                               fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal
                           )),
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
                          // Mark read locally optimistic
                          if (unreadCount > 0 && mounted) {
                              setState(() {
                                  chatData['unreadCount'] = 0;
                                  _store.markRead(chatId);
                              });
                          }
                          
                          final contact = Contact(name: displayName, profileImage: finalAvatarUrl, isOnline: true);
                          final peerId = !isGroup ? participants.firstWhere((id) => id != currentUid, orElse: () => '') : '';
                          _navigateToChat(context, contact, peerId, chatId, isGroup: isGroup);
                       },
                     ),
                );
               },
            );
          },
        );
      }
    ),
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
