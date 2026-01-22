
import 'package:flutter/material.dart';
import 'package:whatsapp_clone/services/auth_service.dart';
import 'package:whatsapp_clone/models/user_model.dart';
import 'package:whatsapp_clone/services/contact_service.dart';
import 'package:whatsapp_clone/widgets/avatar_widget.dart';

class ContactPickerScreen extends StatefulWidget {
  final String title;
  final List<String> initialSelectedIds;
  
  const ContactPickerScreen({
    super.key, 
    required this.title,
    required this.initialSelectedIds
  });

  @override
  State<ContactPickerScreen> createState() => _ContactPickerScreenState();
}

class _ContactPickerScreenState extends State<ContactPickerScreen> {
  final ContactService _contactService = ContactService();
  List<UserModel> _contacts = [];
  bool _isLoading = true;
  late Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.initialSelectedIds.toSet();
    _fetchContacts();
  }

  Future<void> _fetchContacts() async {
    try {
      final currentUid = AuthService().currentUserId;
      final users = await _contactService.getRegisteredUsers();
      final items = users.where((u) => u.uid != currentUid).toList();
      
      if (mounted) {
        setState(() {
          _contacts = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleSelection(String uid) {
    setState(() {
      if (_selectedIds.contains(uid)) {
        _selectedIds.remove(uid);
      } else {
        _selectedIds.add(uid);
      }
    });
  }

  void _submit() {
    Navigator.pop(context, _selectedIds.toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('${_selectedIds.length} selected', style: const TextStyle(fontSize: 12)),
          ],
        ),
        backgroundColor: const Color(0xFFC92136),
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator()) 
          : Column(
              children: [
                 if (_selectedIds.isNotEmpty)
                  SizedBox(
                    height: 70,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      children: _selectedIds.map((id) {
                        final contact = _contacts.firstWhere(
                           (c) => c.uid == id, 
                           orElse: () => UserModel(uid: id, phoneNumber: '', name: 'Unknown', isOnline: false, lastSeen: null, profilePhotoUrl: '', about: '')
                        );
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Column(
                            children: [
                              Stack(
                                children: [
                                  AvatarWidget(imageUrl: contact.profilePhotoUrl, radius: 15),
                                  Positioned(
                                     bottom: 0, right: 0,
                                     child: GestureDetector(
                                       onTap: () => _toggleSelection(id),
                                       child: const CircleAvatar(radius: 6, backgroundColor: Colors.grey, child: Icon(Icons.close, size: 8, color: Colors.white))
                                     )
                                  )
                                ], 
                              ),
                              const SizedBox(height: 2),
                              Text(contact.name.split(' ')[0], style: const TextStyle(fontSize: 10)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _contacts.length,
                    itemBuilder: (context, index) {
                      final contact = _contacts[index];
                      final isSelected = _selectedIds.contains(contact.uid);
                      
                      return ListTile(
                        leading: Stack(
                          children: [
                            AvatarWidget(imageUrl: contact.profilePhotoUrl, radius: 22),
                            if (isSelected)
                              const Positioned(
                                bottom: 0, right: 0,
                                child: CircleAvatar(
                                  radius: 10,
                                  backgroundColor: Color(0xFFC92136),
                                  child: Icon(Icons.check, size: 12, color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                        title: Text(contact.name.isEmpty ? contact.phoneNumber : contact.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(contact.about, maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () => _toggleSelection(contact.uid),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFC92136),
        onPressed: _submit,
        child: const Icon(Icons.check, color: Colors.white),
      ),
    );
  }
}
