const mongoose = require('mongoose');

const contactSchema = new mongoose.Schema({
    ownerUserId: { type: String, required: true, ref: 'User' }, // The user who added this contact
    name: { type: String, required: true },
    phone: { type: String, required: true },

    isRegistered: { type: Boolean, default: false },
    linkedUserId: { type: String, ref: 'User', default: null }, // If isRegistered=true, points to User document

    createdAt: { type: Date, default: Date.now },
});

// Composite index to prevent duplicates for same owner
contactSchema.index({ ownerUserId: 1, phone: 1 }, { unique: true });

module.exports = mongoose.model('Contact', contactSchema);
