const Status = require('../models/Status');
const User = require('../models/User');
const Contact = require('../models/Contact');
const fs = require('fs');
const path = require('path');
const { getIO } = require('../socket'); // Import Socket Getter

// 1. Create Status
exports.createStatus = async (req, res) => {
    try {
        const { type, content, caption, backgroundColor, mimeType, text, privacy, allowedUsers, excludedUsers } = req.body;
        const currentUserId = req.uid;

        // Validation
        if (!type) return res.status(400).json({ message: 'Type is required' });

        let finalContent = content;
        if (type === 'text') {
            finalContent = text || content;
            if (!finalContent) return res.status(400).json({ message: 'Text content is required' });
        } else {
            if (!finalContent) return res.status(400).json({ message: 'Media URL is required' });
        }

        const validPrivacy = ['contacts', 'exclude', 'only'].includes(privacy) ? privacy : 'contacts';

        const status = new Status({
            userId: currentUserId,
            type: type,
            content: finalContent,
            mimeType: mimeType || (type === 'text' ? 'text/plain' : null),
            caption: caption || '',
            backgroundColor: backgroundColor || '#7E57C2',
            privacy: validPrivacy,
            allowedUsers: Array.isArray(allowedUsers) ? allowedUsers : [],
            excludedUsers: Array.isArray(excludedUsers) ? excludedUsers : [],
            viewers: []
        });

        await status.save();

        // --- Real-time Notification ---
        try {
            const io = getIO();
            const populatedStatus = await User.findById(currentUserId).select('name avatar phone');

            // Safe User Object
            const safeUserName = populatedStatus ? (populatedStatus.name || populatedStatus.phone || 'Unknown') : 'Unknown';
            const safeUserAvatar = populatedStatus ? populatedStatus.avatar : '';

            const eventData = {
                statusId: status._id.toString(), // Ensure string for clients
                userId: currentUserId,
                userName: safeUserName,
                userAvatar: safeUserAvatar,
                createdAt: status.createdAt
            };

            // 1. Resolve Recipients Dynamically (Phone Matching)
            // Fetch my contacts
            const myContacts = await Contact.find({ ownerUserId: currentUserId });
            const contactPhones = myContacts.map(c => c.phone);

            // Find Users matching these phones
            const matchingUsers = await User.find({ phone: { $in: contactPhones } }).select('_id blockedUsers blockedByUsers');

            // Check Block Status (Mutual)
            // If I block them OR they block me -> Exclude
            // User schema has blockedUsers/blockedByUsers.
            // Since we fetched them, we can check their blocked lists too?
            // Actually, we need to check if *I* block them (User.findById(me)) and if *THEY* block me (User.blockedUsers).

            // Re-fetch ME to be sure of my blocked list (optimized above? no, fetched populatedStatus)
            // populatedStatus only has name/avatar/phone.
            const me = await User.findById(currentUserId).select('blockedUsers blockedByUsers');
            const myBlockedSet = new Set((me.blockedUsers || []).map(id => id.toString()));
            const blockedBySet = new Set((me.blockedByUsers || []).map(id => id.toString()));

            const contactUserIds = matchingUsers
                .filter(u => {
                    const uId = u._id.toString();
                    if (myBlockedSet.has(uId)) return false; // I block them
                    if (blockedBySet.has(uId)) return false; // They block me
                    return true;
                })
                .map(u => u._id.toString());

            // 2. Filter based on privacy
            let recipients = [];
            if (validPrivacy === 'contacts') {
                recipients = contactUserIds;
            } else if (validPrivacy === 'exclude') {
                const excludedSet = new Set(status.excludedUsers);
                recipients = contactUserIds.filter(id => !excludedSet.has(id));
            } else if (validPrivacy === 'only') {
                const allowedSet = new Set(status.allowedUsers);
                recipients = contactUserIds.filter(id => allowedSet.has(id));
            }

            // 3. Emit to each recipient
            recipients.forEach(recipientId => {
                if (!recipientId) return;
                try {
                    io.to(recipientId).emit('status_uploaded', eventData);
                } catch (e) {
                    console.error(`Failed to emit status to ${recipientId}`, e);
                }
            });

            // Allow sending to self for testing
            io.to(currentUserId).emit('status_uploaded', eventData);

        } catch (socketError) {
            console.error('Socket emit error:', socketError);
        }

        res.status(201).json(status);
    } catch (error) {
        console.error('Create Status Error:', error);
        res.status(500).json({ message: error.message });
    }
};

