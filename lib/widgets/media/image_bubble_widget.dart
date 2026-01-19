import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:whatsapp_clone/config/api_config.dart';
import 'package:whatsapp_clone/utils/web_image_utils.dart';

class ImageBubbleWidget extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;

  const ImageBubbleWidget({
    super.key,
    required this.message,
    required this.isMe,
  });

  String _getFullUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '${ApiConfig.baseUrl}$path';
  }

  @override
  Widget build(BuildContext context) {
    // 1. Check for local bytes (Draft / Preview)
    final Uint8List? imageBytes = message['imageBytes'];
    final String? previewUrl = message['previewUrl'];
    
    // 2. Determine Image Provider
    Widget? imageWidget;
    
      if (imageBytes != null) {
       // Local bytes (sending phase)
       if (kIsWeb) {
        // Universal Blob creation with explicit MIME, matching JPG behavior.
        final mime = message['mime'] ?? message['mimeType'];
        final contentType = (mime != null && mime.isNotEmpty) ? mime : 'image/jpeg';
        
        final blobUrl = createImageUrlFromBytes(imageBytes, mimeType: contentType);
        imageWidget = Image.network(
             blobUrl, 
             fit: BoxFit.cover, 
             width: 250, 
             height: 250,
             gaplessPlayback: true, 
             errorBuilder: (context, error, stackTrace) => _buildErrorWidget()
        );
      } else {
        imageWidget = Image.memory(
          imageBytes, 
          fit: BoxFit.cover, 
          width: 250, 
          height: 250, 
          errorBuilder: (context, error, stackTrace) => _buildErrorWidget()
        );
      }
    } else if (previewUrl != null && previewUrl.isNotEmpty) {
       // 3. Use Thumbnail (Server Preview)
       final url = _getFullUrl(previewUrl);
       imageWidget = Image.network(
            url,
            fit: BoxFit.cover,
            width: 250,
            height: 250,
            errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
            loadingBuilder: (context, child, loadingProgress) => _buildLoadingWidget(child, loadingProgress),
       );
    } else {
      // 4. Fallback to Original URL (Image messages)
      final content = message['content'] ?? message['text'] ?? '';
      final url = _getFullUrl(content);
      
      imageWidget = Hero(
          tag: 'image_${message['_id'] ?? DateTime.now().millisecondsSinceEpoch}',
          child: Image.network(
            url,
            fit: BoxFit.cover,
            width: 250,
            height: 250,
            errorBuilder: (context, error, stackTrace) {
               return _buildErrorWidget();
            },
            loadingBuilder: (context, child, loadingProgress) => _buildLoadingWidget(child, loadingProgress),
          ),
        );
    }

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(backgroundColor: Colors.transparent, iconTheme: const IconThemeData(color: Colors.white)),
              body: Center(
                child: Builder(
                  builder: (context) {
                    if (imageBytes != null) {
                      if (kIsWeb) {
                        final mime = message['mime'] ?? message['mimeType'];
                        final contentType = (mime != null && mime.isNotEmpty) ? mime : 'image/jpeg';
                        final blobUrl = createImageUrlFromBytes(imageBytes, mimeType: contentType);
                        return Image.network(blobUrl, fit: BoxFit.contain, gaplessPlayback: true);
                      } else {
                        return Image.memory(imageBytes, fit: BoxFit.contain);
                      }
                    } else {
                       // Use Original URL for Fullscreen
                       final originalUrl = message['originalUrl'] ?? message['content'] ?? message['text'] ?? '';
                       final url = _getFullUrl(originalUrl);
                       return Image.network(url, fit: BoxFit.contain);
                    }
                  }
                ),
              ),
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            imageWidget ?? Container(),
            // Timestamp & Status Overlay
            Positioned(
              bottom: 6,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                     Text(
                        message['timestamp'] != null 
                           ? // Importing intl needed or raw string? Using basic logic or need import. 
                             // Best to assume Intl is available or use simple parsing if import missing.
                             // Actually, let's use a cleaner approach: pass formatted time or just format it.
                             // We'll add import 'package:intl/intl.dart'; at top.
                             DateFormat('h:mm a').format(DateTime.parse(message['timestamp']).toLocal())
                           : '',
                        style: const TextStyle(color: Colors.white, fontSize: 10)
                     ),
                     if (isMe) ...[
                       const SizedBox(width: 4),
                       Icon(
                         (message['status'] == 'seen' || message['status'] == 'delivered') 
                             ? Icons.done_all 
                             : Icons.done,
                         size: 14, 
                         color: message['status'] == 'seen' ? const Color(0xFF53BDEB) : Colors.white
                       )
                     ]
                  ],
                ),
              ),
            )
          ],
        )
      ),
    );
  }

  Widget _buildLoadingWidget(Widget child, ImageChunkEvent? loadingProgress) {
    if (loadingProgress == null) return child;
    return Container(
      width: 250, height: 250,
      color: Colors.grey[200],
      child: Center(
        child: CircularProgressIndicator(
          value: loadingProgress.expectedTotalBytes != null
              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
              : null,
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: 250, height: 250,
      color: Colors.grey[300],
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image, color: Colors.grey),
          SizedBox(height: 4),
          Text("Image Error", style: TextStyle(color: Colors.grey, fontSize: 10))
        ],
      ),
    );
  }
}
