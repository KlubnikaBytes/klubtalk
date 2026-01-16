const Chat = require('../models/Chat');
const Message = require('../models/Message');
const User = require('../models/User');

// --- Helpers ---
const getChatResponse = async (chatId) => {
    return await Chat.findById(chatId)
        .populate('participants', 'name phone avatar about isOnline lastSeen')
        .populate('lastMessage')
        .populate('groupAdmin', 'name phone');
};

// --- Core Chat ---
exports.getMyChats = async (req, res) => {
    try {
        const chats = await Chat.find({ participants: req.uid })
            .populate('participants', 'name phone avatar about isOnline lastSeen')
            .populate('lastMessage')
            .sort({ updatedAt: -1 });
        res.json(chats);
    } catch (e) { res.status(500).json({ error: e.message }); }
};

exports.getMessages = async (req, res) => {
    try {
        const { chatId } = req.params;
        const { page = 1, limit = 50 } = req.query;
        const messages = await Message.find({ chatId })
            .sort({ createdAt: -1 })
            .skip((page - 1) * limit)
            .limit(parseInt(limit));
        res.json(messages.reverse());
    } catch (e) { res.status(500).json({ error: e.message }); }
};

exports.createPrivateChat = async (req, res) => {
    try {
        const { peerId } = req.body;
        if (!peerId) {
            return res.status(400).json({ error: "peerId is required" });
        }
        let chat = await Chat.findOne({
            isGroup: false,
            participants: { $all: [req.uid, peerId] }
        });

        if (!chat) {
            chat = await Chat.create({
                isGroup: false,
                participants: [req.uid, peerId]
            });
        }
        res.json(await getChatResponse(chat._id));
    } catch (e) { res.status(500).json({ error: e.message }); }
};

const { getIO } = require('../socket'); // Import socket helper

exports.sendMessage = async (req, res) => {
    try {
        const { chatId, content, type, mediaUrl, tempId } = req.body; // Extract tempId
        // Fallback REST endpoint. Ideally use Socket.
        const message = await Message.create({
            chatId,
            senderId: req.uid,
            content,
            type: type || 'text',
            mediaUrl,
            status: 'sent'
        });
        await Chat.findByIdAndUpdate(chatId, { lastMessage: message._id, updatedAt: new Date() });

        // --- Socket Emission for Real-time Delivery ---
        try {
            const { getIO, notifyDelivery } = require('../socket');
            const io = getIO();

            // Emit to Chat Room (Include tempId for dedup/matching)
            const msgObj = message.toObject();
            if (tempId) msgObj.tempId = tempId;
            io.to(chatId).emit('new_message', msgObj);

            // Check Delivery
            await notifyDelivery(io, message, chatId, tempId);

        } catch (socketErr) {
            console.error("Socket emit error in REST:", socketErr);
            // Don't fail the request if socket fails
        }

        res.json(message);
    } catch (e) { res.status(500).json({ error: e.message }); }
};

// --- Groups ---
exports.createGroupChat = async (req, res) => {
    try {
        const { name, participants, avatar } = req.body;
        // participants is array of IDs. Add self.
        const allParticipants = [...new Set([...participants, req.uid])];

        const chat = await Chat.create({
            isGroup: true,
            groupName: name,
            groupAdmin: req.uid,
            groupAvatar: avatar,
            participants: allParticipants
        });

        res.json(await getChatResponse(chat._id));
    } catch (e) { res.status(500).json({ error: e.message }); }
};

exports.createCommunity = async (req, res) => {
    // Placeholder for Community
    try {
        const { name, description } = req.body;
        res.json({ message: "Community created (stub)", id: "comm_" + Date.now() });
    } catch (e) { res.status(500).json({ error: e.message }); }
};

exports.getCommunity = async (req, res) => {
    res.json({ message: "Community details (stub)" });
};

// --- Features (Stubs/Basic Impl) ---
exports.toggleFavorite = async (req, res) => {
    // Requires 'isFavorite' field in Chat schema or User-Chat mapping. 
    // For now success stub.
    res.json({ success: true });
};

exports.toggleArchive = async (req, res) => {
    // Requires 'isArchived'. Stub.
    res.json({ success: true });
};

exports.muteChat = async (req, res) => {
    // Requires 'isMuted'. Stub.
    res.json({ success: true });
};

exports.setDisappearingTimer = async (req, res) => {
    res.json({ success: true });
};

exports.setChatTheme = async (req, res) => {
    res.json({ success: true });
};

exports.reportChat = async (req, res) => {
    res.json({ success: true, message: "Reported" });
};

// --- Blocking (User Logic) ---
// Note: Ideally move to userController, but api.js routes here.
exports.blockUser = async (req, res) => {
    try {
        const { userId } = req.body;
        await User.findByIdAndUpdate(req.uid, { $addToSet: { blockedUsers: userId } });
        res.json({ success: true, message: "Blocked" });
    } catch (e) { res.status(500).json({ error: e.message }); }
};

exports.unblockUser = async (req, res) => {
    try {
        const { userId } = req.body; // or req.query if delete?? api says POST typically for actions, but route says DELETE
        // Route: router.delete('/block-user', ...). Body in delete? use query or body.
        const targetId = userId || req.query.userId;
        await User.findByIdAndUpdate(req.uid, { $pull: { blockedUsers: targetId } });
        res.json({ success: true, message: "Unblocked" });
    } catch (e) { res.status(500).json({ error: e.message }); }
};

exports.getBlockedUsers = async (req, res) => {
    try {
        const user = await User.findById(req.uid).populate('blockedUsers', 'name phone avatar');
        res.json(user.blockedUsers);
    } catch (e) { res.status(500).json({ error: e.message }); }
};
