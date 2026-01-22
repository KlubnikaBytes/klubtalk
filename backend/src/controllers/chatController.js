const Chat = require('../models/Chat');
const Message = require('../models/Message');
const User = require('../models/User');

// --- Helpers ---
// --- Helpers ---
// Updated to accept currentUserId and sanitize blocked users
const getChatResponse = async (chatId, currentUserId) => {
    let chat = await Chat.findById(chatId)
        .populate('participants', 'name phone avatar about isOnline lastSeen')
        .populate('lastMessage')
        .populate('groupAdmin', 'name phone')
        .lean(); // Use lean to edit

    if (!chat || !currentUserId) return chat;

    // Sanitize Blocked Users
    const User = require('../models/User');
    const me = await User.findById(currentUserId).select('blockedUsers blockedByUsers');
    const blockedSet = new Set([
        ...(me.blockedUsers || []),
        ...(me.blockedByUsers || [])
    ].map(id => id.toString()));

    if (chat.participants) {
        chat.participants = chat.participants.map(p => {
            if (blockedSet.has(p._id.toString())) {
                return {
                    ...p,
                    avatar: '', // Hide Avatar
                    about: '', // Hide About
                    isOnline: false, // Hide Online
                    lastSeen: null // Hide Last Seen
                    // Name and Phone remain (in groups you see name/phone usually)
                };
            }
            return p;
        });
    }
    return chat;
};

// --- Core Chat ---
exports.getMyChats = async (req, res) => {
    try {
        const chats = await Chat.find({ participants: req.uid })
            .populate('participants', 'name phone avatar about isOnline lastSeen')
            .populate('lastMessage')
            .lean() // Use lean to modify the object
            .sort({ updatedAt: -1 });

        // Fetch User to get archived list AND blocked lists
        const user = await User.findById(req.uid).select('archivedChats blockedUsers blockedByUsers');
        const archivedIds = user?.archivedChats?.map(id => id.toString()) || [];
        const blockedSet = new Set([
            ...(user?.blockedUsers || []),
            ...(user?.blockedByUsers || [])
        ].map(id => id.toString()));

        const enrichedChats = chats.filter(chat => {
            if (chat.isGroup) return true; // Groups are usually visible? Requirement says "Chats list: Exclude blocked users". Usually means Private.
            // Check if peer is blocked
            const peer = chat.participants.find(p => p._id.toString() !== req.uid);
            if (!peer) return false;
            return !blockedSet.has(peer._id.toString());
        }).map(chat => {
            // Sanitize participants for GROUPS (or remaining items)
            const sanitizedParticipants = chat.participants.map(p => {
                if (blockedSet.has(p._id.toString())) {
                    return {
                        ...p,
                        avatar: '',
                        about: '',
                        isOnline: false,
                        lastSeen: null
                    };
                }
                return p;
            });

            return {
                ...chat,
                participants: sanitizedParticipants,
                isArchivedSelf: archivedIds.includes(chat._id.toString())
            };
        });

        res.json(enrichedChats);
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

        if (await isBlocked(req.uid, peerId)) {
            return res.status(403).json({ error: "Cannot chat with this user" });
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
        res.json(await getChatResponse(chat._id, req.uid));
    } catch (e) { res.status(500).json({ error: e.message }); }
};

const { getIO } = require('../socket'); // Import socket helper

exports.sendMessage = async (req, res) => {
    try {
        const { chatId, content, type, mediaUrl, tempId } = req.body;

        // 1. Check Block Status
        const chat = await Chat.findById(chatId);
        if (chat && !chat.isGroup) {
            const peerId = chat.participants.find(p => p.toString() !== req.uid);
            if (peerId) {
                const blocked = await isBlocked(req.uid, peerId);
                if (blocked) {
                    return res.status(403).json({ error: "You cannot send messages to this user." });
                }
            }
        }
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

        res.json(await getChatResponse(chat._id, req.uid));
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
    try {
        const { chatId } = req.body;
        const user = await User.findById(req.uid);

        const index = user.archivedChats.indexOf(chatId);
        if (index === -1) {
            user.archivedChats.push(chatId);
        } else {
            user.archivedChats.splice(index, 1);
        }

        await user.save();
        res.json({ success: true, isArchived: index === -1 });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
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
// --- Blocking (User Logic) ---
const { modifyBlock, isBlocked } = require('../utils/blockUtil');

exports.blockUser = async (req, res) => {
    try {
        const { userId } = req.body;
        if (!userId) return res.status(400).json({ error: "User ID required" });

        await modifyBlock(req.uid, userId, 'block');

        // Emit socket event to enforce immediate frontend update
        try {
            const { getIO } = require('../socket');
            const io = getIO();
            // Disconnect/Kick sockets if needed? Or just emit event.
            // Notify blocker (me) and blocked (them)?? No, usually silent.
            // But my frontend needs to know to remove them.
            // Send event to ME to refresh logic? Client should handle response.

            // To be thorough: remove socket rooms if implemented.
        } catch (e) { }

        res.json({ success: true, message: "Blocked" });
    } catch (e) { res.status(500).json({ error: e.message }); }
};

exports.unblockUser = async (req, res) => {
    try {
        const { userId } = req.body;
        const targetId = userId || req.query.userId;

        if (!targetId) return res.status(400).json({ error: "User ID required" });

        await modifyBlock(req.uid, targetId, 'unblock');
        res.json({ success: true, message: "Unblocked" });
    } catch (e) { res.status(500).json({ error: e.message }); }
};

exports.getBlockedUsers = async (req, res) => {
    try {
        const user = await User.findById(req.uid).populate('blockedUsers', 'name phone avatar');
        res.json(user.blockedUsers || []);
    } catch (e) { res.status(500).json({ error: e.message }); }
};
