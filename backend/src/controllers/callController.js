const Call = require('../models/Call');
const User = require('../models/User'); // In case we need it, or for populate if ids are ObjectIds

exports.saveCall = async (req, res) => {
    try {
        console.log("📞 [API] saveCall request received:", JSON.stringify(req.body));
        const { from, to, type, status, duration, callTime } = req.body;

        // validation
        if (!from || !to) {
            console.warn("⚠️ [API] saveCall missing from/to:", { from, to });
            return res.status(400).json({ error: 'Missing from/to user IDs' });
        }

        const User = require('../models/User'); // Ensure User model is loaded

        // Fix: resolve users to get phone numbers
        const caller = await User.findById(from);
        const receiver = await User.findById(to);

        if (!caller || !receiver) {
            console.warn("⚠️ [API] saveCall user not found:", { from, to });
            return res.status(404).json({ error: 'User not found' });
        }

        // Check Block Status
        const { isBlocked } = require('../utils/blockUtil');
        /* 
           Temporarily logging block check but NOT blocking saving of log to see if this is the issue.
           WhatsApp usually shows call logs even if blocked (as blocked call)? Or maybe not.
           Actually, if I am blocked by them, I might not see it?
           Let's just log for now.
        */
        const blocked = await isBlocked(from, to);
        console.log(`🔍 [API] Block status check: ${blocked} (from: ${from}, to: ${to})`);

        if (blocked) {
            console.warn("🚫 [API] Call blocked, but proceeding to save log for debug purposes (or should we return?)");
            // return res.status(403).json({ error: 'Call blocked' }); 
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
        console.log(`✅ [API] Call saved successfully: ${newCall._id}`);
        res.status(201).json({ message: 'Call saved successfully', call: newCall });
    } catch (error) {
        console.error('❌ [API] Error saving call:', error);
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
        // AND exclude calls where the other party is blocked/blocking

        const User = require('../models/User'); // Ensure User model is loaded
        const me = await User.findById(userId).select('blockedUsers blockedByUsers');
        const excludeSet = new Set([
            ...(me.blockedUsers || []),
            ...(me.blockedByUsers || [])
        ].map(id => id.toString()));

        // We can't easily filter efficiently in Mongo unless we use aggregation or multiple queries if exclude list is huge.
        // But for typical user, list is small. We can use $nin in the query.

        const calls = await Call.find({
            $or: [{ from: userId }, { to: userId }],
            $and: [
                { from: { $nin: Array.from(excludeSet) } },
                { to: { $nin: Array.from(excludeSet) } }
            ]
        })
            .populate('from', 'name avatar phone')
            .populate('to', 'name avatar phone')
            .sort({ callTime: -1 });

        res.status(200).json(calls);
    } catch (error) {
        console.error('Error fetching call history:', error);
        res.status(500).json({ error: 'Failed to fetch call history' });
    }
};

exports.getCallById = async (req, res) => {
    try {
        const { callId } = req.params;
        const call = await Call.findById(callId).populate('from', 'name avatar phone').populate('to', 'name avatar phone');
        if (!call) return res.status(404).json({ error: 'Call not found' });
        res.json(call);
    } catch (error) {
        console.error('Error fetching call:', error);
        res.status(500).json({ error: 'Internal Server Error' });
    }
};

exports.rejectCall = async (req, res) => {
    try {
        const { to } = req.body;
        const from = req.user.uid; // From authMiddleware

        if (!to) {
            return res.status(400).json({ error: 'Missing "to" user ID' });
        }

        console.log(`\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`);
        console.log(`🔻 [API] Call Rejected via HTTP`);
        console.log(`   From: ${from}`);
        console.log(`   To: ${to}`);

        // Get Socket.IO instance
        const io = require('../socket').getIO();

        // Emit rejection to the Caller (target)
        io.to(to).emit('video_call_reject', {
            from: from
        });

        console.log(`   ✅ Socket event emitted via HTTP Handler`);

        // 🚀 FAILSAFE: Send FCM Notification (in case Caller is background/offline)
        try {
            const { sendCallRejectNotification } = require('../utils/notification_helper');
            await sendCallRejectNotification(to);
            console.log(`   ✅ FCM Reject Notification sent`);
        } catch (fcmError) {
            console.error(`   ❌ FCM Reject Error:`, fcmError);
        }

        console.log(`━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n`);

        res.status(200).json({ message: 'Call rejected' });
    } catch (error) {
        console.error("❌ [API] Reject Call Error:", error);
        res.status(500).json({ error: 'Failed to reject call' });
    }
};
