import 'package:flutter/material.dart';

class GroupMediaScreen extends StatefulWidget {
  final String chatId;
  final String groupName;

  const GroupMediaScreen({super.key, required this.chatId, required this.groupName});

  @override
  State<GroupMediaScreen> createState() => _GroupMediaScreenState();
}

class _GroupMediaScreenState extends State<GroupMediaScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupName),
        backgroundColor: const Color(0xFF075E54),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: "Media"),
            Tab(text: "Docs"),
            Tab(text: "Links"),
            Tab(text: "Voice"), // Or Audio
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMediaTab(),
          _buildDocsTab(),
          _buildLinksTab(),
          _buildVoiceTab(),
        ],
      ),
    );
  }

  Widget _buildMediaTab() {
    // Placeholder grid
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: 12, // Dummy
      itemBuilder: (context, index) {
        return Container(
          color: Colors.grey[300],
          child: const Icon(Icons.image, color: Colors.white),
        );
      },
    );
  }

  Widget _buildDocsTab() => const Center(child: Text("No documents found"));
  Widget _buildLinksTab() => const Center(child: Text("No links found"));
  Widget _buildVoiceTab() => const Center(child: Text("No voice notes found"));
}
