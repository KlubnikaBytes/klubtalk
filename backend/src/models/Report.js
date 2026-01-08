const mongoose = require('mongoose');

const reportSchema = new mongoose.Schema({
    reporterId: { type: String, required: true, ref: 'User' },
    reportedUserId: { type: String, ref: 'User' },
    chatId: { type: String, ref: 'Chat' },
    reason: { type: String, default: '' },
    timestamp: { type: Date, default: Date.now },
});

module.exports = mongoose.model('Report', reportSchema);
