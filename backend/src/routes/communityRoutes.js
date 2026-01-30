const express = require('express');
const router = express.Router();
const communityController = require('../controllers/communityController');
const verifyToken = require('../middlewares/authMiddleware');

router.use(verifyToken); // Protect all community routes

router.post('/create', communityController.createCommunity);
router.get('/', communityController.getMyCommunities);
router.get('/:id', communityController.getCommunityById);
router.post('/:id/groups', communityController.addGroupsToCommunity);
router.delete('/:id/groups/:groupId', communityController.removeGroupFromCommunity);

module.exports = router;
