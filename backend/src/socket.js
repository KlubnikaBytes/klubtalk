const socketIo = require('socket.io');
const jwt = require('jsonwebtoken');
const User = require('./models/User');
const Message = require('./models/Message');
const Chat = require('./models/Chat');
const Call = require('./models/Call'); // Preserving Call model usage

let io;
const onlineUsers = new Map(); // userId -> socketId

exports.init = (server) => {
    io = socketIo(server, {
        cors: {
            origin: "*", // Allow all for now, lock down in prod
            methods: ["GET", "POST"]
        }
    });

    // Auth Middleware
    io.use(async (socket, next) => {
        try {
            const token = socket.handshake.auth.token;
            if (!token) return next(new Error('Authentication error'));

            const decoded = jwt.verify(token, process.env.JWT_SECRET || 'fallback_secret_do_not_use_in_prod');
            socket.uid = decoded.uid;
            next();
        } catch (e) {
            next(new Error('Authentication error'));
        }
    });

    io.on('connection', async (socket) => {
        console.log(`User connected: ${socket.uid}`);
        onlineUsers.set(socket.uid, socket.id);

        // Auto-join personal room (User ID)
        socket.join(socket.uid);

        // Set User Online
        await User.findByIdAndUpdate(socket.uid, { isOnline: true, lastSeen: null });
        socket.broadcast.emit('user_status', { userId: socket.uid, isOnline: true });

        // --- Offline Delivery Logic ---
        // Find messages sent to this user that are still 'sent'
        try {
            // We need to find valid chats where this user is a participant
            // Then find messages in those chats where sender != user AND status == 'sent'
            // Simpler: Just find all messages where sender != user (we don't have recipient field in Message, only chatId)
            // We have to query Aggregation or 2-step.
            // 1. Get My Chats
            const chats = await Chat.find({ participants: socket.uid });
            const chatIds = chats.map(c => c._id);

            // 2. Find Pending Messages in these chats
            const pendingMessages = await Message.find({
                chatId: { $in: chatIds },
                senderId: { $ne: socket.uid },
                status: 'sent'
            });

            if (pendingMessages.length > 0) {
                // Update DB
                await Message.updateMany(
                    { _id: { $in: pendingMessages.map(m => m._id) } },
                    { status: 'delivered' }
                );

                // Emit to Senders
                pendingMessages.forEach(msg => {
                    // Notify sender that their message was delivered
                    if (onlineUsers.has(msg.senderId.toString())) {
                        io.to(msg.senderId.toString()).emit('message_delivered', {
                            messageId: msg._id,
                            userId: socket.uid,
                            chatId: msg.chatId
                        });
                    }
                });
            }
        } catch (e) {
            console.error("Offline Delivery Error:", e);
        }

        // --- EVENTS ---

        // 1. Join Chat Room (optional)
        socket.on('join_chat', (chatId) => {
            socket.join(chatId);
            console.log(`User ${socket.uid} joined chat ${chatId}`);
        });

        // 2. Send Message
        socket.on('send_message', async (data) => {
            try {
                const { chatId, content, type, mediaUrl, thumbnailUrl, tempId } = data;

                const message = await Message.create({
                    chatId,
                    senderId: socket.uid,
                    content,
                    type,
                    mediaUrl,
                    thumbnailUrl,
                    status: 'sent'
                });

                // Update Chat's lastMessage
                await Chat.findByIdAndUpdate(chatId, {
                    lastMessage: message._id,
                    updatedAt: new Date()
                });

                // Emit to the Chat Room (Everyone in the chat sees it instantly)
                const msgObj = message.toObject();
                if (tempId) msgObj.tempId = tempId;
                io.to(chatId).emit('new_message', msgObj);

                // Ack back to sender (confirm 'sent' status / update tempId)
                socket.emit('message_sent', { tempId: tempId, message });

                // --- Delivery Status Update (Server-side Hack for "Instant" delivery if online) ---
                // Ideally client sends ACK, but we do this for simplicity as per previous logic.
                await exports.notifyDelivery(io, message, chatId, tempId);

            } catch (e) {
                console.error("Send Message Error", e);
            }
        });

        // 3. Mark Messages as Seen
        socket.on('message_seen', async (data) => {
            try {
                const { chatId } = data;
                // Find messages in this chat NOT from me, and NOT seen
                const result = await Message.updateMany(
                    { chatId: chatId, senderId: { $ne: socket.uid }, status: { $ne: 'seen' } },
                    { status: 'seen' }
                );

                if (result.matchedCount > 0) {
                    // Emit to Room (everyone knows messages are seen)
                    // socket.to(chatId) excludes sender, but 'seen' is usually relevant for OTHERS.
                    // The person who read it (me) knows I read it. The sender needs to know.
                    io.to(chatId).emit('messages_seen_update', {
                        chatId,
                        userId: socket.uid
                    });
                }
            } catch (e) {
                console.error("Message Seen Error", e);
            }
        });

        // 4. Typing
        socket.on('typing', (data) => {
            // Broadcast to room (exclude sender)
            socket.to(data.chatId).emit('typing', { chatId: data.chatId, userId: socket.uid });
        });

        socket.on('stop_typing', (data) => {
            // Broadcast to room (exclude sender)
            socket.to(data.chatId).emit('stop_typing', { chatId: data.chatId, userId: socket.uid });
        });

        // --- WebRTC Signaling ---
        socket.on("join-user", (userId) => {
            // Already joined in connection
        });

        socket.on("call-user", async (data) => {
            console.log(`Call initiated from ${data.from} to ${data.to}`);
            io.to(data.to).emit("incoming-call", {
                from: data.from,
                callType: data.callType,
                offer: data.offer
            });

            try {
                const newCall = new Call({ from: data.from, to: data.to, type: data.callType });
                await newCall.save();
            } catch (e) { console.error("Call Log Error:", e); }
        });

        socket.on("accept-call", (data) => {
            io.to(data.to).emit("call-accepted", { answer: data.answer });
        });

        socket.on("reject-call", (data) => {
            io.to(data.to).emit("call-rejected");
        });

        socket.on("end-call", (data) => {
            io.to(data.to).emit("call-ended");
        });

        socket.on("ice-candidate", (data) => {
            io.to(data.to).emit("ice-candidate", { candidate: data.candidate });
        });

        // 5. Check Online Status (Initial Load)
        socket.on('check_user_online', (userId) => {
            const isOnline = onlineUsers.has(userId);
            socket.emit('user_status', { userId: userId, isOnline: isOnline });
        });

        // 6. Disconnect
        socket.on('disconnect', async () => {
            console.log(`User disconnected: ${socket.uid}`);
            if (onlineUsers.get(socket.uid) === socket.id) {
                onlineUsers.delete(socket.uid);
                await User.findByIdAndUpdate(socket.uid, { isOnline: false, lastSeen: new Date() });
                socket.broadcast.emit('user_status', { userId: socket.uid, isOnline: false, lastSeen: new Date() });
            }
        });
    });
};

// Helper to notify delivery (Shared with REST Controller)
exports.notifyDelivery = async (io, message, chatId, tempId = null) => {
    try {
        const chat = await Chat.findById(chatId);
        if (chat && chat.participants) {
            chat.participants.forEach(pId => {
                const pIdStr = pId.toString();
                if (pIdStr === message.senderId.toString()) return; // Skip self

                // If recipient is online, mark as delivered immediately
                if (onlineUsers.has(pIdStr)) {
                    // Update DB
                    Message.findByIdAndUpdate(message._id, { status: 'delivered' }).exec();
                    // Notify Sender (using their specific socket room or just by user ID room)
                    // We emit to the SENDER'S room (User ID) so they get the update
                    io.to(message.senderId.toString()).emit('message_delivered', {
                        messageId: message._id,
                        userId: pIdStr,
                        chatId: chatId,
                        tempId: tempId // Include tempId for optimistic matching
                    });
                }
            });
        }
    } catch (e) {
        console.error("Notify Delivery Error:", e);
    }
};

exports.getIO = () => {
    if (!io) throw new Error("Socket.io not initialized!");
    return io;
};
