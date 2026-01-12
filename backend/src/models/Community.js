const mongoose = require('mongoose');

const communitySchema = new mongoose.Schema({
    _id: {
        type: String,
        default: () => new mongoose.Types.ObjectId().toString()
    },
    name: { type: String, required: true },
    icon: { type: String, default: '' },
    description: { type: String, default: '' },
    creatorId: { type: String, ref: 'User', required: true },

    // Community Members (Admins can be derived or stored, simpler to store)
    admins: [{ type: String, ref: 'User' }],
    members: [{ type: String, ref: 'User' }], // All participants from all groups

    // The logic: Community -> Groups
    groupIds: [{ type: String, ref: 'Chat' }],

    // The Announcements Group ID
    announcementsGroupId: { type: String, ref: 'Chat' },

    createdAt: { type: Date, default: Date.now },
});

module.exports = mongoose.model('Community', communitySchema);
