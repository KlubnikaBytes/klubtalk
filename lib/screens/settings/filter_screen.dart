
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photofilters/photofilters.dart';
import 'package:image/image.dart' as img; // 'image' package
import 'package:path/path.dart';

class FilterScreen extends StatelessWidget {
  final String imagePath;

  const FilterScreen({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    // 1. Decode image for filtering
    final imageFile = File(imagePath);
    var image = img.decodeImage(imageFile.readAsBytesSync());

    if (image == null) {
        return Scaffold(
            appBar: AppBar(title: const Text("Error")),
            body: const Center(child: Text("Failed to load image")),
        );
    }
    
    // Resize for better performance on mobile updates
    image = img.copyResize(image, width: 600); 

    // 2. Return the Lib's Filter Selector
    return PhotoFilterSelector(
      title: const Text("Apply Filter"),
      image: image,
      filters: presetFiltersList,
      filename: basename(imagePath),
      loader: const Center(child: CircularProgressIndicator()),
      fit: BoxFit.contain,
      appBarColor: const Color(0xFF075E54), // Whatsapp Greenish
    );
  }
}
