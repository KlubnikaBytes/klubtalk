import 'package:flutter/material.dart';
import 'package:whatsapp_clone/mock_data/mock_repository.dart';
import 'package:whatsapp_clone/widgets/avatar_widget.dart';

class GroupCreationScreen extends StatefulWidget {
  const GroupCreationScreen({super.key});

  @override
  State<GroupCreationScreen> createState() => _GroupCreationScreenState();
}

class _GroupCreationScreenState extends State<GroupCreationScreen> {
  final Set<String> _selectedContactIds = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('New group', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(
              '${_selectedContactIds.length} selected',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_selectedContactIds.isNotEmpty)
            SizedBox(
              height: 90,
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                scrollDirection: Axis.horizontal,
                itemCount: _selectedContactIds.length,
                itemBuilder: (context, index) {
                   final id = _selectedContactIds.elementAt(index);
                   final contact = MockRepository.contacts.firstWhere((c) => c.id == id);
                   return Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 8.0),
                     child: Column(
                       children: [
                         Stack(
                           children: [
                             AvatarWidget(imageUrl: contact.avatarUrl),
                             Positioned(
                               bottom: 0,
                               right: 0,
                               child: GestureDetector(
                                 onTap: () {
                                   setState(() {
                                     _selectedContactIds.remove(id);
                                   });
                                 },
                                 child: const CircleAvatar(
                                   radius: 10,
                                   backgroundColor: Colors.grey,
                                   child: Icon(Icons.close, size: 12, color: Colors.white),
                                 ),
                               ),
                             )
                           ],
                         ),
                         const SizedBox(height: 4),
                         Text(
                           contact.name.split(' ')[0],
                           style: const TextStyle(fontSize: 12),
                         ),
                       ],
                     ),
                   );
                },
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: MockRepository.contacts.length,
              itemBuilder: (context, index) {
                final contact = MockRepository.contacts[index];
                final isSelected = _selectedContactIds.contains(contact.id);
                
                return ListTile(
                  leading: Stack(
                    children: [
                      AvatarWidget(imageUrl: contact.avatarUrl),
                      if (isSelected)
                        const Positioned(
                          bottom: 0,
                          right: 0,
                          child: CircleAvatar(
                            radius: 10,
                            backgroundColor: Color(0xFF25D366),
                            child: Icon(Icons.check, size: 12, color: Colors.white),
                          ),
                        )
                    ],
                  ),
                  title: Text(
                    contact.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(contact.about),
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedContactIds.remove(contact.id);
                      } else {
                        _selectedContactIds.add(contact.id);
                      }
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedContactIds.isNotEmpty
          ? FloatingActionButton(
              onPressed: () {
                // Next step: Group name
              },
              backgroundColor: const Color(0xFF25D366),
              child: const Icon(Icons.arrow_forward, color: Colors.white),
            )
          : null,
    );
  }
}
