
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:messaging_app/models/sticker_model.dart';
import 'package:messaging_app/services/sticker_service.dart';

class StickerPickerPanel extends StatefulWidget {
  final Function(Sticker) onStickerSelected;

  const StickerPickerPanel({super.key, required this.onStickerSelected});

  @override
  State<StickerPickerPanel> createState() => _StickerPickerPanelState();
}

class _StickerPickerPanelState extends State<StickerPickerPanel> with SingleTickerProviderStateMixin {
  final StickerService _stickerService = StickerService();
  late TabController _tabController;
  List<StickerPack> _packs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _stickerService.addListener(_onServiceUpdate);
  }

  void _loadData() async {
    await _stickerService.initialize();
    if (mounted) {
      setState(() {
        _packs = _stickerService.getPacks();
        _isLoading = false;
        // 2 Fixed Tabs (Recent, Fav) + Pack Tabs
        _tabController = TabController(length: 2 + _packs.length, vsync: this);
      });
    }
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _stickerService.removeListener(_onServiceUpdate);
    // _tabController might need disposal check if initialized
    if (_packs.isNotEmpty) _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 300, 
        child: Center(child: CircularProgressIndicator())
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1F2C34) : Colors.white;

    return Container(
      height: 300, // Or dynamic ~45% of screen
      color: bgColor,
      child: Column(
        children: [
          // Tab Bar
          Container(
            height: 40,
            color: isDark ? const Color(0xFF202C33) : const Color(0xFFEEEEEE),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: const Color(0xFF00A884),
              labelColor: const Color(0xFF00A884),
              unselectedLabelColor: Colors.grey,
              tabs: [
                const Tab(icon: Icon(Icons.access_time, size: 20)), // Recents
                const Tab(icon: Icon(Icons.star_border, size: 20)), // Favorites
                ..._packs.map((p) => Tab(
                   child: CachedNetworkImage(
                     imageUrl: p.trayImageFile,
                     width: 24, height: 24,
                     errorWidget: (_,__,___) => const Icon(Icons.broken_image, size: 20),
                   )
                )),
              ],
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 1. Recents
                _buildStickerGrid(_stickerService.getRecents(), emptyMsg: "No recent stickers"),
                
                // 2. Favorites
                _buildStickerGrid(_stickerService.getFavorites(), emptyMsg: "No favorite stickers"),
                
                // 3. Packs
                ..._packs.map((p) => _buildStickerGrid(p.stickers)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickerGrid(List<Sticker> stickers, {String? emptyMsg}) {
    if (stickers.isEmpty && emptyMsg != null) {
      return Center(child: Text(emptyMsg, style: const TextStyle(color: Colors.grey)));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: stickers.length,
      itemBuilder: (context, index) {
        final sticker = stickers[index];
        return GestureDetector(
          onTap: () {
            _stickerService.addToRecents(sticker);
            widget.onStickerSelected(sticker);
          },
          onLongPress: () {
            _stickerService.toggleFavorite(sticker);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(_stickerService.isFavorite(sticker) ? "Added to Favorites" : "Removed from Favorites"),
              duration: const Duration(milliseconds: 500),
            ));
          },
          child: Stack(
            children: [
              CachedNetworkImage(
                imageUrl: sticker.imageUrl,
                fit: BoxFit.contain,
                placeholder: (_, __) => Container(color: Colors.black12), // Shimmer placeholder if needed
              ),
              if (_stickerService.isFavorite(sticker))
                 const Positioned(
                   right: 0, bottom: 0,
                   child: Icon(Icons.star, size: 12, color: Colors.orange)
                 )
            ],
          ),
        );
      },
    );
  }
}
