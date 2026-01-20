const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
    firebaseUid: { type: String, unique: true, sparse: true }, // Optional now
    phone: { type: String, required: true, unique: true },
    name: { type: String, default: '' },
    about: { type: String, default: 'Hey there! I am using WhatsApp.' },
    avatar: { type: String, default: '' }, // URL/Path on VPS
    lastSeen: { type: Date, default: Date.now },
    isOnline: { type: Boolean, default: false },
    createdAt: { type: Date, default: Date.now },
    blockedUsers: [String], // Array of firebaseUids
    archivedChats: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Chat' }], // Personal Archive
});

userSchema.index({ name: 'text', phone: 'text' });

module.exports = mongoose.model('User', userSchema);
