const express = require('express');
const router = express.Router();
const chatController = require('../controllers/chatController');
const verifyToken = require('../middlewares/authMiddleware');

router.use(verifyToken);

router.get('/', chatController.getChats);
router.post('/', chatController.createChat); // Create/Get 1-on-1
router.get('/:chatId/messages', chatController.getMessages);

module.exports = router;
