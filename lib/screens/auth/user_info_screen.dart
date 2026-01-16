import 'package:flutter/material.dart';
import 'package:whatsapp_clone/services/auth_service.dart';
import 'package:whatsapp_clone/layout/responsive_layout.dart';
import 'package:whatsapp_clone/screens/chat_list_screen.dart';
import 'package:whatsapp_clone/screens/web_layout_screen.dart';

class UserInfoScreen extends StatefulWidget {
  final String phoneNumber;

  const UserInfoScreen({super.key, required this.phoneNumber});

  @override
  State<UserInfoScreen> createState() => _UserInfoScreenState();
}

class _UserInfoScreenState extends State<UserInfoScreen> {
  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Update profile on backend
      // Assuming AuthService has a way to update profile or we call API directly.
      // Since we just logged in, we have a token.
      
      // Wait, we need to implement updateProfile in AuthService or ensure we use the right endpoint.
      // The current AuthController.updateProfile maps to PUT /auth/me
      
      await AuthService().updateProfile(name: name);

      if (mounted) {
         Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const ResponsiveLayout(
              mobileScaffold: MobileChatLayout(),
              webScaffold: WebLayoutScreen(),
            ),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving profile: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Info'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black, // Or purple based on theme, keeping simple
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const Text(
                'Please provide your name and an optional profile photo',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 30),
              Stack(
                children: [
                   const CircleAvatar(
                    radius: 64,
                    backgroundColor: Colors.grey, // Placeholder
                    child: Icon(Icons.person, size: 64, color: Colors.white),
                  ),
                  Positioned(
                    bottom: -10,
                    right: -10,
                    child: IconButton(
                      onPressed: () {}, // TODO: Implement Image Picker
                      icon: const Icon(Icons.add_a_photo, color: Color(0xFFC92136)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        hintText: 'Type your name here',
                        border: UnderlineInputBorder(
                             borderSide: BorderSide(color: Color(0xFFC92136))
                        ),
                        focusedBorder: UnderlineInputBorder(
                             borderSide: BorderSide(color: Color(0xFFC92136), width: 2)
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.emoji_emotions_outlined, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: 90,
                child: ElevatedButton(
                  onPressed: _saveProfile,
                   style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC92136),
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : const Text('NEXT'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
