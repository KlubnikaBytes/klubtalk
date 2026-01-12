const User = require('../models/User');
const Chat = require('../models/Chat');
const Message = require('../models/Message');

exports.globalSearch = async (req, res) => {
    try {
        const { q } = req.query;
        const currentUserId = req.user.uid;

        if (!q || q.trim() === '') {
            return res.status(400).json({ error: 'Query parameter "q" is required' });
        }

        const regex = new RegExp(q, 'i'); // Case insensitive

        // 1. Search Contacts (Users)
        // Find users matching name or phone, excluding self
        const contacts = await User.find({
            $and: [
                { firebaseUid: { $ne: currentUserId } },
                {
                    $or: [
                        { name: regex },
                        { phone: regex }
                    ]
                }
            ]
        }).select('firebaseUid name phone avatar about').limit(10);

        // 2. Search Chats (Groups or Direct Names if implemented)
        // For groups, search groupName.
        // For DMs, we relies on Contacts search, but we can also check if a chat exists.
        // Let's search Groups primarily here.
        // Also ensure user is a participant.
        const chats = await Chat.find({
            participants: currentUserId,
            isGroup: true,
            groupName: regex
        }).select('_id groupName groupPhoto participants').limit(10);

        // 3. Search Messages
        // Find messages containing the text, where user is a participant of the chat.
        // This is complex:
        // a) Find all chatIds where user is participant.
        // b) Search messages in those chats.

        const userChats = await Chat.find({ participants: currentUserId }).select('_id');
        const userChatIds = userChats.map(c => c._id);

        const messages = await Message.find({
            chatId: { $in: userChatIds },
            content: regex,
            type: 'text' // Only search text messages
        })
            .sort({ timestamp: -1 })
            .limit(20)
            .populate('senderId', 'name avatar firebaseUid')
            .populate('chatId', 'isGroup groupName participants');

        // Group messages by chat for better UI
        // But for global search, a flat list or grouped by chat is fine.
        // WhatsApp shows grouping: "Messages" -> list.
        // We will return flat list and let frontend group if needed, 
        // OR better: we format it for frontend.

        // Let's format messages to be useful
        const formattedMessages = messages.map(m => {
            const chat = m.chatId;
            let title = '';
            let subtitle = '';

            if (chat.isGroup) {
                title = chat.groupName;
                subtitle = `${m.senderId.name}: ${m.content}`;
            } else {
                // For DM, title is the other person.
                // We need to find the other person from participants.
                // Since we don't have full participant details populated here efficiently (only ids in chat probably?),
                // we might rely on sender if incoming, or 'You' if outgoing?
                // Actually, for DM search results, it usually shows the chat partner name.
                // Optimization: We populated chatId, but chatId.participants is just array of Strings (IDs).
                // We need to resolve them?
                // Let's keep it simple: Frontend handles title display if we send Chat Object.

                // If I am sender: "You: ..." -> Chat Title: Receiver
                // If they are sender: "Name: ..." -> Chat Title: Sender
            }
            return m;
        });

        res.json({
            contacts,
            chats,
            messages
        });

    } catch (error) {
        console.error('Global Search Error:', error);
        res.status(500).json({ error: 'Search failed' });
    }
};

exports.chatSearch = async (req, res) => {
    try {
        const { chatId } = req.params;
        const { q } = req.query;

        if (!chatId) return res.status(400).json({ error: 'Chat ID required' });
        if (!q || q.trim() === '') return res.status(400).json({ error: 'Query required' });

        const regex = new RegExp(q, 'i');

        const messages = await Message.find({
            chatId: chatId,
            type: 'text',
            content: regex
        })
            .sort({ timestamp: -1 }) // Newest first? Or Oldest? WhatsApp navigates up/down. default usually context.
            // We return matches with their IDs so frontend can jump to them.
            .select('_id content timestamp senderId')
            .limit(100); // Limit reasonable amount

        res.json({ messages });

    } catch (error) {
        console.error('Chat Search Error:', error);
        res.status(500).json({ error: 'Chat search failed' });
    }
};
