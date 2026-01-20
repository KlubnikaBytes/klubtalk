import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:whatsapp_clone/services/auth_service.dart';
import 'package:whatsapp_clone/config/api_config.dart';
import 'package:whatsapp_clone/models/sticker_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StickerService {
  
  // In-memory cache
  List<StickerPack> _packs = [];
  final List<Sticker> _recents = [];
  final Set<String> _favoriteIds = {};
  final List<Sticker> _favorites = []; // Kept in sync with IDs

  static final StickerService _instance = StickerService._internal();
  factory StickerService() => _instance;
  StickerService._internal();

  Future<String?> _getToken() async => AuthService().token;

  Future<void> initialize() async {
    await _loadLocalData();
  }

  Future<void> _loadLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load Favorites
    final favList = prefs.getStringList('favorite_stickers');
    if (favList != null) {
      _favorites.clear();
      _favoriteIds.clear();
      for (var jsonStr in favList) {
        try {
          final s = Sticker.fromJson(jsonDecode(jsonStr));
          _favorites.add(s);
          _favoriteIds.add(s.id);
        } catch (e) { debugPrint('Error loading fav sticker: $e'); }
      }
    }

    // Load Recents
    final recList = prefs.getStringList('recent_stickers');
    if (recList != null) {
      _recents.clear();
      for (var jsonStr in recList) {
        try {
           _recents.add(Sticker.fromJson(jsonDecode(jsonStr)));
        } catch (e) { debugPrint('Error loading recent sticker: $e'); }
      }
    }
  }

  Future<void> _saveRecents() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _recents.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList('recent_stickers', list);
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _favorites.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList('favorite_stickers', list);
  }

  // --- PUBLIC API ---

  Future<List<StickerPack>> getPacks() async {
    // If we have cached packs, return them (simplistic caching)
    if (_packs.isNotEmpty) return _packs;

    try {
      // 1. Try Fetching from API
      // Since API might not exist yet, we wrap in try/catch and fallback
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/stickers/packs'),
        headers: token != null ? {'Authorization': 'Bearer $token'} : {},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _packs = data.map((json) => StickerPack.fromJson(json)).toList();
        return _packs;
      }
    } catch (e) {
      debugPrint('Error fetching packs: $e');
    }

    // 2. Fallback to Mock Data
    _packs = _getMockPacks();
    return _packs;
  }

  List<Sticker> getRecents() => List.unmodifiable(_recents);
  List<Sticker> getFavorites() => List.unmodifiable(_favorites);

  void addToRecents(Sticker sticker) {
    // Remove if exists to move to top
    _recents.removeWhere((s) => s.id == sticker.id);
    _recents.insert(0, sticker);
    
    if (_recents.length > 30) {
      _recents.removeLast();
    }
    _saveRecents();
  }

  void toggleFavorite(Sticker sticker) {
    if (_favoriteIds.contains(sticker.id)) {
      _favoriteIds.remove(sticker.id);
      _favorites.removeWhere((s) => s.id == sticker.id);
    } else {
      _favoriteIds.add(sticker.id);
      _favorites.add(sticker);
    }
    _saveFavorites();
  }

  bool isFavorite(Sticker sticker) => _favoriteIds.contains(sticker.id);

  // MOCK DATA GENERATOR
  List<StickerPack> _getMockPacks() {
     // Using some public domain/placeholder images for testing visually
     // Cuppy is the classic WhatsApp example pack
     return [
       StickerPack(
         id: 'pack_1',
         name: 'Cuppy',
         author: 'WhatsApp',
         trayImageFile: 'https://raw.githubusercontent.com/WhatsApp/stickers/master/Android/app/src/main/assets/1/01_Cuppy_smile.webp',
         stickers: [
            _createSticker('cuppy_1', 'pack_1', 'https://raw.githubusercontent.com/WhatsApp/stickers/master/Android/app/src/main/assets/1/01_Cuppy_smile.webp'),
            _createSticker('cuppy_2', 'pack_1', 'https://raw.githubusercontent.com/WhatsApp/stickers/master/Android/app/src/main/assets/1/02_Cuppy_lol.webp'),
            _createSticker('cuppy_3', 'pack_1', 'https://raw.githubusercontent.com/WhatsApp/stickers/master/Android/app/src/main/assets/1/03_Cuppy_rofl.webp'),
            _createSticker('cuppy_4', 'pack_1', 'https://raw.githubusercontent.com/WhatsApp/stickers/master/Android/app/src/main/assets/1/04_Cuppy_sad.webp'),
            _createSticker('cuppy_5', 'pack_1', 'https://raw.githubusercontent.com/WhatsApp/stickers/master/Android/app/src/main/assets/1/05_Cuppy_cry.webp'),
            _createSticker('cuppy_6', 'pack_1', 'https://raw.githubusercontent.com/WhatsApp/stickers/master/Android/app/src/main/assets/1/06_Cuppy_love.webp'),
         ]
       ),
       StickerPack(
         id: 'pack_2',
         name: 'Reviewer',
         author: 'Admin',
         trayImageFile: 'https://cdn-icons-png.flaticon.com/512/3260/3260838.png', 
         stickers: [
            _createSticker('rev_1', 'pack_2', 'https://cdn-icons-png.flaticon.com/512/3260/3260838.png'),
            _createSticker('rev_2', 'pack_2', 'https://cdn-icons-png.flaticon.com/512/3260/3260839.png'),
            _createSticker('rev_3', 'pack_2', 'https://cdn-icons-png.flaticon.com/512/3260/3260840.png'),
         ]
       )
     ];
  }

  Sticker _createSticker(String id, String packId, String url) {
    return Sticker(
      id: id,
      packId: packId,
      imageUrl: url,
      width: 512,
      height: 512,
      mimeType: 'image/webp'
    );
  }
}
