const User = require('../models/User');

// Auth Handshake: Verify Token & Get/Create User
const login = async (req, res) => {
    try {
        // req.user is populated by verifyToken middleware (from Firebase Admin)
        const { uid, phone_number } = req.user;

        if (!uid || !phone_number) {
            return res.status(400).json({ error: 'Invalid token payload' });
        }

        // Find or Create User
        // We match by firebaseUid
        let user = await User.findOne({ firebaseUid: uid });

        if (!user) {
            user = new User({
                firebaseUid: uid,
                phone: phone_number,
                createdAt: new Date()
            });
            await user.save();
        }

        return res.status(200).json({
            message: 'Auth successful',
            user: user
        });

    } catch (error) {
        console.error('Auth Error:', error);
        return res.status(500).json({ error: 'Authentication failed' });
    }
};

const getProfile = async (req, res) => {
    try {
        const { uid } = req.user;
        const user = await User.findOne({ firebaseUid: uid });

        if (!user) return res.status(404).json({ error: 'User not found' });

        return res.status(200).json(user);
    } catch (error) {
        console.error('Get Profile Error:', error);
        return res.status(500).json({ error: 'Failed to fetch profile' });
    }
};

const updateProfile = async (req, res) => {
    try {
        const { uid } = req.user;
        const { name, about, isOnline } = req.body;

        const updateData = {};
        if (name !== undefined) updateData.name = name;
        if (about !== undefined) updateData.about = about;
        if (isOnline !== undefined) updateData.isOnline = isOnline;

        const user = await User.findOneAndUpdate(
            { firebaseUid: uid },
            { $set: updateData },
            { new: true }
        );

        return res.status(200).json(user);
    } catch (error) {
        return res.status(500).json({ error: 'Failed to update profile' });
    }
};

const getAllUsers = async (req, res) => {
    try {
        const users = await User.find({});
        return res.status(200).json(users);
    } catch (error) {
        return res.status(500).json({ error: 'Failed to fetch users' });
    }
};

module.exports = {
    login,
    getProfile,
    updateProfile,
    getAllUsers
};
