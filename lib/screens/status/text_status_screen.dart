
import 'package:flutter/material.dart';
import 'package:whatsapp_clone/services/status_service.dart';
import 'package:whatsapp_clone/screens/status/status_privacy_screen.dart';

class TextStatusScreen extends StatefulWidget {
  const TextStatusScreen({super.key});

  @override
  State<TextStatusScreen> createState() => _TextStatusScreenState();
}

class _TextStatusScreenState extends State<TextStatusScreen> {
  final TextEditingController _controller = TextEditingController();
  final StatusService _statusService = StatusService();
  
  // WhatsApp Style Colors
  final List<Color> _colors = [
    const Color(0xFF7E57C2), // Purple (Theme)
    const Color(0xFFE91E63), // Pink
    const Color(0xFF2196F3), // Blue
    const Color(0xFF8BC34A), // Light Green
    const Color(0xFFFF9800), // Orange
    const Color(0xFF607D8B), // Blue Grey
    Colors.black,
  ];

  final List<String> _fonts = [
    'sans',
    'serif',
    'monospace',
    'cursive', 
  ]; // In real app, map to GoogleFonts

  int _colorIndex = 0;
  int _fontIndex = 0;
  bool _isSending = false;

  // Privacy State
  String _privacy = 'contacts';
  List<String> _allowedUsers = [];
  List<String> _excludedUsers = [];

  void _cycleColor() {
    setState(() {
      _colorIndex = (_colorIndex + 1) % _colors.length;
    });
  }

  void _cycleFont() {
    setState(() {
      _fontIndex = (_fontIndex + 1) % _fonts.length;
    });
  }

  Future<void> _openPrivacy() async {
     final result = await Navigator.push(context, MaterialPageRoute(
       builder: (_) => StatusPrivacyScreen(
         currentPrivacy: _privacy, 
         currentAllowed: _allowedUsers, 
         currentExcluded: _excludedUsers
       )
     ));
     
     if (result != null && result is Map) {
        setState(() {
           _privacy = result['privacy'];
           _allowedUsers = result['allowed'];
           _excludedUsers = result['excluded'];
        });
     }
  }

  Future<void> _sendStatus() async {
    if (_controller.text.trim().isEmpty) return;

    setState(() => _isSending = true);
    try {
      // Hex color
      String hexColor = '#${_colors[_colorIndex].value.toRadixString(16).substring(2)}';
      
      await _statusService.createTextStatus(
        text: _controller.text.trim(),
        backgroundColor: hexColor,
        privacy: _privacy,
        allowedUsers: _allowedUsers,
        excludedUsers: _excludedUsers
      );
      
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine font family based on index (Placeholder logic)
    TextStyle getTextStyle() {
       switch(_fonts[_fontIndex]) {
          case 'serif': return const TextStyle(fontFamily: 'Times New Roman', fontWeight: FontWeight.bold);
          case 'monospace': return const TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.w500);
          case 'cursive': return const TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.bold);
          default: return const TextStyle(fontWeight: FontWeight.normal);
       }
    }

    return Scaffold(
      backgroundColor: _colors[_colorIndex],
      body: SafeArea(
        child: Stack(
          children: [
            // Input Area
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: TextField(
                  controller: _controller,
                  textAlign: TextAlign.center,
                  maxLines: null,
                  autofocus: true,
                  style: getTextStyle().copyWith(
                     fontSize: 40,
                     color: Colors.white,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Type a status',
                    hintStyle: TextStyle(color: Colors.white54, fontSize: 40),
                  ),
                  onChanged: (val) => setState((){}),
                ),
              ),
            ),

            // Top Toolbar
            Positioned(
              top: 10, left: 10, right: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.white, size: 28),
                        onPressed: () {
                           // Toggle Emoji Picker (TODO: Integrate library)
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Emoji picker TODO")));
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.text_fields, color: Colors.white, size: 28),
                        onPressed: _cycleFont,
                      ),
                      IconButton(
                        icon: const Icon(Icons.palette, color: Colors.white, size: 28),
                        onPressed: _cycleColor,
                      ),
                    ],
                  )
                ],
              ),
            ),

            // Privacy Bubble
            Positioned(
              bottom: 20, left: 20,
              child: GestureDetector(
                onTap: _openPrivacy,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                       Text(
                         _privacy == 'contacts' ? 'Status (Contacts)' 
                         : (_privacy == 'exclude' ? 'Status (Excluded)' : 'Status (Selected)'),
                         style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                       ),
                       const SizedBox(width: 4),
                       const Icon(Icons.arrow_drop_down, color: Colors.white)
                    ],
                  ),
                ),
              )
            ),

            // Send Button
            if (_controller.text.trim().isNotEmpty)
              Positioned(
                bottom: 20, right: 20,
                child: FloatingActionButton(
                  backgroundColor: const Color(0xFF7E57C2), // Purple send button
                  onPressed: _isSending ? null : _sendStatus,
                  child: _isSending 
                     ? const CircularProgressIndicator(color: Colors.white) 
                     : const Icon(Icons.send, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
