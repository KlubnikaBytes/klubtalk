import 'package:flutter/material.dart';
import 'package:whatsapp_clone/layout/responsive_layout.dart';
import 'package:whatsapp_clone/screens/chat_list_screen.dart';
import 'package:whatsapp_clone/screens/web_layout_screen.dart';
import 'package:whatsapp_clone/services/auth_service.dart';
import 'package:whatsapp_clone/screens/auth/user_info_screen.dart';

class OtpScreen extends StatefulWidget {
  final String phoneNumber;

  const OtpScreen({
    super.key,
    required this.phoneNumber,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _otpController = TextEditingController();
  bool _isLoading = false;

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a 6-digit code')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Create Custom Session via Backend
      final data = await AuthService().verifyOtp(widget.phoneNumber, otp);
      final bool isNewUser = data['isNewUser'] == true;

      if (mounted) {
         if (isNewUser) {
           Navigator.pushAndRemoveUntil(
             context,
             MaterialPageRoute(
               builder: (context) => UserInfoScreen(phoneNumber: widget.phoneNumber),
             ),
             (route) => false,
           );
         } else {
           // Navigate to Home
           Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
               builder: (context) => const ResponsiveLayout(
                  mobileScaffold: MobileChatLayout(),
                  webScaffold: WebLayoutScreen(),
               )
            ),
            (route) => false,
          );
         }
      }

    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Phone Number')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text(
              'Waiting to automatically detect an SMS sent to ${widget.phoneNumber}.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 5),
              decoration: const InputDecoration(
                hintText: '- - - - - -',
                counterText: '',
              ),
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC92136),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _verifyOtp,
                    child: const Text('Verify'),
                  ),
          ],
        ),
      ),
    );
  }
}
