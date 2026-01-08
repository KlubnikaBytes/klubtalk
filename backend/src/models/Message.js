const mongoose = require('mongoose');

const messageSchema = new mongoose.Schema({
    chatId: { type: String, ref: 'Chat', required: true },
    senderId: { type: String, ref: 'User', required: true },
    type: {
        type: String,
        enum: ['text', 'image', 'voice', 'video', 'file'],
        default: 'text'
    },
    content: { type: String, required: true }, // Text or File Path
    status: {
        type: String,
        enum: ['sent', 'delivered', 'read'],
        default: 'sent'
    },
    timestamp: { type: Date, default: Date.now },
    duration: { type: Number }, // Extra for voice
    expiresAt: { type: Date, index: true }, // Auto-delete time
});

module.exports = mongoose.model('Message', messageSchema);
