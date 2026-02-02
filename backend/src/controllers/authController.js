const Otp = require('../models/Otp');
const User = require('../models/User');
const jwt = require('jsonwebtoken');
const axios = require('axios');

const SMS_API_KEY = process.env.TWO_FACTOR_API_KEY;
const JWT_SECRET = process.env.JWT_SECRET || 'fallback_secret_do_not_use_in_prod';

// Helper: Generate 6-digit OTP
const generateOTP = () => Math.floor(100000 + Math.random() * 900000).toString();

exports.sendOtp = async (req, res) => {
    try {
        const { phone } = req.body;
        if (!phone) return res.status(400).json({ message: 'Phone number is required' });

        // Generate OTP
        const otp = generateOTP();

        // Save to DB (upsert-like behavior not needed per se, but good to clean old ones if any? 
        // We'll just create a new doc, TTL handles cleanup)
        // Better: delete existing OTPs for this phone first to avoid duplicates
        await Otp.deleteMany({ phone });

        await Otp.create({ phone, otp });

        // Send via 2Factor API
        // Send via MSG91 (DLT Compliant)
        const sendOtpSms = require('../utils/sendOtpSms');
        await sendOtpSms(phone, otp);

        res.json({ message: 'OTP sent successfully' });
    } catch (error) {
        console.error('Send OTP Error:', error);
        res.status(500).json({ message: 'Failed to send OTP' });
    }
};

exports.verifyOtp = async (req, res) => {
    try {
        const { phone, otp } = req.body;
        console.log(`DEBUG: verifyOtp called with phone: '${phone}', otp: '${otp}'`);

        if (!phone || !otp) return res.status(400).json({ message: 'Phone and OTP are required' });

        // Check DB
        const validOtp = await Otp.findOne({ phone, otp });
        console.log(`DEBUG: DB Find result:`, validOtp);

        if (!validOtp) {
            // Debug: check if ANY otp exists for this phone
            const anyOtp = await Otp.find({ phone });
            console.log(`DEBUG: Any OTPs for this phone?`, anyOtp);
            return res.status(400).json({ message: 'Invalid or expired OTP' });
        }

        // OTP Valid!
        // 1. Delete OTP used
        await Otp.deleteMany({ phone });

        // 2. Find or Create User
        // Note: Our User model might default some fields.
        let user = await User.findOne({ phone });
        let isNewUser = false;

        if (!user) {
            isNewUser = true;
            user = new User({
                phone,
                name: '', // Empty name triggers profile setup on frontend
                about: 'Hey there! I am using WhatsApp.',
                isRegistered: true,
                // firebaseUid: 'optional_or_removed' 
            });
            await user.save();
        }

        // 3. Generate JWT
        const token = jwt.sign({ uid: user._id.toString(), phone: user.phone }, JWT_SECRET, {
            expiresIn: '7d'
        });

        res.json({
            token,
            user: {
                _id: user._id,
                name: user.name,
                phone: user.phone,
                avatar: user.avatar,
                about: user.about
            },
            isNewUser
        });

    } catch (error) {
        console.error('Verify OTP Error:', error);
        res.status(500).json({ message: 'Verification failed' });
    }
};

exports.getMe = async (req, res) => {
    try {
        const user = await User.findById(req.uid);
        if (!user) return res.status(404).json({ message: 'User not found' });
        res.json(user);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
};

// --- User Helpers (Ported from old controller to maintain functionality) ---
exports.getAllUsers = async (req, res) => {
    try {
        const { isBlocked } = require('../utils/blockUtil'); // Lazy load if needed or top
        // But better to pull blocked lists and filter in query OR memory
        const currentUser = await User.findById(req.uid).select('blockedUsers blockedByUsers');

        const excludeIds = [
            req.uid,
            ...(currentUser.blockedUsers || []),
            ...(currentUser.blockedByUsers || [])
        ];

        // Return all registered users except self and blocked
        const users = await User.find({
            _id: { $nin: excludeIds },
            isRegistered: true
        }).select('name phone avatar about');

        res.json(users);
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
};

exports.updateProfile = async (req, res) => {
    try {
        const { name, about, avatar, isOnline } = req.body;

        // Construct strict update object to prevent overwriting critical fields like blockedUsers
        const updates = {};
        if (name !== undefined) updates.name = name;
        if (about !== undefined) updates.about = about;
        if (avatar !== undefined) updates.avatar = avatar;
        if (isOnline !== undefined) updates.isOnline = isOnline;

        // Automatically update lastSeen if online status changes? 
        // Or client sends it. Let's allow specific internal updates if needed, but for now strict whitelist.

        const updatedUser = await User.findByIdAndUpdate(req.uid, updates, { new: true }).select('-password');

        if (!updatedUser) return res.status(404).json({ message: 'User not found' });

        res.json(updatedUser);
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
};

// Get User by ID (Public Profile)
exports.getUserById = async (req, res) => {
    try {
        const { id } = req.params;
        // Search by _id (ObjectId) OR firebaseUid (String)
        const mongoose = require('mongoose');
        const query = mongoose.Types.ObjectId.isValid(id) ? { _id: id } : { firebaseUid: id };

        const user = await User.findOne(query).select('name phone about avatar lastSeen isOnline');

        if (!user) return res.status(404).json({ message: 'User not found' });

        res.json(user);
    } catch (e) {
        res.status(500).json({ message: e.message });
    }
};

// Update FCM Token for Push Notifications
exports.updateFcmToken = async (req, res) => {
    try {
        const { fcmToken } = req.body;

        if (!fcmToken) {
            return res.status(400).json({ message: 'FCM token is required' });
        }

        await User.findByIdAndUpdate(req.uid, { fcmToken });
        console.log(`FCM token updated for user ${req.uid}`);

        res.json({ success: true, message: 'FCM token updated' });
    } catch (error) {
        console.error('Update FCM token error:', error);
        res.status(500).json({ message: 'Failed to update FCM token' });
    }
};