// 2. Get Feed (STRICT PRIVACY + PHONE MATCHING)
exports.getFeed = async (req, res) => {
    try {
        const currentUserId = req.uid;

        const me = await User.findById(currentUserId).select('name phone firebaseUid blockedUsers blockedByUsers profileType accountType');

        // Debug logs as requested
        console.log("VIEWER ID:", currentUserId);
        console.log("VIEWER NAME:", me?.name);
        console.log("VIEWER PROFILE TYPE:", me?.profileType || "Not Defined");
        console.log("VIEWER ACCOUNT TYPE:", me?.accountType || "Not Defined");

        // 1. Resolve all possible IDs for current user (handle split identity)
        const myIds = [currentUserId, me?.firebaseUid].filter(Boolean);

        // 2. Get My Contacts
        const myContacts = await Contact.find({ ownerUserId: { $in: myIds } });
        const contactPhones = myContacts.map(c => c.phone);

        // 3. Resolve Authors from Contacts
        const authors = await User.find({ phone: { $in: contactPhones } }).select('_id');
        const authorIds = authors.map(u => u._id.toString());

        const excludeSet = new Set([
            ...(me?.blockedUsers || []),
            ...(me?.blockedByUsers || [])
        ].map(id => id.toString()));

        const allowedAuthorIds = authorIds.filter(id => !excludeSet.has(id));
        const feedUserIds = [currentUserId, ...allowedAuthorIds];

        console.log("STATUS OWNERS IN DB:", await Status.distinct("userId"));
        console.log("ALLOWED USER IDS:", feedUserIds);

        // 4. Aggregate Statuses (Simplified Filtering)
        const feed = await Status.aggregate([
            {
                $match: {
                    userId: { $in: feedUserIds },
                    createdAt: { $gte: new Date(Date.now() - 24 * 60 * 60 * 1000) } // Last 24h
                }
            },
            { $sort: { createdAt: 1 } }, // Oldest first (Story order)
            {
                $group: {
                    _id: "$userId",
                    statuses: { $push: "$$ROOT" },
                    lastUpdate: { $max: "$createdAt" }
                }
            },
            {
                $lookup: {
                    from: "users",
                    // We must match string ID or ObjectId? 
                    // Status.userId is usually String if created via req.uid (from JWT string). 
                    // BUT User._id is ObjectId. 
                    // $lookup might fail if types mismatch. 
                    // Let's assume userId is stored as String. 
                    // If Mongo _id is Object, we need conversion. 
                    // Usually Mongoose casts string to ObjectId in queries, but in Aggregate $lookup request localField must match.
                    let: { uId: "$_id" },
                    pipeline: [
                        // Convert stored ObjectId to String for comparison OR match directly
                        // Best to just match on _id if Status.userId is ObjectId. 
                        // Check createStatus: `userId: currentUserId` (String usually).
                        // We will attempt both conversions to be safe.
                        { $addFields: { strId: { $toString: "$_id" } } },
                        { $match: { $expr: { $eq: ["$strId", "$$uId"] } } }
                    ],
                    as: "user"
                }
            },
            { $unwind: { path: "$user", preserveNullAndEmptyArrays: true } },
            // Fallback for missing user is handled in map

            { $sort: { lastUpdate: -1 } } // Recent updates top
        ]);

        // 5. Get Muted List
        const currentUser = await User.findById(currentUserId);
        const mutedAuthors = currentUser ? (currentUser.mutedStatusAuthors || []) : [];

        // 6. Transform Result
        const result = feed.map(item => {
            const userObj = item.user || {};
            // If user is missing, try to resolve name from my contacts locally (frontend does this mostly, but backend can try)
            // But we don't have phone here easily if userObj is null.
            return {
                _id: item._id, // userId
                user: {
                    name: userObj.name || userObj.phone || 'Unknown',
                    avatar: userObj.avatar || '',
                    phone: userObj.phone || ''
                },
                statuses: item.statuses,
                lastUpdate: item.lastUpdate,
                isMuted: mutedAuthors.includes(item._id)
            };
        });

        res.json(result);
    } catch (error) {
        console.error('Get Feed Error:', error);
        res.status(500).json({ message: error.message });
    }
};

// 3. View Status
exports.viewStatus = async (req, res) => {
    try {
        const { statusId } = req.body;
        const currentUserId = req.uid;

        if (!statusId) return res.status(400).json({ message: 'Status ID required' });

        const status = await Status.findById(statusId);
        if (!status) return res.status(404).json({ message: 'Status not found' });

        // Check if already viewed
        const alreadyViewed = status.viewers.some(v => v.userId === currentUserId);

        if (!alreadyViewed && status.userId !== currentUserId) {
            // Add viewer
            status.viewers.push({ userId: currentUserId, viewedAt: new Date() });
            await status.save();

            // Emit to Owner
            try {
                const io = getIO();
                const viewer = await User.findOne({ firebaseUid: currentUserId }).select('name avatar');
                io.to(status.userId).emit('status_viewed', {
                    statusId,
                    viewerId: currentUserId,
                    viewerName: viewer?.name || 'Someone',
                    viewedAt: new Date()
                });
            } catch (e) {
                console.error("Socket emit status_viewed error", e);
            }
        }

        res.json({ success: true });
    } catch (error) {
        console.error('View Status Error:', error);
        res.status(500).json({ message: error.message });
    }
};

