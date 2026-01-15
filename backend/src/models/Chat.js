const mongoose = require('mongoose');

const chatSchema = new mongoose.Schema({
    isGroup: { type: Boolean, default: false },
    participants: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],

    // Group Fields
    groupName: { type: String },
    groupAdmin: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    groupAvatar: { type: String },

    // Valid for both (used for list sorting)
    lastMessage: { type: mongoose.Schema.Types.ObjectId, ref: 'Message' },
    updatedAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('Chat', chatSchema);
