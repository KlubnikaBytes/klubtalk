import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:whatsapp_clone/models/sticker_model.dart';
import 'package:whatsapp_clone/services/sticker_service.dart';

class StickerPickerWidget extends StatefulWidget {
  final Function(Sticker) onStickerSelected;

  const StickerPickerWidget({super.key, required this.onStickerSelected});

  @override
  State<StickerPickerWidget> createState() => _StickerPickerWidgetState();
}

class _StickerPickerWidgetState extends State<StickerPickerWidget> with SingleTickerProviderStateMixin {
  final StickerService _stickerService = StickerService();
  late TabController _tabController;
  List<StickerPack> _packs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPacks();
  }

  Future<void> _loadPacks() async {
    final packs = await _stickerService.getPacks();
    _stickerService.initialize().then((_) => setState(() {})); // Reload recents/favs
    if (mounted) {
      setState(() {
        _packs = packs;
        _isLoading = false;
        // Tabs: Recents + Favorites + Each Pack
        _tabController = TabController(length: 2 + _packs.length, vsync: this);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 250,
        child: Center(child: CircularProgressIndicator(color: Color(0xFF9575CD))),
      );
    }

    return Column(
      children: [
        // TAB BAR (Packs icons)
        // WhatsApp puts this at bottom usually, but top is fine too. Let's stick to standard TabBar for now at top or bottom?
        // Cloning standard behavior often implies bottom navigation for picker categories. 
        // Let's put TabBar at the TOP of the picker panel for clarity.
        Container(
          color: const Color(0xFFF0F2F5),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: const Color(0xFF9575CD),
            labelColor: const Color(0xFF9575CD),
            unselectedLabelColor: Colors.grey,
            tabs: [
              const Tab(icon: Icon(Icons.access_time)), // Recents
              const Tab(icon: Icon(Icons.star)),         // Favorites
              ..._packs.map((pack) {
                 return Tab(
                   icon: SizedBox(
                     width: 30, height: 30,
                     child: CachedNetworkImage(imageUrl: pack.trayImageFile),
                   )
                 );
              }),
            ],
          ),
        ),

        // GRID VIEW
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Recents
              _buildStickerGrid(_stickerService.getRecents(), emptyMsg: 'No recent stickers'),
              
              // Favorites
              _buildStickerGrid(_stickerService.getFavorites(), emptyMsg: 'No favorite stickers'),

              // Packs
              ..._packs.map((pack) => _buildStickerGrid(pack.stickers))
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStickerGrid(List<Sticker> stickers, {String emptyMsg = ''}) {
    if (stickers.isEmpty) {
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
             widget.onStickerSelected(sticker);
             _stickerService.addToRecents(sticker);
          },
          onLongPress: () {
             _stickerService.toggleFavorite(sticker);
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(
               content: Text(_stickerService.isFavorite(sticker) ? 'Removed from favorites' : 'Added to favorites'),
               duration: const Duration(milliseconds: 500),
             ));
             setState(() {}); // Refresh UI for favs
          },
          child: CachedNetworkImage(
            imageUrl: sticker.imageUrl,
            placeholder: (c, u) => Container(color: Colors.grey[200]),
          ),
        );
      },
    );
  }
}
