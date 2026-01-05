const multer = require('multer');
const path = require('path');
const dotenv = require('dotenv');

dotenv.config();

// Configure Multer for Disk Storage (Hybrid Backend)
const storage = multer.diskStorage({
    destination: (req, file, cb) => {
        cb(null, 'uploads/');
    },
    filename: (req, file, cb) => {
        // Unique filename: timestamp + random + extension
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        cb(null, uniqueSuffix + path.extname(file.originalname));
    }
});

const upload = multer({
    storage: storage,
    limits: { fileSize: 50 * 1024 * 1024 } // 50MB limit
});

// Upload Audio
const uploadAudio = (req, res) => {
    if (!req.file) {
        return res.status(400).json({ error: 'No file uploaded' });
    }

    // Construct Public URL
    // On a real VPS, use the actual domain. Locally, use localhost.
    const baseUrl = process.env.VPS_PUBLIC_URL || 'http://localhost:3000';
    const fileUrl = `${baseUrl}/uploads/${req.file.filename}`;

    // Return the URL for the client to save to Firestore
    return res.status(200).json({
        message: 'Audio uploaded successfully',
        url: fileUrl,
        filename: req.file.filename,
        mimetype: req.file.mimetype
    });
};

// Upload Generic Media
const uploadMedia = (req, res) => {
    if (!req.file) {
        return res.status(400).json({ error: 'No file uploaded' });
    }

    const baseUrl = process.env.VPS_PUBLIC_URL || 'http://localhost:3000';
    const fileUrl = `${baseUrl}/uploads/${req.file.filename}`;

    return res.status(200).json({
        message: 'Media uploaded successfully',
        url: fileUrl,
        type: req.body.type || 'media'
    });
};

module.exports = {
    upload,
    uploadAudio,
    uploadMedia
};
