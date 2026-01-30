const mongoose = require('mongoose');

const chatSchema = new mongoose.Schema({
    isGroup: { type: Boolean, default: false },
    participants: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],

    // Group Fields
    groupName: { type: String },
    groupAdmin: { type: mongoose.Schema.Types.ObjectId, ref: 'User' }, // Keep for backward compatibility
    groupAvatar: { type: String },

    // Extended Group Fields
    groupAdmins: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }], // Multiple admins
    groupDescription: { type: String, default: '' },

    // Unread Counts: Map of UserId -> Count
    unreadCounts: {
        type: Map,
        of: Number,
        default: {}
    },

    // Permission Controls
    editInfoPermission: {
        type: String,
        enum: ['all', 'admins'],
        default: 'all'
    },
    sendMessagePermission: {
        type: String,
        enum: ['all', 'admins'],
        default: 'all'
    },
    addParticipantsPermission: {
        type: String,
        enum: ['all', 'admins'],
        default: 'all'
    },

    // Valid for both (used for list sorting)
    lastMessage: { type: mongoose.Schema.Types.ObjectId, ref: 'Message' },
    updatedAt: { type: Date, default: Date.now },
    createdAt: { type: Date, default: Date.now },
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' }
});

// Pre-save hook to maintain backward compatibility
// Pre-save hook to maintain backward compatibility
chatSchema.pre('save', async function () {
    if (this.isGroup && this.groupAdmins && this.groupAdmins.length > 0) {
        // Sync first admin to groupAdmin field
        this.groupAdmin = this.groupAdmins[0];
    }
});

module.exports = mongoose.model('Chat', chatSchema);
