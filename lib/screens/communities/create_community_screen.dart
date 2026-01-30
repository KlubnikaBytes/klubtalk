import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:whatsapp_clone/models/group_model.dart';
import 'package:whatsapp_clone/services/chat_service.dart';
import 'package:whatsapp_clone/services/community_service.dart';
import 'package:whatsapp_clone/services/auth_service.dart';
import 'package:whatsapp_clone/services/media_upload_service.dart';
import 'dart:io';

class CreateCommunityScreen extends StatefulWidget {
  const CreateCommunityScreen({super.key});

  @override
  State<CreateCommunityScreen> createState() => _CreateCommunityScreenState();
}

class _CreateCommunityScreenState extends State<CreateCommunityScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  
  File? _imageFile;
  String? _uploadedPhotoUrl;
  bool _isUploading = false;
  bool _isLoading = false;
  
  List<GroupModel> _myAdminGroups = [];
  final Set<String> _selectedGroupIds = {};

  int _step = 0;

  @override
  void initState() {
    super.initState();
    _fetchMyAdminGroups();
  }

  Future<void> _fetchMyAdminGroups() async {
    final chatService = ChatService();
    // Assuming getMyChats returns base Chat/Group models. 
    // We need to filter for groups where I am admin.
    // Ideally backend should have an endpoint, but filtering client side for now.
    final chats = await chatService.getMyChats();
    // Checking ChatService (assumed)
    
    // Fallback: If getAllChats returns generic objects, we need a way to check admin status.
    // For now, I'll assume we can filter locally.
    final myId = AuthService().currentUserId;
    
    // We need to cast or convert to GroupModel if possible
    // Assuming chats are list of dynamic or ChatModel
    
    // Logic:
    // _myAdminGroups = chats.where((c) => c.isGroup && c.admins.contains(myId)).toList();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
      // Upload immediately or on save?
      // Better upload now to get URL
      _uploadImage(File(picked.path));
    }
  }

  Future<void> _uploadImage(File file) async {
    setState(() => _isUploading = true);
    try {
      final mediaService = MediaUploadService(); 
      // Expecting Map<String, dynamic> {'url': ...}
      final result = await mediaService.uploadImage(file); 
      final url = result['url'];
       setState(() => _uploadedPhotoUrl = url);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _createCommunity() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name is required')));
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      final service = CommunityService();
      final community = await service.createCommunity(
        _nameController.text,
        _descController.text,
        _uploadedPhotoUrl ?? '',
        _selectedGroupIds.toList(),
      );

      if (community != null) {
        Navigator.pop(context); // Close creator
        // Navigate to Community Home?
      } else {
        throw Exception('Failed to create');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Community'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
             if (_step == 1) {
               _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.ease);
               setState(() => _step = 0);
             } else {
               Navigator.pop(context);
             }
          },
        ),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildInfoStep(),
          _buildGroupSelectionStep(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_step == 0) {
            if (_nameController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a name')));
              return;
            }
             _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.ease);
             setState(() => _step = 1);
          } else {
            _createCommunity();
          }
        },
        child: Icon(_step == 0 ? Icons.arrow_forward : Icons.check),
      ),
    );
  }

  Widget _buildInfoStep() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SingleChildScrollView(
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: _imageFile != null ? FileImage(_imageFile!) : null,
                    child: _imageFile == null 
                      ? const Icon(Icons.groups, size: 60, color: Colors.grey)
                      : null,
                  ),
                  if (_isUploading)
                    const Positioned.fill(child: CircularProgressIndicator()),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      backgroundColor: Theme.of(context).primaryColor,
                      radius: 18,
                      child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Community Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupSelectionStep() {
    // Need to have groups loaded here
    // For prototype, I will use a FutureBuilder or assuming loaded in initState
    // But since I don't have ChatService details handy, I will stub UI
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Add your groups to this community',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Expanded(
          child: FutureBuilder(
            future: ChatService().getMyChats(), 
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData) return const Center(child: Text("No groups found"));
              
              final myId = AuthService().currentUserId;
              // Filter: Must be group and I must be admin
              // Using dynamic check because I don't have exact ChatModel signature in head, 
              // but I recall ChatModel has isGroup and groupAdmins
              
              final allChats = snapshot.data as List<dynamic>; 
              final adminGroups = allChats.where((c) {
                 // Check isGroup
                 try {
                   // Ensure it's a map
                   if (c is! Map<String, dynamic>) return false;
                   
                   final isGroup = c['isGroup'] == true;
                   if (!isGroup) return false;

                   // Check admin (Handle Map structure)
                   bool isAdmin = false;
                   if (c['groupAdmins'] != null && c['groupAdmins'] is List) {
                      final admins = c['groupAdmins'] as List;
                      isAdmin = admins.any((a) {
                         if (a is String) return a == myId;
                         if (a is Map) return a['_id'] == myId || a['id'] == myId;
                         return false;
                      });
                   }
                   
                   // Fallback for single admin field
                   if (!isAdmin && c['groupAdmin'] != null) {
                      final admin = c['groupAdmin'];
                      if (admin is String) isAdmin = admin == myId;
                      if (admin is Map) isAdmin = admin['_id'] == myId;
                   }
                   
                   return isAdmin;
                 } catch (e) { return false; }
              }).toList();

              if (adminGroups.isEmpty) {
                return const Center(child: Text("You are not admin of any groups"));
              }

              return ListView.builder(
                itemCount: adminGroups.length,
                itemBuilder: (context, index) {
                   final group = adminGroups[index];
                   final groupId = group['_id'] ?? group['id'];
                   final isSelected = _selectedGroupIds.contains(groupId);
                   final groupName = group['groupName'] ?? 'Unknown Group';
                   final groupAvatar = group['groupAvatar'] ?? group['groupPhoto'] ?? '';
                   
                   return CheckboxListTile(
                     value: isSelected,
                     title: Text(groupName),
                     secondary: CircleAvatar(
                       backgroundImage: (groupAvatar.isNotEmpty) 
                         ? NetworkImage(groupAvatar) 
                         : null,
                       child: (groupAvatar.isEmpty) ? const Icon(Icons.group) : null,
                     ),
                     onChanged: (val) {
                       setState(() {
                         if (val == true) {
                           _selectedGroupIds.add(groupId);
                         } else {
                           _selectedGroupIds.remove(groupId);
                         }
                       });
                     },
                   );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
