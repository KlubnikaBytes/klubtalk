const express = require('express');
const router = express.Router();
const verifyToken = require('../middlewares/authMiddleware');
const mediaController = require('../controllers/mediaController');
const chatController = require('../controllers/chatController');

// --- MEDIA ROUTES (Hybrid Backend) ---
// Authorization: Bearer <ID_TOKEN>
const authController = require('../controllers/authController');

// --- AUTH ROUTES ---
router.post('/auth/login', verifyToken, authController.login);
router.get('/auth/profile', verifyToken, authController.getProfile);
router.put('/auth/profile', verifyToken, authController.updateProfile);
router.get('/users', verifyToken, authController.getAllUsers);

// --- MEDIA ROUTES (Hybrid Backend) ---
// Authorization: Bearer <ID_TOKEN>
router.post('/upload/avatar', verifyToken, mediaController.upload.single('avatar'), mediaController.uploadAvatar);
router.post('/upload/image', verifyToken, mediaController.upload.single('image'), mediaController.uploadImage);
router.post('/upload/voice', verifyToken, mediaController.upload.single('voice'), mediaController.uploadVoice);

const contactController = require('../controllers/contactController');
const { seedUsers } = require('../utils/userSeeder');

// --- CONTACT ROUTES ---
router.post('/contacts/add', verifyToken, contactController.addContact);
router.get('/contacts', verifyToken, contactController.getMyContacts);

// --- SEEDER ROUTES (DEV) ---
router.post('/seed/users', seedUsers);

// --- CHAT ROUTES ---
router.post('/chats/private', verifyToken, chatController.createPrivateChat);
router.post('/chats/group', verifyToken, chatController.createGroupChat);
router.post('/chats/community', verifyToken, chatController.createCommunity);
router.get('/communities/:communityId', verifyToken, chatController.getCommunity);
router.get('/chats', verifyToken, chatController.getMyChats);
router.post('/chats/favorite', verifyToken, chatController.toggleFavorite);
router.post('/chats/archive', verifyToken, chatController.toggleArchive);
router.post('/chats/mute', verifyToken, chatController.muteChat);
router.post('/chats/disappearing', verifyToken, chatController.setDisappearingTimer);
router.post('/chats/wallpaper', verifyToken, chatController.setChatTheme);
router.post('/chats/report', verifyToken, chatController.reportChat);

// New Block Routes per architecture
router.post('/block-user', verifyToken, chatController.blockUser);
router.delete('/block-user', verifyToken, chatController.unblockUser);
router.get('/blocked-users/:userId', verifyToken, chatController.getBlockedUsers);

// Backwards compatibility / existing frontend calls (mapped to new controllers)
router.post('/users/block', verifyToken, chatController.blockUser);
router.post('/users/unblock', verifyToken, chatController.unblockUser);

router.post('/messages', verifyToken, chatController.sendMessage);
router.get('/messages/:chatId', verifyToken, chatController.getMessages);

// --- HEALTH CHECK ---
router.get('/health', (req, res) => res.send('WhatsApp Backend Running'));

const searchController = require('../controllers/searchController');

// --- Search Routes ---
router.get('/search/global', verifyToken, searchController.globalSearch);
router.get('/search/chat/:chatId', verifyToken, searchController.chatSearch);

const statusController = require('../controllers/statusController');

// --- STATUS ROUTES ---
router.post('/status/create', verifyToken, statusController.createStatus);
router.get('/status/feed', verifyToken, statusController.getFeed);
router.post('/status/view', verifyToken, statusController.viewStatus);
router.delete('/status/:statusId', verifyToken, statusController.deleteStatus);

module.exports = router;
