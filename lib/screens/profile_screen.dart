import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:whatsapp_clone/models/project_models.dart' as model; // Alias to avoid conflict if any
import 'package:whatsapp_clone/services/media_upload_service.dart';

class ProfileScreen extends StatefulWidget {
  final model.User user;

  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late String _avatarUrl;
  bool _isUploading = false;
  bool _isMe = false;

  @override
  void initState() {
    super.initState();
    _avatarUrl = widget.user.avatarUrl;
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && currentUser.uid == widget.user.id) {
      _isMe = true;
    }
  }

  Future<void> _updateProfilePhoto() async {
    if (!_isMe || _isUploading) return;

    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image == null) return;

    setState(() => _isUploading = true);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Uploading profile photo...')));

    try {
      final uploadService = MediaUploadService();
      final newUrl = await uploadService.uploadProfilePhoto(image.path);

      // Update Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.id)
          .update({'profilePhotoUrl': newUrl});

      setState(() {
        _avatarUrl = newUrl;
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated!')));
    } catch (e) {
      print('Profile Update Error: $e');
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(widget.user.name),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    onTap: _isMe ? _updateProfilePhoto : null,
                    child: Hero(
                      tag: widget.user.id,
                      child: Image.network(
                        _avatarUrl,
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
                  if (_isUploading)
                    const Center(child: CircularProgressIndicator()),
                  if (_isMe && !_isUploading)
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColor,
                        radius: 20,
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // ... Rest of the UI remains mostly static for now
          SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 10),
              // Reusing existing buildSection helper logic, but inlined or copied since we replaced the class
              _buildSection(
                context,
                title: 'About and phone number',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.user.about,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 4),
                    const Divider(),
                    Text(
                      widget.user.phoneNumber,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
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
          Text(title, style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
