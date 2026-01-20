const mongoose = require('mongoose');

const callLogSchema = new mongoose.Schema({
    callerId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true
    },
    receiverId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true
    },
    callType: {
        type: String,
        enum: ['voice', 'video'],
        required: true
    },
    callDirection: {
        type: String,
        enum: ['incoming', 'outgoing', 'missed'],
        // Note: This might be relative to the user fetching it, but for storage we might store "status" and derive direction or store separate logs?
        // The prompt asks for: callDirection: "incoming" | "outgoing" | "missed"
        // But usually a single record has one caller and one receiver.
        // If we store one record per call, 'direction' depends on who is asking.
        // Let's stick to the prompt's schema but maybe "status" is enough?
        // Prompt schema:
        // {
        //   callerId: ObjectId,
        //   receiverId: ObjectId,
        //   callType: "voice" | "video",
        //   callDirection: "incoming" | "outgoing" | "missed", // <--- This is ambiguous for a single record.
        //   status: "completed" | "missed" | "rejected",
        //   duration: Number, 
        //   startedAt: Date,
        //   endedAt: Date
        // }
        // I will treat 'callDirection' as optional or relevant if we duplicate logs per user. 
        // However, for a single shared log, we just need caller/receiver. 
        // But wait, the prompt schema has `callDirection`. 
        // If I save it as "outgoing" from caller side, it is "incoming" for receiver.
        // Maybe the prompt implies saving TWO records? Or just derivation?
        // I'll stick to deriving direction in the Controller when fetching history.
        // I will OMIT `callDirection` from the schema if it's derived, OR if the user meant specific user-side logging.
        // The `saveCall` API body does NOT have `callDirection`. 
        // So I will NOT store `callDirection` in the DB unless necessary. 
        // I will store `status` and `callerId`/`receiverId`.
    },
    status: {
        type: String,
        enum: ['completed', 'missed', 'rejected'],
        required: true
    },
    duration: {
        type: Number,
        default: 0
    },
    startedAt: {
        type: Date,
        default: Date.now
    },
    endedAt: {
        type: Date
    }
}, { timestamps: true });

module.exports = mongoose.model('CallLog', callLogSchema);
