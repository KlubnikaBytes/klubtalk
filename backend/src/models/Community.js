const mongoose = require('mongoose');

const communitySchema = new mongoose.Schema({
    name: { type: String, required: true },
    description: { type: String, default: '' },
    photo: { type: String, default: '' }, // Renamed from icon to photo
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },

    // Admins & Members
    admins: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
    members: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }], // Derived + Stored for efficiency

    // Groups in this community
    groups: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Chat' }],

    // The Announcements Group (Auto-created)
    announcementsGroupId: { type: mongoose.Schema.Types.ObjectId, ref: 'Chat' },

    createdAt: { type: Date, default: Date.now },
});

module.exports = mongoose.model('Community', communitySchema);
