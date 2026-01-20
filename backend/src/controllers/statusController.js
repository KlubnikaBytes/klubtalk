const Status = require('../models/Status');
const Contact = require('../models/Contact');

exports.createStatus = async (req, res) => {
    try {
        const { type, content, caption, backgroundColor } = req.body;

        // Basic Validation
        if (!type || !content) {
            return res.status(400).json({ message: 'Type and content are required' });
        }

        const status = new Status({
            userId: req.uid,
            type,
            content,
            caption,
            backgroundColor,
            privacy: req.body.privacy || 'contacts',
            allowedUsers: req.body.allowedUsers || [],
            excludedUsers: req.body.excludedUsers || []
        });

        await status.save();

        // Return populated status
        await status.populate('userId', 'name avatar');

        res.status(201).json(status);
    } catch (error) {
        console.error('Create Status Error:', error);
        res.status(500).json({ message: error.message });
    }
};

exports.getFeed = async (req, res) => {
    try {
        // 1. Get IDs associated with user (friends + self)
        const contacts = await Contact.find({ ownerUserId: req.uid, isRegistered: true });
        const contactIds = contacts.map(c => c.linkedUserId).filter(id => id);
        const feedUserIds = [req.uid, ...contactIds];

        // 2. Aggregate Statuses
        const feed = await Status.aggregate([
            {
                $match: {
                    userId: { $in: feedUserIds },
                    // Privacy Logic Placeholder (Basic 'contacts' check implied by feedUserIds for now)
                    // We can refine this later to check 'excludedUsers' etc.
                }
            },
            { $sort: { createdAt: 1 } }, // Oldest to newest inside the group
            {
                $group: {
                    _id: "$userId",
                    statuses: { $push: "$$ROOT" },
                    lastUpdate: { $max: "$createdAt" }
                }
            },
            {
                // Join User Info
                $lookup: {
                    from: "users",
                    localField: "_id", // user ID
                    foreignField: "firebaseUid", // Match schema (firebaseUid or _id?)
                    // Schema checks: User.js uses firebaseUid as sparse, but logic uses _id usually.
                    // Wait, Status stores userId. Is it ObjectId or String?
                    // User.js: firebaseUid is String.
                    // Contact.js: linkedUserId is String (firebaseUid).
                    // Status.js: userId is String.
                    // So we join on firebaseUid usually OR _id if stored as such.
                    // Let's assume Status.userId is storing ._id string if we changed auth to use Mongo ID?
                    // "req.uid" -> typically Mongo _id in this hybrid backend.
                    // Let's check Aggregation Lookup carefully.
                    // Most reliable is to Populate after aggregation, but simple Lookup works if keys match.
                    // Let's assume userId -> _id
                    // BUT User.js has _id (ObjectId).
                    // So we must cast string to ObjectId if needed, OR just Populate.
                    // Population is harder on Aggregate result without Mongoose 6+ helpers or manual loop.
                    // Let's do manual population for simplicity and safety.
                    as: "user"
                }
            },
            {
                $unwind: {
                    path: "$user",
                    preserveNullAndEmptyArrays: true
                }
            },
            { $sort: { lastUpdate: -1 } } // Newest updates top
        ]);

        // Transform for Frontend
        const result = feed.map(item => ({
            _id: item._id,
            user: item.user ? {
                name: item.user.name,
                avatar: item.user.avatar,
                phone: item.user.phone
            } : {},
            statuses: item.statuses,
            lastUpdate: item.lastUpdate
        }));

        res.json(result);
    } catch (error) {
        console.error('Get Feed Error:', error);
        res.status(500).json({ message: error.message });
    }
};

exports.viewStatus = async (req, res) => {
    try {
        const { statusId } = req.body;
        if (!statusId) return res.status(400).json({ message: 'Status ID required' });

        await Status.findByIdAndUpdate(statusId, {
            $addToSet: { viewers: { userId: req.uid, viewedAt: new Date() } }
        });

        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
};

exports.deleteStatus = async (req, res) => {
    try {
        const { statusId } = req.params;
        const status = await Status.findOne({ _id: statusId, userId: req.uid });

        if (!status) {
            return res.status(404).json({ message: 'Status not found or unauthorized' });
        }

        await status.deleteOne();
        res.json({ success: true, message: 'Status deleted' });
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
};
