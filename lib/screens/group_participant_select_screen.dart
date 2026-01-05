import 'package:flutter/material.dart';
import 'package:whatsapp_clone/screens/group_info_screen.dart';

class DummyContact {
  final String id;
  final String name;
  final String phone;

  DummyContact({required this.id, required this.name, required this.phone});
}

class GroupParticipantSelectScreen extends StatefulWidget {
  const GroupParticipantSelectScreen({super.key});

  @override
  State<GroupParticipantSelectScreen> createState() => _GroupParticipantSelectScreenState();
}

class _GroupParticipantSelectScreenState extends State<GroupParticipantSelectScreen> {
  final List<DummyContact> _dummyContacts = [
    DummyContact(id: '1', name: 'Amit Sharma', phone: '+91 98765 43210'),
    DummyContact(id: '2', name: 'Riya Sen', phone: '+91 87654 32109'),
    DummyContact(id: '3', name: 'Rahul Das', phone: '+91 76543 21098'),
    DummyContact(id: '4', name: 'Sneha Paul', phone: '+91 65432 10987'),
    DummyContact(id: '5', name: 'Kabir Roy', phone: '+91 54321 09876'),
  ];

  final Set<String> _selectedIds = {};

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _goToGroupInfo() {
    // Pass selected IDs to next screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupInfoScreen(
          selectedParticipantIds: _selectedIds.toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF9575CD), // Purple Theme
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('New Group', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('${_selectedIds.length} selected', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          // Selected Chips
          if (_selectedIds.isNotEmpty)
            SizedBox(
              height: 70,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                children: _selectedIds.map((id) {
                  final contact = _dummyContacts.firstWhere((c) => c.id == id);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Column(
                      children: [
                        const CircleAvatar(
                          radius: 15,
                          backgroundColor: Colors.grey,
                          child: Icon(Icons.person, size: 20, color: Colors.white),
                        ),
                        Text(contact.name.split(' ')[0], style: const TextStyle(fontSize: 10)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          
          Expanded(
            child: ListView.builder(
              itemCount: _dummyContacts.length,
              itemBuilder: (context, index) {
                final contact = _dummyContacts[index];
                final isSelected = _selectedIds.contains(contact.id);
                
                return ListTile(
                  leading: Stack(
                    children: [
                      const CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.grey,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      if (isSelected)
                        const Positioned(
                          bottom: 0,
                          right: 0,
                          child: CircleAvatar(
                            radius: 10,
                            backgroundColor: Color(0xFF9575CD),
                            child: Icon(Icons.check, size: 12, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                  title: Text(contact.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(contact.phone),
                  onTap: () => _toggleSelection(contact.id),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedIds.isNotEmpty
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF9575CD),
              onPressed: _goToGroupInfo,
              child: const Icon(Icons.arrow_forward, color: Colors.white),
            )
          : null,
    );
  }
}
