const express = require('express');
const router = express.Router();
const verifyToken = require('../middlewares/authMiddleware');
const mediaController = require('../controllers/mediaController');
const chatController = require('../controllers/chatController');

// --- MEDIA ROUTES (Hybrid Backend) ---
// Authorization: Bearer <ID_TOKEN>
// The folder destination is determined by the route path in mediaController
router.post('/upload/audio', verifyToken, mediaController.upload.single('file'), mediaController.uploadAudio);
router.post('/upload/image', verifyToken, mediaController.upload.single('file'), mediaController.uploadMedia);
router.post('/upload/group', verifyToken, mediaController.upload.single('file'), mediaController.uploadMedia);
router.post('/upload/profile', verifyToken, mediaController.upload.single('file'), mediaController.uploadMedia);

// --- CHAT ROUTES ---
router.post('/chats/private', verifyToken, chatController.createPrivateChat);
router.post('/chats/group', verifyToken, chatController.createGroupChat);
router.get('/chats', verifyToken, chatController.getMyChats);

// --- HEALTH CHECK ---
router.get('/health', (req, res) => res.send('WhatsApp Backend Running'));

module.exports = router;
