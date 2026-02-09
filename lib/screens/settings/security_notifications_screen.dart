import 'package:flutter/material.dart';
import 'package:whatsapp_clone/services/auth_service.dart';

class SecurityNotificationsScreen extends StatefulWidget {
  const SecurityNotificationsScreen({super.key});

  @override
  State<SecurityNotificationsScreen> createState() => _SecurityNotificationsScreenState();
}

class _SecurityNotificationsScreenState extends State<SecurityNotificationsScreen> {
  bool _securityNotifications = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final user = AuthService().currentUser;
    if (user != null) {
      setState(() {
        _securityNotifications = user['securityNotifications'] ?? false;
      });
    }
  }

  Future<void> _toggleSetting(bool value) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await AuthService().updateAccountSettings(securityNotifications: value);
      setState(() {
        _securityNotifications = value;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update setting: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Security notifications')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.security, size: 80, color: Colors.green),
                const SizedBox(height: 16),
                const Text(
                  'Messages and calls in end-to-end encrypted chats appear on specific devices. If a contact\'s security code changes, you can choose to receive a notification.',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show security notifications on this device'),
                  subtitle: const Text('Get notified when your security code changes for a contact\'s phone.'),
                  trailing: Switch(
                    value: _securityNotifications,
                    onChanged: _isLoading ? null : _toggleSetting,
                    activeColor: const Color(0xFF008069),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
