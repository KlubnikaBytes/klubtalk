const mongoose = require('mongoose');

const chatSchema = new mongoose.Schema({
    // UNIVERSAL ID SUPPORT:
    // We strictly use String for _id to support:
    // 1. Legacy IDs ('uid1_uid2')
    // 2. Group IDs (Timestamp strings)
    // 3. New IDs (ObjectIds converted to String)
    _id: {
        type: String,
        default: () => new mongoose.Types.ObjectId().toString()
    },
    participants: [{ type: String, ref: 'User' }], // All members
    // Group Specific Fields
    isGroup: { type: Boolean, default: false },
    groupName: { type: String }, // 'name' in prompt
    groupPhoto: { type: String, default: '' }, // 'icon' in prompt
    admins: [{ type: String, ref: 'User' }],
    createdBy: { type: String, ref: 'User' },

    // Metadata per user (Map of userId -> value)
    unreadCount: { type: Map, of: Number, default: {} },
    isFavorite: { type: Map, of: Boolean, default: {} },
    isArchived: { type: Map, of: Boolean, default: {} },
    muteUntil: { type: Map, of: mongoose.Schema.Types.Mixed, default: {} }, // date or 'permanent'
    wallpaper: { type: Map, of: String, default: {} },
    disappearingTimer: { type: Number, default: 0 }, // 0=off, 86400=24h, 604800=7d, 7776000=90d

    lastMessage: { type: mongoose.Schema.Types.Mixed, default: {} },
    // Legacy support: If lastMessage is string, accessors might fail.
    // We will fix it on write (sendMessage). 
    // Ideally we would migrate, but Mixed prevents crash on load.
    lastMessageTime: { type: Date, default: Date.now }, // Kept for sorting efficiency
    createdAt: { type: Date, default: Date.now },
}, { minimize: false }); // minimize: false ensures empty objects (unreadCount) are saved

// Virtual or Helper to ensure maps are initialized
// Virtual or Helper to ensure maps are initialized
// REMOVED: pre('save') hook was causing 'next is not a function' errors.
// The schema defaults { type: Map, default: {} } handle this automatically.
// chatSchema.pre('save', function (next) { ... });

module.exports = mongoose.model('Chat', chatSchema);
