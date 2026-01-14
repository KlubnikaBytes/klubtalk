
const getPacks = (req, res) => {
    // Mock Data mimicking a DB fetch
    // Real implementation would fetch from MongoDB 'StickerPacks' collection
    const packs = [
        {
            id: '1',
            name: 'Cuppy',
            author: 'Minie',
            trayImage: 'https://cdn-icons-png.flaticon.com/512/4712/4712109.png',
            stickers: Array.from({ length: 16 }, (_, i) => ({
                id: `cuppy_${i}`,
                packId: '1',
                url: `https://cdn-icons-png.flaticon.com/512/4712/4712${100 + i}.png`,
                mimeType: 'image/webp'
            }))
        },
        {
            id: '2',
            name: 'Dogs',
            author: 'Doggos',
            trayImage: 'https://cdn-icons-png.flaticon.com/512/616/616408.png',
            stickers: Array.from({ length: 12 }, (_, i) => ({
                id: `dog_${i}`,
                packId: '2',
                url: `https://cdn-icons-png.flaticon.com/512/616/616${400 + i}.png`,
                mimeType: 'image/webp'
            }))
        }
    ];

    res.status(200).json(packs);
};

const getPackDetails = (req, res) => {
    res.status(501).json({ message: "Not implemented, use getPacks for full data" });
};

module.exports = {
    getPacks,
    getPackDetails
};
