import 'package:flutter/material.dart';
import 'package:whatsapp_clone/models/project_models.dart';
import 'package:whatsapp_clone/widgets/avatar_widget.dart';

class ProfileScreen extends StatelessWidget {
  final User user;

  const ProfileScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(user.name),
              background: Hero(
                tag: user.id,
                child: Image.network(
                  user.avatarUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey,
                      child: const Center(
                        child: Icon(Icons.person, size: 80, color: Colors.white),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 10),
              _buildSection(
                context,
                title: 'Media, links, and docs',
                child: SizedBox(
                   height: 80,
                   child: ListView(
                     scrollDirection: Axis.horizontal,
                     children: List.generate(5, (index) => 
                       Container(
                         width: 80,
                         margin: const EdgeInsets.only(right: 8),
                         color: Colors.grey[300],
                         child: const Icon(Icons.image, color: Colors.grey),
                       )
                     ),
                   ),
                )
              ),
              const SizedBox(height: 10),
              _buildSection(
                context,
                title: 'About and phone number',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.about,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sept 15, 2024',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                    const Divider(),
                    Text(
                      user.phoneNumber,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Mobile',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
              ),
               const SizedBox(height: 10),
              _buildActionTile(context, Icons.notifications, 'Notifications'),
              _buildActionTile(context, Icons.lock, 'Encryption'),
              _buildActionTile(context, Icons.block, 'Block ${user.name}', color: Colors.red),
              _buildActionTile(context, Icons.thumb_down, 'Report ${user.name}', color: Colors.red),
              const SizedBox(height: 40),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, {required String title, required Widget child}) {
    return Container(
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildActionTile(BuildContext context, IconData icon, String text, {Color? color}) {
    return Container(
      color: Theme.of(context).cardColor,
      margin: const EdgeInsets.only(top: 10),
      child: ListTile(
        leading: Icon(icon, color: color ?? Colors.grey),
        title: Text(
           text,
           style: TextStyle(color: color ?? Theme.of(context).textTheme.bodyLarge?.color),
        ),
      ),
    );
  }
}
