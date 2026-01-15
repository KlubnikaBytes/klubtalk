const mongoose = require('mongoose');

const messageSchema = new mongoose.Schema({
    chatId: { type: mongoose.Schema.Types.ObjectId, ref: 'Chat', required: true },
    senderId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    content: { type: String, default: '' },
    type: {
        type: String,
        enum: ['text', 'image', 'video', 'audio', 'file', 'sticker'],
        default: 'text'
    },
    mediaUrl: { type: String },
    thumbnailUrl: { type: String },
    status: {
        type: String,
        enum: ['sent', 'delivered', 'seen'],
        default: 'sent'
    },
    createdAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('Message', messageSchema);