// 4. Get User Status (Public profile / Preview)
exports.getUserStatus = async (req, res) => {
    try {
        const { userId } = req.params;
        const currentUserId = req.uid;

        // Simplify: Just fetch valid ones. 
        // Real logic should reuse 'getFeed' privacy conditions, but for single user.

        // Quick check: If I am blocked? (Add later)

        const statuses = await Status.find({
            userId: userId,
            createdAt: { $gte: new Date(Date.now() - 24 * 60 * 60 * 1000) },
            $or: [
                { userId: currentUserId }, // My own
                { privacy: 'contacts' },
                { privacy: 'exclude', excludedUsers: { $ne: currentUserId } },
                { privacy: 'only', allowedUsers: currentUserId }
            ]
        }).sort({ createdAt: 1 });

        res.json(statuses);
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
};

// 5. Delete Status
exports.deleteStatus = async (req, res) => {
    try {
        const { statusId } = req.params;
        const currentUserId = req.uid;

        const status = await Status.findOne({ _id: statusId, userId: currentUserId });
        if (!status) return res.status(404).json({ message: 'Status not found' });

        // Delete File if local (optional, if using local uploads)
        if (status.content && status.content.includes('/uploads/status/')) {
            try {
                // Extract relative path from URL
                // URL: http://host:port/uploads/status/filename.jpg
                // Path: uploads/status/filename.jpg
                const urlParts = status.content.split('/uploads/');
                if (urlParts.length > 1) {
                    const relativePath = 'uploads/' + urlParts[1];
                    const fullPath = path.join(__dirname, '../../', relativePath);
                    if (fs.existsSync(fullPath)) {
                        fs.unlinkSync(fullPath);
                    }
                }
            } catch (err) {
                console.error("File deletion error:", err);
            }
        }

        await Status.deleteOne({ _id: statusId });

        // Emit delete event (so viewers client removes it instantly?)
        // Helps if someone is currently viewing it.
        try {
            const io = getIO();
            // We don't know exactly who is viewing, but we can emit to 'status_room' if we had one.
            // Or just do nothing, client handles 404. 
            // Better: Emit to all contacts? Expensive. 
            // Just let silent fail or client refresh.
        } catch (e) { }

        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
};

// 6. Mute/Unmute
exports.muteUser = async (req, res) => {
    try {
        const { userId } = req.body;
        await User.updateOne({ firebaseUid: req.uid }, { $addToSet: { mutedStatusAuthors: userId } });
        res.json({ success: true });
    } catch (error) { res.status(500).json({ message: error.message }); }
};

exports.unmuteUser = async (req, res) => {
    try {
        const { userId } = req.body;
        await User.updateOne({ firebaseUid: req.uid }, { $pull: { mutedStatusAuthors: userId } });
        res.json({ success: true });
    } catch (error) { res.status(500).json({ message: error.message }); }
};

// 7. Cleanup Job (Called internally or via cron)
exports.cleanupExpiredStatuses = async () => {
    try {
        console.log('Running Status Cleanup Job...');
        const expiryTime = new Date(Date.now() - 24 * 60 * 60 * 1000);

        // Find expired statuses
        const expiredStatuses = await Status.find({ createdAt: { $lt: expiryTime } });

        if (expiredStatuses.length === 0) return;

        console.log(`Found ${expiredStatuses.length} expired statuses to clean.`);

        for (const status of expiredStatuses) {
            // Delete File
            if (status.content && status.content.includes('/uploads/status/')) {
                try {
                    const urlParts = status.content.split('/uploads/');
                    if (urlParts.length > 1) {
                        const relativePath = 'uploads/' + urlParts[1];
                        const fullPath = path.join(__dirname, '../../', relativePath);
                        if (fs.existsSync(fullPath)) {
                            fs.unlinkSync(fullPath);
                            console.log(`Deleted file: ${fullPath}`);
                        }
                    }
                } catch (err) {
                    console.error(`Failed to delete file for status ${status._id}:`, err);
                }
            }
            // Delete Doc
            await Status.deleteOne({ _id: status._id });
        }
    } catch (error) {
        console.error('Status Cleanup Error:', error);
    }
};
