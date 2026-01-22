const mongoose = require('mongoose');

const statusSchema = new mongoose.Schema({
    userId: { type: String, ref: 'User', required: true, index: true },
    type: {
        type: String,
        enum: ['text', 'image', 'video'],
        required: true
    },
    content: { type: String, required: true }, // URL or Text
    mimeType: { type: String }, // e.g. 'image/jpeg', 'video/mp4'
    caption: { type: String },
    backgroundColor: { type: String }, // Hex color for text status
    font: { type: String, default: 'sans-serif' },
    viewers: [{
        userId: { type: String, ref: 'User' }, // Store FirebaseUID
        viewedAt: { type: Date, default: Date.now },
        _id: false
    }],
    privacy: {
        type: String,
        enum: ['contacts', 'exclude', 'only'],
        default: 'contacts'
    },
    allowedUsers: [{ type: String, ref: 'User' }], // For 'only' - list of FirebaseUIDs
    excludedUsers: [{ type: String, ref: 'User' }], // For 'exclude' - list of FirebaseUIDs
    createdAt: { type: Date, default: Date.now } // Manual cleanup handled by cron
});

// Index for efficient feed queries
statusSchema.index({ userId: 1, createdAt: -1 });

module.exports = mongoose.model('Status', statusSchema);
