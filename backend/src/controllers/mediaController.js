const multer = require('multer');
const path = require('path');
const fs = require('fs');
const dotenv = require('dotenv');
const User = require('../models/User');
const { Jimp } = require('jimp');

dotenv.config();

const sharp = require('sharp');
const ffmpeg = require('fluent-ffmpeg');

// Ensure directories exist
const ensureDir = (dir) => {
    if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
    }
};

// ... (Multer storage remains same)

// Helper: Create Image Preview (JPEG)
async function createImagePreview(originalPath) {
    try {
        const previewFilename = 'preview_' + path.basename(originalPath, path.extname(originalPath)) + '.jpg';
        const previewPath = path.join(path.dirname(originalPath), previewFilename);

        console.log(`[Media] Generating preview for: ${originalPath}`);

        await sharp(originalPath)
            .resize(600, 600, { fit: 'inside', withoutEnlargement: true }) // Max 600px
            .toFormat('jpeg', { quality: 70 })
            .toFile(previewPath);

        console.log(`[Media] Preview generated: ${previewPath}`);
        return previewPath.replace(/\\/g, '/'); // Normalize slashes
    } catch (err) {
        console.error(`Image preview generation failed for ${originalPath}:`, err);
        return null; // Fallback to original
    }
}

// Helper: Create Video Preview (JPEG Snapshot)
function createVideoPreview(videoPath) {
    return new Promise((resolve, reject) => {
        try {
            const previewFilename = 'thumb_' + Date.now() + '.jpg';
            const outputDir = path.dirname(videoPath);

            ffmpeg(videoPath)
                .screenshots({
                    count: 1,
                    folder: outputDir,
                    filename: previewFilename,
                    size: '640x?' // Maintain aspect ratio
                })
                .on('end', () => {
                    const previewPath = path.join(outputDir, previewFilename);
                    resolve(previewPath.replace(/\\/g, '/'));
                })
                .on('error', (err) => {
                    console.error('Video preview failed:', err);
                    resolve(null); // Resolve null on error to not block flow
                });
        } catch (err) {
            console.error('FFmpeg error:', err);
            resolve(null);
        }
    });
}
// ... (Multer and other helpers)


// Upload Chat Media (Generic: Image, Video, File)
const uploadImage = async (req, res) => {
    if (!req.file) {
        return res.status(400).json({ error: 'No file uploaded' });
    }

    let type = 'file';
    const mime = req.file.mimetype;

    if (mime.startsWith('image')) type = 'image';
    if (mime.startsWith('video')) type = 'video';
    if (mime.startsWith('audio')) type = 'audio'; // Optional, but usually audio is file or dedicated voice

    // Correct extension based on intended type logic
    if (type === 'video') correctFileExtension(req.file, 'video');
    else if (type === 'image') correctFileExtension(req.file, 'image');
    // else file, keep original or detect generic? generic detectFileExtension handles some.

    const filePath = `/uploads/images/${req.file.filename}`; // Storing all generic media in images folder for now or separate? 
    // The prompt suggested: app.use("/uploads", express.static("uploads")); and storage destination 'uploads/'.
    // My storage config puts them in 'uploads/images', 'uploads/voice' etc.
    // I should probably keep 'uploads/images' for backward compatibility or use 'uploads/files'?
    // I'll stick to 'images' or just respect where multer put it. 
    // Multer (lines 114+) rules: if fieldname 'image' -> 'uploads/images'. 
    // Frontend should likely use 'image' fieldname for this endpoint to work with existing multer config.

    // But wait, if I upload a PDF, Multer (lines 127) defaults to:
    // if path includes 'image' ... 
    // I should ideally update Multer config too if I want separate folders, but avoiding complex changes.
    // I'll rely on it landing in 'uploads/images' (or wherever fieldname directs) and just setting 'type' correctly.

    const fullPath = req.file.path;
    let previewUrl = null;

    // Generate Preview
    if (type === 'image') {
        const previewAbsPath = await createImagePreview(fullPath);
        if (previewAbsPath) {
            const relative = path.relative(path.resolve(__dirname, '../../'), previewAbsPath);
            previewUrl = '/' + relative.replace(/\\/g, '/');
        }
    } else if (type === 'video') {
        const previewAbsPath = await createVideoPreview(fullPath);
        if (previewAbsPath) {
            const relative = path.relative(path.resolve(__dirname, '../../'), previewAbsPath);
            previewUrl = '/' + relative.replace(/\\/g, '/');
        }
    }

    return res.status(200).json({
        message: 'Media uploaded successfully',
        originalUrl: filePath,
        url: filePath,
        previewUrl: previewUrl || null, // Null for files means no preview
        type: type,
        mime: mime,
        filename: req.file.originalname, // Add filename for generic files
        size: req.file.size
    });
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
        // Robust extension handling via MIME type
        const mimeToExt = {
            'image/jpeg': '.jpg',
            'image/png': '.png',
            'image/gif': '.gif',
            'image/webp': '.webp',
            'image/avif': '.avif',
            'audio/mpeg': '.mp3',
            'audio/mp4': '.m4a',
            'audio/x-m4a': '.m4a',
            'audio/wav': '.wav',
            'audio/aac': '.aac',
            'application/pdf': '.pdf'
        };

        let ext = mimeToExt[file.mimetype];

        // Fallback: If unknown MIME type, use original extension
        if (!ext) {
            ext = path.extname(file.originalname);
        }

        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        cb(null, uniqueSuffix + ext);
    }
});

