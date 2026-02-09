import 'package:flutter/material.dart';
import 'package:whatsapp_clone/services/auth_service.dart';

class TwoStepVerificationScreen extends StatefulWidget {
  const TwoStepVerificationScreen({super.key});

  @override
  State<TwoStepVerificationScreen> createState() => _TwoStepVerificationScreenState();
}

class _TwoStepVerificationScreenState extends State<TwoStepVerificationScreen> {
  bool _isEnabled = false;
  final _pinController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  void _checkStatus() {
    // In a real app, we'd check if a PIN is set.
    // Here we'll just check if the local user object has a dummy 'twoFactorPin'
    final user = AuthService().currentUser;
    setState(() {
      _isEnabled = user != null && user['twoFactorPin'] != null && user['twoFactorPin'].toString().isNotEmpty;
    });
  }

  Future<void> _enableTwoStep() async {
    if (_pinController.text.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN must be 6 digits')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await AuthService().updateAccountSettings(twoFactorPin: _pinController.text);
      setState(() {
        _isEnabled = true;
      });
      if (mounted) Navigator.pop(context); // Close dialog
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to enable: $e')),
        );
      }
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  Future<void> _disableTwoStep() async {
     setState(() {
      _isLoading = true;
    });

    try {
      // Sending empty string or null to clear? API might need tweak or we send empty string.
      await AuthService().updateAccountSettings(twoFactorPin: ""); 
      setState(() {
        _isEnabled = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to disable: $e')),
        );
      }
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  void _showPinDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create a 6-digit PIN'),
        content: TextField(
          controller: _pinController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          obscureText: true,
          decoration: const InputDecoration(hintText: '******'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: _enableTwoStep,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Two-step verification')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Icon(Icons.verified_user, size: 80, color: Colors.teal),
            const SizedBox(height: 24),
            const Text(
              'For extra security, turn on two-step verification, which will require a PIN when registering your phone number with WhatsApp again.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),
            if (_isEnabled)
              Column(
                children: [
                   const Text('Two-step verification is ON', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                   const SizedBox(height: 20),
                   ListTile(
                     leading: const Icon(Icons.close),
                     title: const Text('Turn off'),
                     onTap: _isLoading ? null : _disableTwoStep,
                   ),
                   ListTile(
                     leading: const Icon(Icons.pin),
                     title: const Text('Change PIN'),
                     onTap: _isLoading ? null : _showPinDialog,
                   ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _showPinDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF008069),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Turn on'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
