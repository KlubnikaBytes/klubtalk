import 'package:flutter/material.dart';
import 'package:whatsapp_clone/config/api_config.dart';

class AvatarWidget extends StatelessWidget {
  final String imageUrl;
  final double radius;
  final String? heroTag;

  const AvatarWidget({
    super.key,
    required this.imageUrl,
    this.radius = 24,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Check if we have a valid image string
    final bool hasImage = imageUrl.isNotEmpty;
    
    // 2. Construct full URL if relative
    String fullUrl = imageUrl;
    if (hasImage && !imageUrl.startsWith('http')) {
        fullUrl = '${ApiConfig.baseUrl}$imageUrl';
    }

    // DEBUG: Verify final URL
    if (hasImage) {
      print("Avatar URL -> $fullUrl");
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[300],
      // Only set backgroundImage if we have an image
      backgroundImage: hasImage ? NetworkImage(fullUrl) : null,
      // Only set error handler if we have an image (prevents assertion error)
      onBackgroundImageError: hasImage ? (_, __) {
         // Silently fail to background color/child if 404
      } : null,
      // Helper child if no image
      child: !hasImage 
          ? Icon(Icons.person, size: radius, color: Colors.white) 
          : null,
    );
  }
}
