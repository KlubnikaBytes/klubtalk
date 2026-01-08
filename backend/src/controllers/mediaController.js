const multer = require('multer');
const path = require('path');
const fs = require('fs');
const dotenv = require('dotenv');
const User = require('../models/User');

dotenv.config();

// Ensure directories exist
const ensureDir = (dir) => {
    if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
    }
};

// Configure Multer for Disk Storage (Hybrid Backend)
const storage = multer.diskStorage({
    destination: (req, file, cb) => {
        let dest = 'uploads/';
        // Use fieldname as primary indicator for robustness
        if (file.fieldname === 'avatar') {
            dest = 'uploads/avatars/';
        } else if (file.fieldname === 'voice') {
            dest = 'uploads/voice/';
        } else if (file.fieldname === 'image') {
            dest = 'uploads/images/';
        } else {
            // Fallbacks based on path/mimetype
            if (req.path.includes('/avatar')) dest = 'uploads/avatars/';
            else if (req.path.includes('/voice') || file.mimetype.startsWith('audio')) dest = 'uploads/voice/';
            else if (req.path.includes('/image') || file.mimetype.startsWith('image')) dest = 'uploads/images/';
        }
        ensureDir(dest);
        cb(null, dest);
    },
    filename: (req, file, cb) => {
        // Robust extension handling
        let ext = path.extname(file.originalname);

        // If extension is missing, infer from mimetype
        if (!ext || ext === '.') {
            if (file.mimetype === 'audio/mpeg') ext = '.mp3';
            else if (file.mimetype === 'audio/mp4' || file.mimetype === 'audio/x-m4a') ext = '.m4a';
            else if (file.mimetype === 'audio/aac') ext = '.aac';
            else if (file.mimetype === 'audio/wav') ext = '.wav';
            else if (file.mimetype.startsWith('audio/')) ext = '.mp3'; // Fallback for voice
            else if (file.mimetype === 'image/jpeg') ext = '.jpg';
            else if (file.mimetype === 'image/png') ext = '.png';
        }

        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        cb(null, uniqueSuffix + ext);
    }
});

const upload = multer({
    storage: storage,
    limits: { fileSize: 50 * 1024 * 1024 } // 50MB limit
});

// Upload Voice/Audio
const uploadVoice = (req, res) => {
    if (!req.file) {
        return res.status(400).json({ error: 'No file uploaded' });
    }

    // Store relative path (e.g., /uploads/voice/filename.mp3)
    const filePath = `/uploads/voice/${req.file.filename}`;

    return res.status(200).json({
        message: 'Voice uploaded successfully',
        url: filePath,
        filename: req.file.filename,
        mimetype: req.file.mimetype
    });
};

// Upload Avatar (Profile Picture)
const uploadAvatar = async (req, res) => {
    if (!req.file) {
        return res.status(400).json({ error: 'No avatar uploaded' });
    }

    try {
        // Store relative path (e.g., /uploads/avatars/filename.jpg)
        const filePath = `/uploads/avatars/${req.file.filename}`;
        const firebaseUid = req.user.uid;

        // Update User in MongoDB by firebaseUid
        const updatedUser = await User.findOneAndUpdate(
            { firebaseUid: firebaseUid },
            {
                $set: { avatar: filePath },
                $setOnInsert: {
                    phone: req.user.phone_number || 'UNKNOWN_PHONE',
                    createdAt: new Date()
                }
            },
            { new: true, upsert: true, setDefaultsOnInsert: true }
        );

        return res.status(200).json({
            message: 'Profile photo updated successfully',
            url: filePath,
            user: updatedUser
        });
    } catch (error) {
        console.error('Avatar upload error:', error);
        return res.status(500).json({ error: 'Failed to update profile photo' });
    }
};

// Upload Chat Image
const uploadImage = (req, res) => {
    if (!req.file) {
        return res.status(400).json({ error: 'No file uploaded' });
    }

    // Store relative path (e.g., /uploads/images/filename.jpg)
    const filePath = `/uploads/images/${req.file.filename}`;

    return res.status(200).json({
        message: 'Image uploaded successfully',
        url: filePath,
        type: 'image'
    });
};

module.exports = {
    upload,
    uploadVoice,
    uploadAvatar,
    uploadImage
};
