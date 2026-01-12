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

// Serve Static Files (Media on VPS Filesystem)
// Serve Static Files (Media on VPS Filesystem)
app.use('/uploads', express.static(path.join(__dirname, 'uploads'), {
    setHeaders: (res, path, stat) => {
        res.set('Access-Control-Allow-Origin', '*');
        res.set('Cross-Origin-Resource-Policy', 'cross-origin');
    }
}));

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
const { Server } = require("socket.io");
const io = new Server(server, {
    cors: {
        origin: "*",
        methods: ["GET", "POST"]
    }
});

const Call = require('./src/models/Call');

io.on("connection", (socket) => {
    console.log("User Connected:", socket.id);

    // Join User Room (for targeting specific users)
    socket.on("join-user", (userId) => {
        socket.join(userId);
        console.log(`User joined room: ${userId}`);
    });

    // --- Signaling Events ---

    socket.on("call-user", async (data) => {
        // data: { from, to, callType, offer }
        console.log(`Call initiated from ${data.from} to ${data.to}`);
        io.to(data.to).emit("incoming-call", {
            from: data.from,
            callType: data.callType,
            offer: data.offer // WebRTC Offer
        });

        // Log Call (Optional)
        try {
            const newCall = new Call({ from: data.from, to: data.to, type: data.callType });
            await newCall.save();
        } catch (e) { console.error("Call Log Error:", e); }
    });

    socket.on("accept-call", (data) => {
        console.log(`Call accepted by ${data.from}`);
        io.to(data.to).emit("call-accepted", {
            answer: data.answer // WebRTC Answer
        });
    });

    socket.on("reject-call", (data) => {
        console.log(`Call rejected by ${data.from}`);
        io.to(data.to).emit("call-rejected");
    });

    socket.on("end-call", (data) => {
        // data.to is the other party
        io.to(data.to).emit("call-ended");
    });

    // WebRTC ICE Candidates
    socket.on("ice-candidate", (data) => {
        io.to(data.to).emit("ice-candidate", {
            candidate: data.candidate
        });
    });

    socket.on("disconnect", () => {
        console.log("User Disconnected", socket.id);
    });
});

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
