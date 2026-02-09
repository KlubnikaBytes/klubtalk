const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
    firebaseUid: { type: String, unique: true, sparse: true }, // Optional now
    phone: { type: String, required: true, unique: true },
    name: { type: String, default: '' },
    about: { type: String, default: 'KlubTalk is kinda fun' },
    avatar: { type: String, default: '' }, // URL/Path on VPS
    lastSeen: { type: Date, default: Date.now },
    isOnline: { type: Boolean, default: false },
    createdAt: { type: Date, default: Date.now },
    fcmToken: { type: String, default: '' }, // Firebase Cloud Messaging token for push notifications
    email: { type: String, default: '' },
    securityNotifications: { type: Boolean, default: false },
    twoFactorPin: { type: String, default: '' }, // Hashed PIN
    blockedUsers: [String], // Array of firebaseUids
    archivedChats: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Chat' }], // Personal Archive
    favoritedChats: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Chat' }], // Personal Favorites
    mutedStatusAuthors: [{ type: String }], // Array of firebaseUids
    // blockedUsers is already defined above, removing duplicate
    blockedByUsers: [{ type: String }], // Array of userIds
});

userSchema.index({ name: 'text', phone: 'text' });

module.exports = mongoose.model('User', userSchema);
