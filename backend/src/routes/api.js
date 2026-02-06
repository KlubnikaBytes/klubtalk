const express = require('express');
const router = express.Router();
const verifyToken = require('../middlewares/authMiddleware');
const mediaController = require('../controllers/mediaController');
const chatController = require('../controllers/chatController');

// --- MEDIA ROUTES (Hybrid Backend) ---
// Authorization: Bearer <ID_TOKEN>
const authController = require('../controllers/authController');

// --- AUTH ROUTES (OTP) ---
router.post('/auth/send-otp', authController.sendOtp);
router.post('/auth/verify-otp', authController.verifyOtp);
router.get('/auth/me', verifyToken, authController.getMe);
router.put('/auth/me', verifyToken, authController.updateProfile);
router.post('/auth/fcm-token', verifyToken, authController.updateFcmToken);


// router.get('/auth/profile', verifyToken, authController.getProfile); // Removed or remapped to getMe
// router.put('/auth/profile', verifyToken, authController.updateProfile); // TODO: Add updateProfile to authController if needed, or keep separate userController logic. 
// For now, I will comment them out to strictly follow "Replacement" plan.
// Actually, `updateProfile` is likely needed for Name/About updates. I should probably keep it but ensure `authController` has it.
// The user said "Only authentication must change". Update profile logic is likely `User` logic.
// I will keep `getAllUsers`.

// Current authController.js ONLY has sendOtp, verifyOtp, getMe.
// I need to add getAllUsers back to authController? Or move it.
// To avoid breaking chat, I should add getAllUsers to authController.js.

router.get('/users/:id', verifyToken, authController.getUserById);
router.get('/users', verifyToken, authController.getAllUsers); // IMPORTANT: I need to add getAllUsers to the new authController or move it to userController.


// --- MEDIA ROUTES (Hybrid Backend) ---
// Authorization: Bearer <ID_TOKEN>
router.post('/upload/avatar', verifyToken, mediaController.upload.single('avatar'), mediaController.uploadAvatar);
router.post('/upload/image', verifyToken, mediaController.upload.single('image'), mediaController.uploadImage);
router.post('/upload/voice', verifyToken, mediaController.upload.single('voice'), mediaController.uploadVoice);

const contactController = require('../controllers/contactController');
const { seedUsers } = require('../utils/userSeeder');

// --- CONTACT ROUTES ---
router.post('/contacts/add', verifyToken, contactController.addContact);
router.post('/contacts/sync', verifyToken, contactController.syncContacts);
router.get('/contacts', verifyToken, contactController.getMyContacts);

// --- SEEDER ROUTES (DEV) ---
router.post('/seed/users', seedUsers);

const communityRoutes = require('./communityRoutes');

// --- CHAT ROUTES ---
router.post('/chats/private', verifyToken, chatController.createPrivateChat);
router.post('/chats/group', verifyToken, chatController.createGroupChat);
// Community routes now handled by communityRoutes mounted at /communities
router.use('/communities', verifyToken, communityRoutes);
router.get('/chats', verifyToken, chatController.getMyChats);
router.post('/chats/favorite', verifyToken, chatController.toggleFavorite);
router.post('/chats/archive', verifyToken, chatController.toggleArchive);
router.post('/chats/mute', verifyToken, chatController.muteChat);
router.post('/chats/disappearing', verifyToken, chatController.setDisappearingTimer);
router.post('/chats/wallpaper', verifyToken, chatController.setChatTheme);
router.post('/chats/report', verifyToken, chatController.reportChat);

// --- GROUP MANAGEMENT ROUTES ---
router.put('/chats/:chatId/info', verifyToken, chatController.updateGroupInfo);
router.put('/chats/:chatId/permissions', verifyToken, chatController.updateGroupPermissions);
router.post('/chats/:chatId/participants', verifyToken, chatController.addGroupParticipant);
router.delete('/chats/:chatId/participants/:userId', verifyToken, chatController.removeGroupParticipant);
router.post('/chats/:chatId/admins', verifyToken, chatController.promoteToAdmin);
router.delete('/chats/:chatId/admins/:userId', verifyToken, chatController.demoteAdmin);
router.post('/chats/:chatId/leave', verifyToken, chatController.leaveGroup);


// New Block Routes per architecture
router.post('/block-user', verifyToken, chatController.blockUser);
router.delete('/block-user', verifyToken, chatController.unblockUser);
router.get('/blocked-users/:userId', verifyToken, chatController.getBlockedUsers);

// Backwards compatibility / existing frontend calls (mapped to new controllers)
router.post('/users/block', verifyToken, chatController.blockUser);
router.post('/users/unblock', verifyToken, chatController.unblockUser);

router.post('/messages', verifyToken, chatController.sendMessage);
router.post('/messages/:messageId/ack', verifyToken, chatController.ackMessage); // 🎯 NEW: ACK Route
router.post('/messages/:messageId/react', verifyToken, chatController.addReaction); // 🎯 NEW: Reaction Route
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
router.get('/status/:userId', verifyToken, statusController.getUserStatus);
router.post('/status/view', verifyToken, statusController.viewStatus);
router.delete('/status/:statusId', verifyToken, statusController.deleteStatus);
router.post('/status/mute', verifyToken, statusController.muteUser);
router.post('/status/unmute', verifyToken, statusController.unmuteUser);

const callController = require('../controllers/callController');

// --- CALL ROUTES ---
router.post('/calls/save', verifyToken, callController.saveCall);
router.get('/calls/history/:userId', verifyToken, callController.getCallHistory);
router.post('/calls/reject', verifyToken, callController.rejectCall); // 🎯 NEW: HTTP Rejection
router.get('/calls/:callId', verifyToken, callController.getCallById);

const stickerController = require('../controllers/stickerController');

// --- STICKER ROUTES ---
router.get('/stickers/packs', stickerController.getPacks); // Public or Protected? Service sends token if available. 
// Ideally protected if we want to track usage, but stickers are general asset. Let's make it verifyToken optional or verified. 
// Service sends token.
router.get('/stickers/pack/:id', stickerController.getPackDetails);

module.exports = router;
