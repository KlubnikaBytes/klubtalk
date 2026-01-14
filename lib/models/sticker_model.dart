
class Sticker {
  final String id;
  final String packId;
  final String imageUrl; // Remote URL
  final String? localPath; // For cached/offline access
  final bool isAnimated;
  final String? mimeType; // 'image/webp', 'application/json' (lottie)
  final int width;
  final int height;
  final int sizeKB;
  
  bool get isLottie => mimeType == 'application/json';

  Sticker({
    required this.id,
    required this.packId,
    required this.imageUrl,
    this.localPath,
    this.isAnimated = false,
    this.mimeType,
    this.width = 512,
    this.height = 512,
    this.sizeKB = 0,
  });

  factory Sticker.fromJson(Map<String, dynamic> json) {
    return Sticker(
      id: json['id'] ?? '',
      packId: json['packId'] ?? '',
      imageUrl: json['url'] ?? '',
      isAnimated: json['isAnimated'] ?? false,
      mimeType: json['mimeType'],
      width: json['width'] ?? 512,
      height: json['height'] ?? 512,
      sizeKB: json['sizeKB'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'packId': packId,
      'url': imageUrl,
      'isAnimated': isAnimated,
      'mimeType': mimeType,
      'width': width,
      'height': height,
      'sizeKB': sizeKB,
      if (localPath != null) 'localPath': localPath,
    };
  }
  
  // Hive/Adapter Logic (Manual for now to avoid build_runner wait)
  // We can add HiveType annotations if we run build_runner, 
  // or just store as JSON in Hive if we want simplicity.
  // For now, let's keep it POJO and handle serialization in Service.
}

class StickerPack {
  final String id;
  final String name;
  final String author;
  final String trayImageFile; // The icon for the pack tab
  final List<Sticker> stickers;
  final bool isAnimated;
  
  StickerPack({
    required this.id,
    required this.name,
    required this.author,
    required this.trayImageFile,
    this.stickers = const [],
    this.isAnimated = false,
  });

  factory StickerPack.fromJson(Map<String, dynamic> json) {
    var rawStickers = json['stickers'] as List? ?? [];
    List<Sticker> stickerList = rawStickers.map((s) => Sticker.fromJson(s)).toList();

    return StickerPack(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unknown Pack',
      author: json['author'] ?? 'Unknown',
      trayImageFile: json['trayImage'] ?? '',
      isAnimated: json['isAnimated'] ?? false,
      stickers: stickerList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'author': author,
      'trayImage': trayImageFile,
      'isAnimated': isAnimated,
      'stickers': stickers.map((s) => s.toJson()).toList(),
    };
  }
}
