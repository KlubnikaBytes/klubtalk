import 'package:flutter/material.dart';
import 'package:whatsapp_clone/screens/otp_screen.dart';
import 'package:whatsapp_clone/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  Future<void> _verifyPhone() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.length != 10) { // WhatsApp style: strict 10 digits
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 10-digit phone number')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Force +91
      final fullPhone = '+91$phone';
      await AuthService().sendOtp(fullPhone);
      
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OtpScreen(phoneNumber: fullPhone), 
          ),
        );
      }
    } catch (e) {
      if (mounted) {
         setState(() => _isLoading = false);
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Error: $e')),
         );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enter Your Phone Number'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black, // or purple
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 20.0),
        child: Column(
          children: [
            const Text(
              'KlubTalk will need to verify your phone number.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const SizedBox(
                  width: 60,
                  child: TextField(
                    enabled: false,
                    decoration: InputDecoration(
                       hintText: '+91',
                       contentPadding: EdgeInsets.all(8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    decoration: const InputDecoration(
                      hintText: 'phone number',
                      counterText: '', // Hide length counter
                    ),
                  ),
                ),
              ],
            ),
             const Spacer(),
             SizedBox(
               width: 90, 
               child: _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC92136),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _verifyPhone,
                    child: const Text('NEXT'),
                  ),
             ),
             const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