const upload = multer({
    storage: storage,
    limits: { fileSize: 50 * 1024 * 1024 } // 50MB limit
});

// Helper: Detect file extension from magic bytes
const detectFileExtension = (filePath) => {
    try {
        const buffer = Buffer.alloc(40); // Read first 40 bytes
        const fd = fs.openSync(filePath, 'r');
        fs.readSync(fd, buffer, 0, 40, 0);
        fs.closeSync(fd);

        // Check Magic Bytes
        if (buffer[0] === 0xFF && buffer[1] === 0xD8 && buffer[2] === 0xFF) return '.jpg';
        if (buffer[0] === 0x89 && buffer[1] === 0x50 && buffer[2] === 0x4E && buffer[3] === 0x47) return '.png';
        if (buffer[0] === 0x47 && buffer[1] === 0x49 && buffer[2] === 0x46 && buffer[3] === 0x38) return '.gif';
        if (buffer[0] === 0x42 && buffer[1] === 0x4D) return '.bmp';

        // WebP (RIFF....WEBP)
        if (buffer.subarray(0, 4).toString() === 'RIFF' && buffer.subarray(8, 12).toString() === 'WEBP') return '.webp';

        // AVIF (....ftypavif)
        // Offset 4 usually contains 'ftyp'
        if (buffer.subarray(4, 8).toString() === 'ftyp' && buffer.subarray(8, 12).toString() === 'avif') return '.avif';

        // Audio
        if (buffer.subarray(0, 3).toString() === 'ID3') return '.mp3'; // MP3 with ID3
        if (buffer[0] === 0xFF && (buffer[1] & 0xE0) === 0xE0) return '.mp3'; // MP3 without ID3 (approx)
        if (buffer.subarray(0, 4).toString() === 'RIFF' && buffer.subarray(8, 12).toString() === 'WAVE') return '.wav';
        if (buffer.subarray(0, 4).toString() === 'OggS') return '.ogg';

        // M4A / MP4 / MOV / WEBM
        if (buffer.subarray(4, 8).toString() === 'ftyp') {
            const sub = buffer.subarray(8, 12).toString();
            if (['isom', 'iso2', 'avc1', 'mp41', 'mp42'].includes(sub)) return '.mp4'; // Major MP4 signatures
            if (['M4A '].includes(sub)) return '.m4a';
            if (['qt  '].includes(sub)) return '.mov';
        }

        // WEBM (1A 45 DF A3)
        if (buffer[0] === 0x1A && buffer[1] === 0x45 && buffer[2] === 0xDF && buffer[3] === 0xA3) return '.webm';

        return null; // Unknown
    } catch (err) {
        console.error('Error detecting file extension:', err);
        return null;
    }
};

// Helper: Correct file extension securely
const correctFileExtension = (reqFile, intendedType = 'file') => {
    const detectedExt = detectFileExtension(reqFile.path);
    const currentExt = path.extname(reqFile.filename);

    // Always detect mime if we can, to ensure response is correct
    const extToMime = {
        '.jpg': 'image/jpeg',
        '.png': 'image/png',
        '.gif': 'image/gif',
        '.webp': 'image/webp',
        '.avif': 'image/avif',
        '.mp4': 'video/mp4',
        '.mov': 'video/quicktime',
        '.webm': 'video/webm',
        '.mp3': 'audio/mpeg',
        '.wav': 'audio/wav',
        '.m4a': 'audio/mp4',
        '.pdf': 'application/pdf',
    };

    if (detectedExt && extToMime[detectedExt]) {
        reqFile.mimetype = extToMime[detectedExt];
    }

    if (detectedExt && detectedExt !== currentExt) {
        console.log(`[Media] Extension Mismatch: '${currentExt}' -> '${detectedExt}'. Renaming...`);
        const newFilename = reqFile.filename.replace(currentExt, detectedExt);
        const newPath = path.join(path.dirname(reqFile.path), newFilename);

        fs.renameSync(reqFile.path, newPath);

        // Update req.file properties to match new file
        reqFile.filename = newFilename;
        reqFile.path = newPath; // Full local path
    }
    return reqFile;
};

// Upload Voice/Audio
const uploadVoice = (req, res) => {
    if (!req.file) {
        return res.status(400).json({ error: 'No file uploaded' });
    }

    // 1. Correct Extension
    correctFileExtension(req.file, 'audio');

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
        // 1. Correct Extension
        correctFileExtension(req.file, 'image');

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

// Upload Video (New Implementation)
const uploadVideo = async (req, res) => {
    if (!req.file) {
        return res.status(400).json({ error: 'No file uploaded' });
    }

    correctFileExtension(req.file, 'video');

    // Generate Preview
    const previewAbsPath = await createVideoPreview(req.file.path);
    let previewUrl = null;
    if (previewAbsPath) {
        const relative = path.relative(path.resolve(__dirname, '../../'), previewAbsPath);
        previewUrl = '/' + relative.replace(/\\/g, '/');
    }

    const filePath = `/uploads/voice/${req.file.filename}`;

    return res.status(200).json({
        message: 'Video uploaded successfully',
        url: filePath,
        previewUrl: previewUrl,
        type: 'video',
        mime: req.file.mimetype
    });
};

module.exports = {
    upload,
    uploadVoice,
    uploadAvatar,
    uploadImage,
    uploadVideo
};
