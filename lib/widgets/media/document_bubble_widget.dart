import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:whatsapp_clone/config/api_config.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;

class DocumentBubbleWidget extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;

  const DocumentBubbleWidget({
    super.key,
    required this.message,
    required this.isMe,
  });

  String _getFullUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '${ApiConfig.baseUrl}$path';
  }

  Future<void> _openFile() async {
    final content = message['content'] ?? message['url'] ?? '';
    print('📄 Document tap: content=$content');
    
    if (content.isEmpty) {
      print('❌ Document tap: content is empty');
      return;
    }
    
    final fullUrl = _getFullUrl(content);
    print('📄 Document tap: fullUrl=$fullUrl');
    
    try {
      // Download the file first
      print('⬇️ Downloading document...');
      final response = await http.get(Uri.parse(fullUrl));
      
      if (response.statusCode == 200) {
        // Get temp directory
        final dir = await getTemporaryDirectory();
        final filename = path.basename(content);
        final file = File('${dir.path}/$filename');
        
        // Save file
        await file.writeAsBytes(response.bodyBytes);
        print('✅ Document saved to: ${file.path}');
        
        // Open with default app using open_file package
        final result = await OpenFile.open(file.path);
        print('📄 Open result: ${result.message}');
        
        if (result.type != ResultType.done) {
          print('❌ Failed to open: ${result.message}');
        }
      } else {
        print('❌ Download failed: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error opening document: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Extract just the filename from the path (in case it contains directory structure)
    final String rawFilename = message['filename'] ?? 'Document';
    final String filename = path.basename(rawFilename);
    final int? size = message['size']; // in bytes

    String sizeStr = '';
    if (size != null) {
       if (size < 1024) sizeStr = '$size B';
       else if (size < 1048576) sizeStr = '${(size / 1024).toStringAsFixed(1)} KB';
       else sizeStr = '${(size / 1048576).toStringAsFixed(1)} MB';
    }

    return GestureDetector(
      onTap: _openFile,
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(5), // Reduced padding to fit timestamp
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9FA), // Very light grey often used in doc bubbles
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // File Info Row
            Container(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E5E5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.insert_drive_file, color: Color(0xFF90A4AE), size: 30),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          filename,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (sizeStr.isNotEmpty)
                              Text(
                                sizeStr,
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            if (sizeStr.isNotEmpty)
                              const SizedBox(width: 5),
                            const Text(
                              "•", // Bullet
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            const SizedBox(width: 5),
                            Text(
                               (message['mimeType'] ?? 'FILE').toString().toUpperCase().split('/').last,
                               style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Timestamp & Status (Bottom Right of Bubble)
            Padding(
              padding: const EdgeInsets.only(right: 6, bottom: 4),
              child: Row(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                    Text(
                       DateFormat('h:mm a').format(
                          DateTime.parse(message['timestamp'] ?? message['createdAt'] ?? DateTime.now().toIso8601String()).toLocal()
                       ),
                       style: const TextStyle(fontSize: 10, color: Colors.grey)
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Icon(
                        (message['status'] == 'seen' || message['status'] == 'delivered') 
                            ? Icons.done_all 
                            : Icons.done,
                        size: 14, 
                        color: message['status'] == 'seen' ? const Color(0xFF53BDEB) : Colors.grey
                      )
                    ]
                 ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
