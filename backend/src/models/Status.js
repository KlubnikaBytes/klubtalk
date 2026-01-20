const mongoose = require('mongoose');

const statusSchema = new mongoose.Schema({
    userId: { type: String, ref: 'User', required: true },
    type: {
        type: String,
        enum: ['text', 'image', 'video'],
        required: true
    },
    content: { type: String, required: true }, // Text content or Media URL
    caption: { type: String },
    backgroundColor: { type: String }, // Hex color for text status
    viewers: [{
        userId: { type: String, ref: 'User' },
        viewedAt: { type: Date, default: Date.now }
    }],
    privacy: { type: String, enum: ['contacts', 'exclude', 'only'], default: 'contacts' },
    allowedUsers: [{ type: String, ref: 'User' }], // For 'only'
    excludedUsers: [{ type: String, ref: 'User' }], // For 'exclude'
    createdAt: { type: Date, default: Date.now, expires: 86400 } // Auto-delete after 24h
});

module.exports = mongoose.model('Status', statusSchema);
