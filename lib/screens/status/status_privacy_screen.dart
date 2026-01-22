
import 'package:flutter/material.dart';
import 'package:whatsapp_clone/screens/status/contact_picker_screen.dart';

class StatusPrivacyScreen extends StatefulWidget {
  final String currentPrivacy; // 'contacts', 'exclude', 'only'
  final List<String> currentAllowed;
  final List<String> currentExcluded;

  const StatusPrivacyScreen({
    super.key,
    required this.currentPrivacy,
    required this.currentAllowed,
    required this.currentExcluded,
  });

  @override
  State<StatusPrivacyScreen> createState() => _StatusPrivacyScreenState();
}

class _StatusPrivacyScreenState extends State<StatusPrivacyScreen> {
  late String _privacy;
  late List<String> _allowed;
  late List<String> _excluded;

  @override
  void initState() {
    super.initState();
    _privacy = widget.currentPrivacy;
    // Copies
    _allowed = List.from(widget.currentAllowed);
    _excluded = List.from(widget.currentExcluded);
  }

  void _handleRadioChange(String? value) {
    if (value == null) return;
    setState(() => _privacy = value);
  }

  Future<void> _pickExcluded() async {
    setState(() => _privacy = 'exclude'); // Auto select radio
    final result = await Navigator.push(
      context, 
      MaterialPageRoute(builder: (_) => ContactPickerScreen(title: 'Hide status from...', initialSelectedIds: _excluded))
    );
    if (result != null && result is List<String>) {
      setState(() => _excluded = result);
    }
  }

  Future<void> _pickAllowed() async {
    setState(() => _privacy = 'only'); // Auto select radio
    final result = await Navigator.push(
      context, 
      MaterialPageRoute(builder: (_) => ContactPickerScreen(title: 'Share with...', initialSelectedIds: _allowed))
    );
    if (result != null && result is List<String>) {
      setState(() => _allowed = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Status privacy", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFC92136),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text("Who can see my status updates?", style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold)),
          ),
          
          RadioListTile<String>(
            title: const Text("My contacts"),
            subtitle: const Text("Share with your contacts"),
            value: 'contacts', 
            groupValue: _privacy, 
            onChanged: _handleRadioChange,
            activeColor: const Color(0xFFC92136),
          ),
          RadioListTile<String>(
            title: const Text("My contacts except..."),
            subtitle: Text(_privacy == 'exclude' ? "${_excluded.length} excluded" : "Hide from specific contacts"),
            value: 'exclude', 
            groupValue: _privacy, 
            onChanged: (val) {
               _handleRadioChange(val);
               _pickExcluded(); 
            },
            secondary: IconButton(icon: const Icon(Icons.arrow_forward_ios, size: 16), onPressed: _pickExcluded),
            activeColor: const Color(0xFFC92136),
          ),
          RadioListTile<String>(
            title: const Text("Only share with..."),
            subtitle: Text(_privacy == 'only' ? "${_allowed.length} included" : "Share with specific contacts"),
            value: 'only', 
            groupValue: _privacy, 
            onChanged: (val) {
               _handleRadioChange(val);
               _pickAllowed();
            },
            secondary: IconButton(icon: const Icon(Icons.arrow_forward_ios, size: 16), onPressed: _pickAllowed),
            activeColor: const Color(0xFFC92136),
          ),

          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC92136),
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                   Navigator.pop(context, {
                     'privacy': _privacy,
                     'allowed': _allowed,
                     'excluded': _excluded
                   });
                },
                child: const Text("Done"),
              ),
            ),
          )
        ],
      ),
    );
  }
}
