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
        // Template: https://2factor.in/API/V1/{API_KEY}/SMS/{PHONE_NUMBER}/{OTP}
        const url = `https://2factor.in/API/V1/${SMS_API_KEY}/SMS/${phone}/${otp}`;

        // We don't await this to block? better to await to ensure it didn't fail
        await axios.get(url);

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
                name: 'User ' + phone.slice(-4), // Default name
                about: 'Hey there! I am using Messaging App.',
                isRegistered: true
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
        // Return all registered users except self
        const users = await User.find({ _id: { $ne: req.uid }, isRegistered: true }).select('name phone avatar about');
        res.json(users);
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
};

exports.updateProfile = async (req, res) => {
    try {
        const updates = req.body;
        const user = await User.findByIdAndUpdate(req.uid, updates, { new: true });
        res.json(user);
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
};
