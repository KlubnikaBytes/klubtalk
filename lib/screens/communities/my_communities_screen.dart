import 'package:flutter/material.dart';
import 'package:whatsapp_clone/models/community_model.dart';
import 'package:whatsapp_clone/services/community_service.dart';
import 'package:whatsapp_clone/screens/communities/community_home_screen.dart';
import 'package:whatsapp_clone/screens/communities/create_community_screen.dart';
import 'package:whatsapp_clone/config/api_config.dart';
import 'package:whatsapp_clone/widgets/responsive_container.dart';

class MyCommunitiesScreen extends StatefulWidget {
  const MyCommunitiesScreen({super.key});

  @override
  State<MyCommunitiesScreen> createState() => _MyCommunitiesScreenState();
}

class _MyCommunitiesScreenState extends State<MyCommunitiesScreen> {
  final CommunityService _communityService = CommunityService();
  List<CommunityModel> _communities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCommunities();
  }

  Future<void> _fetchCommunities() async {
    final list = await _communityService.getMyCommunities();
    if (mounted) {
      setState(() {
        _communities = list;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_communities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.groups, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text("No communities yet", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                 Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
                   backgroundColor: const Color(0xFFF0F2F5),
                   body: ResponsiveContainer(child: const CreateCommunityScreen())
                 ))).then((_) => _fetchCommunities());
              },
              child: const Text("Start your community"),
            )
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _communities.length + 1, // Header
      itemBuilder: (context, index) {
        if (index == 0) {
           return ListTile(
             leading: Container(
               decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(8)),
               padding: const EdgeInsets.all(8),
               child: const Icon(Icons.add),
             ),
             title: const Text("New Community"),
             onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
                   backgroundColor: const Color(0xFFF0F2F5),
                   body: ResponsiveContainer(child: const CreateCommunityScreen())
                ))).then((_) => _fetchCommunities());
             },
           );
        }
        final community = _communities[index - 1];
        return ListTile(
          leading: CircleAvatar(
             radius: 24,
             backgroundImage: community.photo.isNotEmpty ? NetworkImage(ApiConfig.getFullImageUrl(community.photo)) : null,
             child: community.photo.isEmpty ? const Icon(Icons.groups) : null,
          ),
          title: Text(community.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(community.description.isNotEmpty ? community.description : "No description"),
          onTap: () {
             Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
                backgroundColor: const Color(0xFFF0F2F5),
                body: ResponsiveContainer(child: CommunityHomeScreen(communityId: community.id))
             )));
          },
        );
      },
    );
  }
}
