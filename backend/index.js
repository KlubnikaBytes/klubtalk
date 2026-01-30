const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const path = require('path');
const connectDB = require('./src/config/db');
const apiRoutes = require('./src/routes/api');

// 1. Load Env Config
dotenv.config();

// 2. Connect to MongoDB
connectDB();

// 3. Initialize Firebase Admin SDK for Push Notifications
const admin = require('firebase-admin');
const serviceAccount = require('./src/config/firebase-admin.json');

try {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
    });
    console.log('🔥 Firebase Admin SDK initialized');
} catch (error) {
    console.error('Failed to initialize Firebase Admin SDK:', error);
}


// --- Auto-Repair: Clean up broken chats ---
const Chat = require('./src/models/Chat');
(async () => {
    try {
        // Wait a tick for connection
        setTimeout(async () => {
            const result = await Chat.deleteMany({ participants: null });
            if (result.deletedCount > 0) {
                console.log(`🧹 CLEANUP: Deleted ${result.deletedCount} broken chats with null participants.`);
            }
        }, 3000);
    } catch (e) { console.error("Auto-Repair Error:", e); }
})();

// --- Auto-Repair: Clean up broken calls ---
const Call = require('./src/models/Call');
(async () => {
    try {
        setTimeout(async () => {
            const result = await Call.deleteMany({
                $or: [
                    { from: null },
                    { to: null },
                    { from: "null" },
                    { to: "null" },
                    { callerPhone: null },
                    { receiverPhone: null }
                ]
            });
            if (result.deletedCount > 0) {
                console.log(`🧹 CLEANUP: Deleted ${result.deletedCount} broken calls.`);
            }
        }, 3500);
    } catch (e) { console.error("Auto-Repair Call Error:", e); }
})();

const app = express();


// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Request Logger
app.use((req, res, next) => {
    console.log(`[${req.method}] ${req.url}`, req.method === 'POST' ? JSON.stringify(req.body).substring(0, 100) : '');
    next();
});

// Video Streaming Endpoint with Range Request Support
// This fixes the infinite loading issue for video status
const fs = require('fs');

app.get('/uploads/images/:file', (req, res) => {
    const filePath = path.join(__dirname, 'uploads/images', req.params.file);

    // Check if file exists
    if (!fs.existsSync(filePath)) {
        return res.status(404).send('File not found');
    }

    const stat = fs.statSync(filePath);
    const fileSize = stat.size;
    const range = req.headers.range;

    // If range header is present (video streaming)
    if (range) {
        const parts = range.replace(/bytes=/, "").split("-");
        const start = parseInt(parts[0], 10);
        const end = parts[1] ? parseInt(parts[1], 10) : fileSize - 1;
        const chunkSize = (end - start) + 1;

        const file = fs.createReadStream(filePath, { start, end });

        res.writeHead(206, {
            'Content-Range': `bytes ${start}-${end}/${fileSize}`,
            'Accept-Ranges': 'bytes',
            'Content-Length': chunkSize,
            'Content-Type': 'video/mp4',
        });

        file.pipe(res);
    } else {
        // No range header (regular request for images or full video)
        res.writeHead(200, {
            'Content-Length': fileSize,
            'Content-Type': req.params.file.endsWith('.mp4') ? 'video/mp4' : 'image/jpeg',
        });
        fs.createReadStream(filePath).pipe(res);
    }
});

// Serve Static Files (Media on VPS Filesystem)
// This handles other upload folders (avatars, etc.)
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// Health Check
app.get('/health', (req, res) => {
    res.status(200).json({
        status: 'ok',
        message: 'Backend API is running',
        mongo_uri_configured: !!process.env.MONGO_URI
    });
});

app.get('/ping', (req, res) => res.send('pong'));

// Routes
app.use('/', apiRoutes);

// Start Server
const PORT = process.env.PORT || 5000;

// Root Route
app.get("/", (req, res) => {
    res.send("Antigravity backend running 🚀");
});

// Start Server with Socket.IO
const http = require('http');
const server = http.createServer(app);
const socketController = require('./src/socket');

// Initialize with Server
socketController.init(server);

server.listen(PORT, () => {
    console.log(`🚀 Server running on port ${PORT}`);
    console.log(`Media serving at ${process.env.VPS_PUBLIC_URL || 'http://localhost:' + PORT}/uploads/`);
});

// Cleanup Job for Disappearing Messages (Every 60 seconds)
const Message = require('./src/models/Message');
setInterval(async () => {
    try {
        const result = await Message.deleteMany({
            expiresAt: { $lt: new Date() }
        });
        if (result.deletedCount > 0) {
            console.log(`🧹 Cleanup: Deleted ${result.deletedCount} expired messages.`);
        }
    } catch (err) {
        console.error('Cleanup Job Error:', err);
    }
}, 60000);

// Cleanup Expired Statuses (Every 60 seconds)
// Cleanup Expired Statuses (Every 60 seconds)
const statusController = require('./src/controllers/statusController');
setInterval(async () => {
    await statusController.cleanupExpiredStatuses();
}, 60000);
