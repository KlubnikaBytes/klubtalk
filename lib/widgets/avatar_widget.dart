import 'package:flutter/material.dart';

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
    Widget avatar = CircleAvatar(
      radius: radius,
      backgroundImage: NetworkImage(imageUrl),
      backgroundColor: Colors.grey[300],
      onBackgroundImageError: (_, __) {
        // Fallback or placeholder handling could go here
      },
    );

    if (heroTag != null) {
      return Hero(
        tag: heroTag!,
        child: avatar,
      );
    }
    return avatar;
  }
}
