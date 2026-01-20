const CallLog = require('../models/CallLog');
const User = require('../models/User');

exports.saveCall = async (req, res) => {
    try {
        const { callerId, receiverId, callType, status, duration } = req.body;

        const newCall = new CallLog({
            callerId,
            receiverId,
            callType,
            status,
            duration,
            startedAt: new Date(),
            endedAt: new Date(Date.now() + (duration * 1000))
        });

        const savedCall = await newCall.save();
        res.status(201).json(savedCall);
    } catch (error) {
        console.error("Error saving call log:", error);
        res.status(500).json({ message: "Failed to save call log" });
    }
};

exports.getCallHistory = async (req, res) => {
    try {
        const { userId } = req.params;

        // Fetch calls where user is caller OR receiver
        const calls = await CallLog.find({
            $or: [{ callerId: userId }, { receiverId: userId }]
        })
            .populate('callerId', 'name avatar')
            .populate('receiverId', 'name avatar')
            .sort({ startedAt: -1 });

        // Transform for UI to include Direction
        const history = calls.map(call => {
            const isCaller = call.callerId._id.toString() === userId;

            let direction = 'outgoing';
            if (!isCaller) {
                if (call.status === 'missed') direction = 'missed';
                else direction = 'incoming';
            } else {
                if (call.status === 'missed') direction = 'missed'; // Outgoing missed doesn't make sense usually, but implies no answer
            }

            // If status is 'missed', it overrides direction in some UIs (Red arrow).
            // But we can enable the UI to decide.
            // Let's return the raw data mostly, but add a 'peer' field for convenience.

            return {
                _id: call._id,
                callerId: call.callerId, // Populated
                receiverId: call.receiverId, // Populated
                callType: call.callType,
                status: call.status,
                duration: call.duration,
                startedAt: call.startedAt,
                direction: isCaller ? 'outgoing' : 'incoming',
                peer: isCaller ? call.receiverId : call.callerId // The other person
            };
        });

        res.status(200).json(history);
    } catch (error) {
        console.error("Error fetching call history:", error);
        res.status(500).json({ message: "Failed to fetch history" });
    }
};
