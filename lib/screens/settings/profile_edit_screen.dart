import 'package:flutter/foundation.dart'; // Add this input
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:whatsapp_clone/models/user_model.dart';
import 'package:whatsapp_clone/services/user_service.dart';
import 'package:whatsapp_clone/widgets/avatar_widget.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final UserService _userService = UserService();
  bool _isUploading = false;

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (pickedFile != null) {
      setState(() => _isUploading = true);
      try {
        if (kIsWeb) {
          final bytes = await pickedFile.readAsBytes();
          await _userService.updateProfilePhoto(bytes);
        } else {
          await _userService.updateProfilePhoto(File(pickedFile.path));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  void _editName(BuildContext context, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter your name'),
        content: TextField(controller: controller, maxLength: 25),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                _userService.updateProfile(name: controller.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _editAbout(BuildContext context, String currentAbout) {
    final controller = TextEditingController(text: currentAbout);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 20, left: 20, right: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add About', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            TextField(controller: controller, maxLength: 140, maxLines: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                TextButton(
                  onPressed: () {
                    _userService.updateProfile(about: controller.text.trim());
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: StreamBuilder<UserModel>(
        stream: _userService.currentUserStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final user = snapshot.data!;

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),
                Center(
                  child: Stack(
                    children: [
                      Hero(
                        tag: 'profile_pic',
                        child: AvatarWidget(imageUrl: user.profilePhotoUrl, radius: 80),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          backgroundColor: const Color(0xFF9575CD),
                          radius: 24,
                          child: _isUploading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : IconButton(
                                  icon: const Icon(Icons.camera_alt, color: Colors.white),
                                  onPressed: _pickAndUploadImage,
                                ),
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                
                // Name
                ListTile(
                  leading: const Icon(Icons.person, color: Colors.grey),
                  title: const Text('Name', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  subtitle: Text(user.name.isEmpty ? 'Tap to add name' : user.name, style: const TextStyle(fontSize: 16, color: Colors.black)),
                  trailing: const Icon(Icons.edit, color: Color(0xFF075E54)),
                  onTap: () => _editName(context, user.name),
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 70, right: 16),
                  child: Text(
                    'This is not your username or pin. This name will be visible to your WhatsApp contacts.', 
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
                const Divider(indent: 70),

                // About
                ListTile(
                   leading: const Icon(Icons.info_outline, color: Colors.grey),
                   title: const Text('About', style: TextStyle(fontSize: 12, color: Colors.grey)),
                   subtitle: Text(user.about, style: const TextStyle(fontSize: 16, color: Colors.black)),
                   trailing: const Icon(Icons.edit, color: Color(0xFF9575CD)),
                   onTap: () => _editAbout(context, user.about),
                ),
                const Divider(indent: 70),

                // Phone
                ListTile(
                   leading: const Icon(Icons.phone, color: Colors.grey),
                   title: const Text('Phone', style: TextStyle(fontSize: 12, color: Colors.grey)),
                   subtitle: Text(user.phoneNumber, style: const TextStyle(fontSize: 16, color: Colors.black)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
