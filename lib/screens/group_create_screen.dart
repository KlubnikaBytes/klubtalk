import 'package:flutter/material.dart';
import 'package:whatsapp_clone/models/contact_model.dart';
import 'package:whatsapp_clone/mock_data/contacts.dart';
import 'package:whatsapp_clone/widgets/contact_list_tile.dart';
import 'package:whatsapp_clone/widgets/selected_contact_avatar.dart';
import 'package:whatsapp_clone/theme/app_theme.dart';
import 'package:image_picker/image_picker.dart';
import 'package:whatsapp_clone/services/chat_service.dart';
import 'package:whatsapp_clone/services/media_upload_service.dart';

class GroupCreateScreen extends StatefulWidget {
  const GroupCreateScreen({super.key});

  @override
  State<GroupCreateScreen> createState() => _GroupCreateScreenState();
}

class _GroupCreateScreenState extends State<GroupCreateScreen> {
  // Store selected IDs
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
                _showGroupCreationDialog(context);
              },
              backgroundColor: AppTheme.accentGreen, // WhatsApp Brand Color
              child: const Icon(Icons.arrow_forward, color: Colors.white),
            )
          : null,
    );
  }

  void _showGroupCreationDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    String? _uploadedIconUrl;
    bool _isUploading = false;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('New Group'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () async {
                      if (_isUploading) return;
                      final picker = ImagePicker();
                      final image = await picker.pickImage(source: ImageSource.gallery);
                      if (image != null) {
                        setState(() => _isUploading = true);
                        try {
                           final service = MediaUploadService();
                           // Use mock/real service
                           final url = await service.uploadGroupIcon(image.path);
                           setState(() {
                             _uploadedIconUrl = url;
                             _isUploading = false;
                           });
                        } catch (e) {
                          setState(() => _isUploading = false);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
                        }
                      }
                    },
                    child: CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: _uploadedIconUrl != null ? NetworkImage(_uploadedIconUrl!) : null,
                      child: _isUploading 
                         ? const CircularProgressIndicator() 
                         : (_uploadedIconUrl == null ? const Icon(Icons.camera_alt, color: Colors.grey) : null),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      hintText: 'Group Subject',
                      border: UnderlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty) return;
                    
                    final chatService = ChatService();
                    await chatService.createGroupChat(
                      nameController.text.trim(), 
                      _selectedIds.toList(),
                      groupPhotoUrl: _uploadedIconUrl
                    );
                    
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Close selection screen
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          }
        );
      },
    );
  }
