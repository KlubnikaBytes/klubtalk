import 'package:flutter/material.dart';
import 'package:whatsapp_clone/services/auth_service.dart';
import 'package:whatsapp_clone/screens/login_screen.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  Future<void> _deleteAccount() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter your phone number')),
        );
        return;
    }

    // Confirmation Dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Proceed to delete this account?'),
        content: const Text('Deleting your account is permanent. Your data cannot be recovered if you reactivate your WhatsApp account in the future.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete account')
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await AuthService().deleteAccount(phone);
      if (mounted) {
         Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete account: $e')),
        );
      }
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Delete my account')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
             const Row(
               children: [
                 Icon(Icons.warning_amber_rounded, color: Colors.red),
                 SizedBox(width: 16),
                 Expanded(child: Text('Deleting your account will:', style: TextStyle(color: Colors.red))),
               ],
             ),
             const SizedBox(height: 10),
             const Padding(
               padding: EdgeInsets.only(left: 40.0),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text('• Delete your account info and profile photo'),
                   Text('• Delete you from all WhatsApp groups'),
                   Text('• Delete your message history'),
                 ],
               ),
             ),
             const SizedBox(height: 24),
             const Divider(),
             const SizedBox(height: 16),
             const Text('Confirm your phone number'),
             const SizedBox(height: 16),
             TextField(
               controller: _phoneController,
               keyboardType: TextInputType.phone,
               decoration: const InputDecoration(
                 labelText: 'Phone number',
                 hintText: 'e.g. +1 555 123 4567',
                 border: OutlineInputBorder(),
               ),
             ),
             const SizedBox(height: 32),
             SizedBox(
               width: double.infinity,
               child: ElevatedButton(
                 onPressed: _isLoading ? null : _deleteAccount,
                 style: ElevatedButton.styleFrom(
                   backgroundColor: Colors.red,
                   foregroundColor: Colors.white,
                 ),
                 child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('DELETE MY ACCOUNT'),
               ),
             ),
          ],
        ),
      ),
    );
  }
}
