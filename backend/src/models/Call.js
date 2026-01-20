const mongoose = require('mongoose');

const callSchema = new mongoose.Schema({
    from: { type: String, ref: 'User', required: true },
    to: { type: String, ref: 'User', required: true },
    callerPhone: { type: String, required: true },
    receiverPhone: { type: String, required: true },
    type: { type: String, enum: ['voice', 'video'], required: true },
    status: { type: String, enum: ['missed', 'completed', 'rejected', 'busy'], default: 'missed' },
    callTime: { type: Date, required: true },
    startedAt: { type: Date, default: Date.now },
    endedAt: { type: Date },
    duration: { type: Number, default: 0 }, // in seconds
});

module.exports = mongoose.model('Call', callSchema);
