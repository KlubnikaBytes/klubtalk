import 'package:flutter/material.dart';
import 'package:whatsapp_clone/services/auth_service.dart';

class RequestAccountInfoScreen extends StatefulWidget {
  const RequestAccountInfoScreen({super.key});

  @override
  State<RequestAccountInfoScreen> createState() => _RequestAccountInfoScreenState();
}

class _RequestAccountInfoScreenState extends State<RequestAccountInfoScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _report;

  Future<void> _requestReport() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final report = await AuthService().getAccountInfo();
      setState(() {
        _report = report;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to request report: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request account info')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.description, size: 80, color: Colors.teal),
            const SizedBox(height: 16),
            const Text(
              'Create a report of your WhatsApp account information and settings, which you can access or port to another app. This report does not include your messages.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            if (_report == null)
              ListTile(
                leading: const Icon(Icons.file_download),
                title: const Text('Request report'),
                onTap: _isLoading ? null : _requestReport,
                trailing: _isLoading ? const CircularProgressIndicator() : null,
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Report Ready', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Generated at: ${_report!['generatedAt']}'),
                      const SizedBox(height: 8),
                      Text('User ID: ${_report!['user']['_id']}'),
                      Text('Phone: ${_report!['user']['phone']}'),
                      Text('Email: ${_report!['user']['email'] ?? "Not set"}'),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
