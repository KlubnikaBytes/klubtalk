const Call = require('../models/Call');
const User = require('../models/User'); // In case we need it, or for populate if ids are ObjectIds

exports.saveCall = async (req, res) => {
    try {
        const { from, to, type, status, duration, callTime } = req.body;

        // validation
        if (!from || !to) {
            return res.status(400).json({ error: 'Missing from/to user IDs' });
        }

        // Fix: resolve users to get phone numbers
        const caller = await User.findById(from);
        const receiver = await User.findById(to);

        if (!caller || !receiver) {
            return res.status(404).json({ error: 'User not found' });
        }

        const newCall = new Call({
            from,
            to,
            callerPhone: caller.phone || "Unknown",
            receiverPhone: receiver.phone || "Unknown",
            type, // 'voice' or 'video'
            status,
            duration: duration || 0,
            callTime: callTime ? new Date(callTime) : new Date()
        });

        await newCall.save();
        res.status(201).json({ message: 'Call saved successfully', call: newCall });
    } catch (error) {
        console.error('Error saving call:', error);
        res.status(500).json({ error: 'Failed to save call' });
    }
};

exports.getCallHistory = async (req, res) => {
    try {
        const { userId } = req.params;

        const mongoose = require('mongoose');
        if (!userId || userId === "null" || !mongoose.Types.ObjectId.isValid(userId)) {
            return res.status(400).json({ error: "Invalid userId" });
        }

        // Find calls where the user is either the caller (from) or receiver (to)
        // Sort by startedAt descending (most recent first)
        const calls = await Call.find({
            $or: [{ from: userId }, { to: userId }]
        })
            .populate('from', 'name avatar phone')
            .populate('from', 'name avatar phone')
            .populate('to', 'name avatar phone')
            .sort({ callTime: -1 });

        res.status(200).json(calls);
    } catch (error) {
        console.error('Error fetching call history:', error);
        res.status(500).json({ error: 'Failed to fetch call history' });
    }
};
