import 'dart:math';
import 'package:flutter/material.dart';
import 'package:whatsapp_clone/services/user_service.dart';
import 'package:whatsapp_clone/widgets/avatar_widget.dart';

class AvatarScreen extends StatefulWidget {
  const AvatarScreen({super.key});

  @override
  State<AvatarScreen> createState() => _AvatarScreenState();
}

class _AvatarScreenState extends State<AvatarScreen> {
  final UserService _userService = UserService();
  String _currentSeed = 'klubnika';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _randomize();
  }

  void _randomize() {
    setState(() {
      _currentSeed = Random().nextInt(1000000).toString();
    });
  }

  String get _avatarUrl => 'https://api.dicebear.com/9.x/avataaars/png?seed=$_currentSeed';

  Future<void> _saveAvatar() async {
    setState(() => _isLoading = true);
    try {
      await _userService.updateProfilePhotoUrl(_avatarUrl);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Avatar updated successfully!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update avatar: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Avatar')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Your New Look",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFC92136), width: 4),
              ),
              child: AvatarWidget(
                imageUrl: _avatarUrl,
                radius: 100, // Large preview
              ),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _randomize,
                  icon: const Icon(Icons.refresh),
                  label: const Text("Randomize"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
                const SizedBox(width: 20),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _saveAvatar,
                  icon: _isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check),
                  label: const Text("Use This"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC92136),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              "Powered by DiceBear",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
