const mongoose = require('mongoose');

const callSchema = new mongoose.Schema({
    from: { type: String, ref: 'User', required: true },
    to: { type: String, ref: 'User', required: true },
    callerPhone: { type: String }, // Optional
    receiverPhone: { type: String }, // Optional
    type: { type: String, enum: ['voice', 'video', 'audio'], required: true },
    status: { type: String, enum: ['missed', 'completed', 'rejected', 'busy'], default: 'missed' },
    callTime: { type: Date, required: true },
    startedAt: { type: Date, default: Date.now },
    endedAt: { type: Date },
    duration: { type: Number, default: 0 }, // in seconds
    offer: { type: Object }, // Store WebRTC Offer (SDP) to avoid FCM payload limits
});

module.exports = mongoose.model('Call', callSchema);
