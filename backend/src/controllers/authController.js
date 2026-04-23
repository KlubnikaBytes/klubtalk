const Otp = require('../models/Otp');
const User = require('../models/User');
const jwt = require('jsonwebtoken');
const axios = require('axios');
const { admin } = require('../config/firebase');

const SMS_API_KEY = process.env.TWO_FACTOR_API_KEY;
const JWT_SECRET = process.env.JWT_SECRET || 'fallback_secret_do_not_use_in_prod';

// Helper: Generate 6-digit OTP
const generateOTP = () => Math.floor(100000 + Math.random() * 900000).toString();

exports.sendOtp = async (req, res) => {
    try {
        console.log('🔐 [AUTH] sendOtp endpoint hit');
        const { phone } = req.body;
        console.log('   📱 Phone:', phone);

        if (!phone) {
            console.log('   ❌ No phone number provided');
            return res.status(400).json({ message: 'Phone number is required' });
        }

        // Generate OTP
        const otp = generateOTP();
        console.log('   🔢 Generated OTP:', otp);

        // Save to DB (upsert-like behavior not needed per se, but good to clean old ones if any? 
        // We'll just create a new doc, TTL handles cleanup)
        // Better: delete existing OTPs for this phone first to avoid duplicates
        await Otp.deleteMany({ phone });
        console.log('   🗑️  Deleted old OTPs for this phone');

        await Otp.create({ phone, otp });
        console.log('   💾 OTP saved to database');

        // Send via MSG91 (DLT Compliant)
        console.log('   📤 Sending OTP via SMS...');
        const sendOtpSms = require('../utils/sendOtpSms');
        await sendOtpSms(phone, otp);
        console.log('   ✅ OTP SMS sent successfully');

        return res.status(200).json({
            success: true,
            message: "OTP sent successfully",
            provider: "DLT",
            status: "sent"
        });
    } catch (error) {
        console.error('❌ Send OTP Error:', error);
        return res.status(500).json({
            success: false,
            message: error.message
        });
    }
};

exports.verifyOtp = async (req, res) => {
    try {
        console.log("STEP 1: Request received", new Date().toISOString());
        const { phone, otp } = req.body;
        
        console.log("STEP 2: Searching OTP...", phone, otp);
        if (!phone || !otp) return res.status(400).json({ success: false, message: 'Phone and OTP are required' });

        const record = await Otp.findOne({ phone, otp });
        console.log("STEP 3: OTP found:", record ? record._id : "null");

        if (!record) {
            return res.status(400).json({
                success: false,
                message: "Invalid or already used OTP"
            });
        }

        const now = new Date();
        if (record.createdAt && (now - record.createdAt > 5 * 60 * 1000)) {
            return res.status(400).json({
                success: false,
                message: "OTP expired"
            });
        }

        let user = await User.findOne({ phone });
        let isNewUser = false;

        if (!user) {
            isNewUser = true;
            user = new User({
                phone,
                name: '', 
                about: 'Hey there! I am using WhatsApp.',
                isRegistered: true,
            });
            await user.save();
        }

        console.log("STEP 4: Deleting OTP...");
        await Otp.deleteMany({ phone });
        console.log("STEP 5: OTP deleted");

        const jwtToken = jwt.sign({ uid: user._id.toString(), phone: user.phone }, JWT_SECRET, {
            expiresIn: '7d'
        });

        console.log("STEP 6: Before Firebase call");
        
        if (!admin || !admin.apps || admin.apps.length === 0) {
            console.error("Firebase NOT initialized properly");
            throw new Error("Firebase is not initialized properly");
        }
        
        console.log("STEP 7: Firebase instance:", typeof admin === 'object' ? "Valid Object" : typeof admin);
        console.log("STEP 8: Firebase apps:", admin.apps.length);
        
        console.log("STEP 9: Calling Firebase auth...");
        let firebaseToken = null;
        try {
            firebaseToken = await admin.auth().createCustomToken(user._id.toString());
            console.log("STEP 10: Firebase success");
        } catch (fbErr) {
            console.error("STEP ERROR:", fbErr);
            throw new Error("Firebase auth failed: " + fbErr.message);
        }

        console.log("Sending success response...");
        return res.json({
            success: true,
            message: "OTP verified successfully",
            data: {
                token: jwtToken,
                firebaseToken: firebaseToken,
                isNewUser,
                user: {
                    uid: user._id,
                    phone: user.phone,
                    name: user.name,
                    avatar: user.avatar,
                    about: user.about
                }
            }
        });

    } catch (error) {
        console.error('Verify OTP Error:', error);
        return res.status(500).json({
            success: false,
            message: error.message
        });
    }
};

exports.getMe = async (req, res) => {
    try {
        const user = await User.findById(req.uid).select('-twoFactorPin');
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

exports.updateAccountSettings = async (req, res) => {
    try {
        const { email, securityNotifications, twoFactorPin } = req.body;
        const updates = {};
        if (email !== undefined) updates.email = email;
        if (securityNotifications !== undefined) updates.securityNotifications = securityNotifications;
        if (twoFactorPin !== undefined) {
            // In a real app, hash this PIN!
            updates.twoFactorPin = twoFactorPin;
        }

        const updatedUser = await User.findByIdAndUpdate(req.uid, updates, { new: true }).select('-password -twoFactorPin');
        res.json(updatedUser);
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
};

exports.deleteAccount = async (req, res) => {
    try {
        const { phone } = req.body;
        const user = await User.findById(req.uid);

        if (!user) return res.status(404).json({ message: 'User not found' });
        if (user.phone !== phone) return res.status(400).json({ message: 'Phone number mismatch' });

        // Logic to delete everything related to user
        // 1. Delete OTPs
        const Otp = require('../models/Otp');
        await Otp.deleteMany({ phone });

        // 2. Delete User
        await User.findByIdAndDelete(req.uid);

        // 3. TODO: Clean up chats, messages, etc. (Complex, skipping for basic feature)

        res.json({ message: 'Account deleted successfully' });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
};

exports.requestAccountInfo = async (req, res) => {
    try {
        const user = await User.findById(req.uid).select('-twoFactorPin');
        if (!user) return res.status(404).json({ message: 'User not found' });

        // Generate a simple report
        const report = {
            user: user,
            generatedAt: new Date(),
            status: 'ready'
        };

        res.json(report);
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

