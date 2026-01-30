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
        .populate('groupAdmins', 'name phone') // Populate admins
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

// Helper: Check if user is group admin
const isGroupAdmin = (chat, userId) => {
    if (!chat.isGroup) return false;
    // Check old single admin or new array
    if (chat.groupAdmin && chat.groupAdmin.toString() === userId) return true;
    if (chat.groupAdmins && chat.groupAdmins.some(a => a.toString() === userId)) return true;
    return false;
};

// Helper: Check permission
const hasPermission = (chat, userId, permissionKey) => {
    // If admin, always true
    if (isGroupAdmin(chat, userId)) return true;
    // If permission is 'all', true
    if (chat[permissionKey] === 'all') return true;
    return false;
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

        const enrichedChats = chats.map(chat => {
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

            // Ensure UID is string for Map access
            const uidStr = req.uid.toString();
            const unread = (chat.unreadCounts && chat.unreadCounts[uidStr]) || 0;

            // DEBUG: Log if we have unread counts but they aren't showing
            if (chat.unreadCounts && Object.keys(chat.unreadCounts).length > 0) {
                console.log(`[DEBUG_CHAT] Chat ${chat._id}: UnreadMap=${JSON.stringify(chat.unreadCounts)}, MyUID=${uidStr}, Result=${unread}`);
            }

            return {
                ...chat,
                participants: sanitizedParticipants,
                isArchivedSelf: archivedIds.includes(chat._id.toString()),
                unreadCount: unread
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


        // Reset Unread Count for ME
        const updateKey = `unreadCounts.${req.uid}`;
        await Chat.findByIdAndUpdate(chatId, { $set: { [updateKey]: 0 } });

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

        // 2. Check Group Message Permission
        if (chat && chat.isGroup && chat.sendMessagePermission === 'admins') {
            const isAdmin = chat.groupAdmins?.some(adminId => adminId.toString() === req.uid) ||
                chat.groupAdmin?.toString() === req.uid;
            if (!isAdmin) {
                return res.status(403).json({ error: "Only admins can send messages in this group." });
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

        // Prepare Unread Increment
        // We need to increment for ALL participants EXCEPT sender
        const chatDoc = await Chat.findById(chatId);
        if (chatDoc) {
            const recipients = chatDoc.participants.filter(p => p.toString() !== req.uid);
            const incUpdate = {};
            recipients.forEach(r => {
                incUpdate[`unreadCounts.${r.toString()}`] = 1;
            });

            console.log(`[DEBUG_MSG] Chat ${chatId}: Incrementing unread for`, JSON.stringify(incUpdate));

            const upRes = await Chat.findByIdAndUpdate(chatId, {
                lastMessage: message._id,
                updatedAt: new Date(),
                $inc: incUpdate // Atomic increment
            }, { new: true });

            console.log(`[DEBUG_MSG] Chat ${chatId} Updated. New Counts:`, JSON.stringify(upRes.unreadCounts));
        }

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

        // --- Push Notification for Offline Recipients ---
        try {
            const { sendMessageNotification } = require('../utils/notification_helper');
            const { getIO } = require('../socket');
            const onlineUsers = getIO()._onlineUsers || new Map(); // Access online users map

            // Get all participants except sender
            const recipients = chat.participants.filter(p => p.toString() !== req.uid);

            for (const recipientId of recipients) {
                // Check if recipient is offline
                if (!onlineUsers.has(recipientId.toString())) {
                    // Get sender info
                    const sender = await User.findById(req.uid).select('name');
                    const senderName = sender?.name || 'Someone';

                    // Send push notification
                    await sendMessageNotification(
                        recipientId.toString(),
                        senderName,
                        content || 'Media',
                        chatId,
                        req.uid
                    );
                }
            }
        } catch (notifErr) {
            console.error("Push notification error:", notifErr);
            // Don't fail the request if notification fails
        }

        res.json(message);
    } catch (e) { res.status(500).json({ error: e.message }); }
};

// 🎯 NEW: HTTP ACK for Background Delivery
exports.ackMessage = async (req, res) => {
    try {
        const { messageId } = req.params;
        const msg = await Message.findById(messageId);
        if (!msg) return res.status(404).json({ error: "Message not found" });

        // Only update if I am receiver
        if (msg.senderId.toString() !== req.uid && msg.status !== 'seen') {
            await Message.findByIdAndUpdate(messageId, { status: 'delivered' });

            // Try to socket emit to sender
            try {
                const { getIO } = require('../socket');
                const io = getIO();
                const onlineUsers = require('../socket').getOnlineUsers(); // Need to export this or check logic
                // Actually relying on io.to(uid) is enough if they are in their room.

                io.to(msg.senderId.toString()).emit('message_delivered', {
                    messageId: msg._id,
                    chatId: msg.chatId,
                    userId: req.uid
                });
            } catch (sErr) {
                console.log("Socket emit failed in ACK:", sErr);
            }
        }
        res.json({ success: true });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
};

// --- Groups ---
exports.createGroupChat = async (req, res, next) => {
    console.log("Creating Group Chat Request Body:", JSON.stringify(req.body));
    try {
        const { name, participants, avatar, description } = req.body;

        // participants is array of IDs. Add self.
        // Validate req.uid
        if (!req.uid) throw new Error("User ID missing from request");

        const allParticipants = [...new Set([...(participants || []), req.uid])];

        console.log("Creating Chat Document...");
        const chat = await Chat.create({
            isGroup: true,
            groupName: name,
            groupDescription: description || '',
            groupAdmin: req.uid,
            groupAdmins: [req.uid],
            groupAvatar: avatar,
            participants: allParticipants,
            createdBy: req.uid
        });

        console.log("Chat Created ID:", chat._id);
        const fullChat = await getChatResponse(chat._id, req.uid);
        res.json(fullChat);
    } catch (e) {
        console.error("Create Group Error Stack:", e);
        res.status(500).json({ error: e.message || "Failed to create group" });
    }
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

// --- Group Management ---



// Update Group Info (name, description, avatar)
exports.updateGroupInfo = async (req, res) => {
    try {
        const { chatId } = req.params;
        const { name, description, avatar } = req.body;

        const chat = await Chat.findById(chatId);
        if (!chat || !chat.isGroup) {
            return res.status(404).json({ error: 'Group not found' });
        }

        // Check permission
        const canEdit = chat.editInfoPermission === 'all' || isGroupAdmin(chat, req.uid);
        if (!canEdit) {
            return res.status(403).json({ error: 'You do not have permission to edit group info' });
        }

        if (name) chat.groupName = name;
        if (description !== undefined) chat.groupDescription = description;
        if (avatar !== undefined) chat.groupAvatar = avatar;

        await chat.save();
        res.json(await getChatResponse(chat._id, req.uid));
    } catch (e) { res.status(500).json({ error: e.message }); }
};

// Update Group Permissions (admin only)
exports.updateGroupPermissions = async (req, res) => {
    try {
        const { chatId } = req.params;
        const { editInfoPermission, sendMessagePermission, addParticipantsPermission } = req.body;

        const chat = await Chat.findById(chatId);
        if (!chat || !chat.isGroup) {
            return res.status(404).json({ error: 'Group not found' });
        }

        // Only admins can update permissions
        if (!isGroupAdmin(chat, req.uid)) {
            return res.status(403).json({ error: 'Only admins can update permissions' });
        }

        if (editInfoPermission) chat.editInfoPermission = editInfoPermission;
        if (sendMessagePermission) chat.sendMessagePermission = sendMessagePermission;
        if (addParticipantsPermission) chat.addParticipantsPermission = addParticipantsPermission;

        await chat.save();
        res.json(await getChatResponse(chat._id, req.uid));
    } catch (e) { res.status(500).json({ error: e.message }); }
};

// Add Participant
exports.addGroupParticipant = async (req, res) => {
    try {
        const { chatId } = req.params;
        const { userId } = req.body;

        const chat = await Chat.findById(chatId);
        if (!chat || !chat.isGroup) {
            return res.status(404).json({ error: 'Group not found' });
        }

        // Check permission
        const canAdd = chat.addParticipantsPermission === 'all' || isGroupAdmin(chat, req.uid);
        if (!canAdd) {
            return res.status(403).json({ error: 'You do not have permission to add participants' });
        }

        // Add participant if not already in group
        if (!chat.participants.includes(userId)) {
            chat.participants.push(userId);
            await chat.save();
        }

        res.json(await getChatResponse(chat._id, req.uid));
    } catch (e) { res.status(500).json({ error: e.message }); }
};

// Update Group Info (Name, Description, Avatar)
exports.updateGroupInfo = async (req, res) => {
    try {
        const { chatId } = req.params;
        const { name, description, avatar } = req.body;
        const chat = await Chat.findById(chatId);
        if (!chat || !chat.isGroup) return res.status(404).json({ error: 'Group not found' });

        if (!hasPermission(chat, req.uid, 'editInfoPermission')) {
            return res.status(403).json({ error: 'Not authorized to edit group info' });
        }

        if (name) chat.groupName = name;
        if (description !== undefined) chat.groupDescription = description;
        if (avatar) chat.groupAvatar = avatar;

        await chat.save();
        res.json(await getChatResponse(chat._id, req.uid));
    } catch (e) { res.status(500).json({ error: e.message }); }
};

// Update Permissions (Admin Only)
exports.updateGroupPermissions = async (req, res) => {
    try {
        const { chatId } = req.params;
        const { editInfoPermission, sendMessagePermission, addParticipantsPermission } = req.body;

        const chat = await Chat.findById(chatId);
        if (!chat || !chat.isGroup) return res.status(404).json({ error: 'Group not found' });

        if (!isGroupAdmin(chat, req.uid)) {
            return res.status(403).json({ error: 'Only admins can change permissions' });
        }

        if (editInfoPermission) chat.editInfoPermission = editInfoPermission;
        if (sendMessagePermission) chat.sendMessagePermission = sendMessagePermission;
        if (addParticipantsPermission) chat.addParticipantsPermission = addParticipantsPermission;

        await chat.save();
        res.json(await getChatResponse(chat._id, req.uid));
    } catch (e) { res.status(500).json({ error: e.message }); }
};

// Add Participant
exports.addGroupParticipant = async (req, res) => {
    try {
        const { chatId } = req.params;
        const { userId } = req.body;
        const chat = await Chat.findById(chatId);
        if (!chat || !chat.isGroup) return res.status(404).json({ error: 'Group not found' });

        if (!hasPermission(chat, req.uid, 'addParticipantsPermission')) {
            return res.status(403).json({ error: 'Not authorized to add participants' });
        }

        // Add if not exists
        if (!chat.participants.includes(userId)) {
            chat.participants.push(userId);
            await chat.save();
        }
        res.json(await getChatResponse(chat._id, req.uid));
    } catch (e) { res.status(500).json({ error: e.message }); }
};

// Remove Participant (admin only)
exports.removeGroupParticipant = async (req, res) => {
    try {
        const { chatId, userId } = req.params;

        const chat = await Chat.findById(chatId);
        if (!chat || !chat.isGroup) {
            return res.status(404).json({ error: 'Group not found' });
        }

        // Only admins can remove participants
        if (!isGroupAdmin(chat, req.uid)) {
            return res.status(403).json({ error: 'Only admins can remove participants' });
        }

        // Remove from participants
        chat.participants = chat.participants.filter(p => p.toString() !== userId);

        // Remove from admins if they were admin
        if (chat.groupAdmins) {
            chat.groupAdmins = chat.groupAdmins.filter(a => a.toString() !== userId);
        }

        await chat.save();
        res.json(await getChatResponse(chat._id, req.uid));
    } catch (e) { res.status(500).json({ error: e.message }); }
};

// Promote to Admin
exports.promoteToAdmin = async (req, res) => {
    try {
        const { chatId } = req.params;
        const { userId } = req.body;

        const chat = await Chat.findById(chatId);
        if (!chat || !chat.isGroup) {
            return res.status(404).json({ error: 'Group not found' });
        }

        // Only admins can promote
        if (!isGroupAdmin(chat, req.uid)) {
            return res.status(403).json({ error: 'Only admins can promote members' });
        }

        // Initialize groupAdmins if not exists
        if (!chat.groupAdmins) {
            chat.groupAdmins = [chat.groupAdmin];
        }

        // Add to admins if not already
        if (!chat.groupAdmins.some(a => a.toString() === userId)) {
            chat.groupAdmins.push(userId);
            await chat.save();
        }

        res.json(await getChatResponse(chat._id, req.uid));
    } catch (e) { res.status(500).json({ error: e.message }); }
};

// Demote Admin
exports.demoteAdmin = async (req, res) => {
    try {
        const { chatId, userId } = req.params;

        const chat = await Chat.findById(chatId);
        if (!chat || !chat.isGroup) {
            return res.status(404).json({ error: 'Group not found' });
        }

        // Only admins can demote
        if (!isGroupAdmin(chat, req.uid)) {
            return res.status(403).json({ error: 'Only admins can demote admins' });
        }

        // Prevent removing last admin
        if (chat.groupAdmins && chat.groupAdmins.length <= 1) {
            return res.status(400).json({ error: 'Cannot remove the last admin' });
        }

        // Remove from admins
        if (chat.groupAdmins) {
            chat.groupAdmins = chat.groupAdmins.filter(a => a.toString() !== userId);
            await chat.save();
        }

        res.json(await getChatResponse(chat._id, req.uid));
    } catch (e) { res.status(500).json({ error: e.message }); }
};

// Leave Group
exports.leaveGroup = async (req, res) => {
    try {
        const { chatId } = req.params;

        const chat = await Chat.findById(chatId);
        if (!chat || !chat.isGroup) {
            return res.status(404).json({ error: 'Group not found' });
        }

        const isAdmin = isGroupAdmin(chat, req.uid);

        // If last admin, transfer to another participant
        if (isAdmin && chat.groupAdmins && chat.groupAdmins.length === 1 && chat.participants.length > 1) {
            const newAdmin = chat.participants.find(p => p.toString() !== req.uid);
            if (newAdmin) {
                chat.groupAdmins = [newAdmin];
                chat.groupAdmin = newAdmin;
            }
        }

        // Remove from participants
        chat.participants = chat.participants.filter(p => p.toString() !== req.uid);

        // Remove from admins
        if (chat.groupAdmins) {
            chat.groupAdmins = chat.groupAdmins.filter(a => a.toString() !== req.uid);
        }

        await chat.save();
        res.json({ success: true, message: 'Left group successfully' });
    } catch (e) { res.status(500).json({ error: e.message }); }
};
