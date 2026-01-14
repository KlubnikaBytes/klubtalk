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
            backgroundColor
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
        // 1. Get IDs of people I know (contacts + self)
        const contacts = await Contact.find({ ownerUserId: req.uid, isRegistered: true });
        const contactIds = contacts.map(c => c.linkedUserId).filter(id => id); // Filter nulls

        // Include self to see my own status
        const feedUserIds = [req.uid, ...contactIds];

        // 2. Fetch Statuses
        const statuses = await Status.find({
            userId: { $in: feedUserIds }
        })
            .populate('userId', 'name avatar')
            .sort({ createdAt: -1 }); // Newest first

        res.json(statuses);
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
