const mongoose = require('mongoose');

const blockedUserSchema = new mongoose.Schema({
    blockerId: { type: String, required: true }, // The user who is blocking
    blockedId: { type: String, required: true }, // The user being blocked
    createdAt: { type: Date, default: Date.now }
});

// Index to ensure unique blocking pair and fast lookups
blockedUserSchema.index({ blockerId: 1, blockedId: 1 }, { unique: true });

module.exports = mongoose.model('BlockedUser', blockedUserSchema);
