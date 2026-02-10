import 'package:flutter/material.dart';
import 'package:whatsapp_clone/models/community_model.dart';
import 'package:whatsapp_clone/models/group_model.dart';
import 'package:whatsapp_clone/services/community_service.dart';
import 'package:whatsapp_clone/screens/chat_screen.dart'; // To open group chat
import 'package:whatsapp_clone/models/project_models.dart'; // for Chat model mapping if needed
import 'package:whatsapp_clone/config/api_config.dart';
import 'package:whatsapp_clone/widgets/common/skeletons.dart';

class CommunityHomeScreen extends StatefulWidget {
  final String communityId;

  const CommunityHomeScreen({super.key, required this.communityId});

  @override
  State<CommunityHomeScreen> createState() => _CommunityHomeScreenState();
}

class _CommunityHomeScreenState extends State<CommunityHomeScreen> {
  CommunityModel? _community;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    final service = CommunityService();
    final data = await service.getCommunityDetails(widget.communityId);
    if (mounted) {
      setState(() {
        _community = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: ChatListSkeleton());
    if (_community == null) return const Scaffold(body: Center(child: Text("Community not found")));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildHeader(),
          SliverToBoxAdapter(
             child: Padding(
               padding: const EdgeInsets.all(16.0),
               child: Text("Groups in this Community", 
                 style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
               ),
             ),
          ),
          _buildGroupsList(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(_community!.name),
        background: _community!.photo.isNotEmpty 
            ? Image.network(ApiConfig.getFullImageUrl(_community!.photo), fit: BoxFit.cover)
            : Container(color: Colors.blueGrey, child: const Icon(Icons.groups, size: 80, color: Colors.white)),
      ),
      actions: [
         IconButton(icon: const Icon(Icons.more_vert), onPressed: () {
           // Open settings
           // Navigator.push...
         }),
      ],
    );
  }

  Widget _buildGroupsList() {
    final groups = _community!.groups ?? [];

    // Prioritize Announcement Group?
    // It's in the list, probably.
    // If not, we might need separate section.
    // Assuming backend returns it in 'groups' or we fetch it separately. 
    // Backend 'getCommunityDetails' populates 'groups' array.
    // Does 'groups' array include announcementsGroupId?
    // In strict sense, announcementsGroupId is separate field, but usually also in groups list?
    // My backend logic: "groups: groupIds". Announcement group ID was stored in announcementsGroupId. 
    // It wasn't pushed to 'groups' array in createCommunity.
    // Verify backend logic: 
    // Community.create has: groups: groupIds, announcementsGroupId: ...
    // So it is NOT in groups array by default.
    // I should display it separately at top (like WhatsApp).
    
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          // Add Announcement Group as first item logic
          if (index == 0) {
            return _buildAnnouncementTile();
          }
          final group = groups[index - 1];
          return _buildGroupTile(group);
        },
        childCount: groups.length + 1, // +1 for Announcement
      ),
    );
  }

  Widget _buildAnnouncementTile() {
    return ListTile(
      leading: Container(
         decoration: BoxDecoration(color: Colors.blue[100], borderRadius: BorderRadius.circular(8)),
         padding: const EdgeInsets.all(8),
         child: const Icon(Icons.campaign, color: Colors.blue),
      ),
      title: const Text("Announcements"),
      subtitle: const Text("Only admins can post"),
      onTap: () {
         // Open Announcement Chat
         _openChat(_community!.announcementsGroupId, "Announcements", true, photo: '');
      },
    );
  }

  Widget _buildGroupTile(GroupModel group) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: (group.avatar.isNotEmpty) ? NetworkImage(ApiConfig.getFullImageUrl(group.avatar)) : null,
        child: group.avatar.isEmpty ? const Icon(Icons.group) : null,
      ),
      title: Text(group.name),
      subtitle: Text(group.description.isNotEmpty ? group.description : "No description"),
       onTap: () {
         _openChat(group.id, group.name, true, photo: group.avatar);
      },
    );
  }

  void _openChat(String chatId, String name, bool isGroup, {String photo = ''}) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
              chatId: chatId,
              peerId: isGroup ? chatId : '', // Required param, safe to pass chatId for group
              groupName: name,
              groupPhoto: ApiConfig.getFullImageUrl(photo), // Fetch dynamically in chat screen or pass
              isGroup: isGroup,
          ),
        ),
      );
  }
}
