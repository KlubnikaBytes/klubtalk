import 'package:flutter/material.dart';
import 'package:whatsapp_clone/models/contact_model.dart';
import 'package:whatsapp_clone/mock_data/contacts.dart';
import 'package:whatsapp_clone/widgets/contact_list_tile.dart';
import 'package:whatsapp_clone/widgets/selected_contact_avatar.dart';
import 'package:whatsapp_clone/theme/app_theme.dart';

class GroupCreateScreen extends StatefulWidget {
  const GroupCreateScreen({super.key});

  @override
  State<GroupCreateScreen> createState() => _GroupCreateScreenState();
}

class _GroupCreateScreenState extends State<GroupCreateScreen> {
  // Store selected IDs to manage state locally without mutating mock data
  final Set<String> _selectedIds = {};
  
  // Get all contacts from mock
  final List<ContactModel> _contacts = MockContacts.contacts;

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // List of selected contact objects
    final selectedContacts = _contacts
        .where((c) => _selectedIds.contains(c.id))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('New group', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('Add participants', style: TextStyle(fontSize: 13, fontWeight: FontWeight.normal)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Selected Contacts Preview Area
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _selectedIds.isNotEmpty ? 90 : 0,
            color: Theme.of(context).scaffoldBackgroundColor,
            child: _selectedIds.isNotEmpty
                ? ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    scrollDirection: Axis.horizontal,
                    itemCount: selectedContacts.length,
                    itemBuilder: (context, index) {
                      final contact = selectedContacts[index];
                      // Use a Key to ensuring proper animations if we were using AnimatedList
                      return SelectedContactAvatar(
                        key: ValueKey(contact.id),
                        contact: contact,
                        onRemove: () => _toggleSelection(contact.id),
                      );
                    },
                  )
                : const SizedBox(),
          ),
          if (_selectedIds.isNotEmpty)
             const Divider(height: 1),

          // Main Contact List
          Expanded(
            child: ListView.builder(
              itemCount: _contacts.length,
              itemBuilder: (context, index) {
                final contact = _contacts[index];
                final isSelected = _selectedIds.contains(contact.id);
                return ContactListTile(
                  contact: contact,
                  isSelected: isSelected,
                  onTap: () => _toggleSelection(contact.id),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedIds.isNotEmpty
          ? FloatingActionButton(
              onPressed: () {
                // Navigate to next screen (Group Name) - mock action
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Next: Group Subject')),
                );
              },
              backgroundColor: AppTheme.accentGreen, // WhatsApp Brand Color
              child: const Icon(Icons.arrow_forward, color: Colors.white),
            )
          : null,
    );
  }
}
