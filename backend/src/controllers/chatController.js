const { db, admin } = require('../config/firebase');

// Create New Chat (Private)
exports.createPrivateChat = async (req, res) => {
    const { participantId } = req.body;
    const currentUserId = req.user.uid;

    if (!participantId) return res.status(400).json({ error: 'Missing participantId' });

    try {
        const participants = [currentUserId, participantId].sort();
        const chatId = participants.join('_');

        const chatRef = db.collection('chats').doc(chatId);
        const chatDoc = await chatRef.get();

        if (!chatDoc.exists) {
            await chatRef.set({
                participants,
                lastMessage: '',
                lastMessageTime: admin.firestore.FieldValue.serverTimestamp(),
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                type: 'private'
            });
        }

        res.status(200).json({ chatId, message: 'Chat retrieved/created' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

// Create Group Chat
exports.createGroupChat = async (req, res) => {
    const { groupName, participants } = req.body; // participants = list of UIDs *excluding* creator
    const currentUserId = req.user.uid;

    if (!groupName || !participants) return res.status(400).json({ error: 'Missing fields' });

    try {
        const allParticipants = [...participants, currentUserId];

        const chatRef = db.collection('chats').doc();
        await chatRef.set({
            isGroup: true,
            groupName,
            createdBy: currentUserId,
            participants: allParticipants,
            lastMessage: 'Group created',
            lastMessageTime: admin.firestore.FieldValue.serverTimestamp(),
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            type: 'group'
        });

        res.status(201).json({ chatId: chatRef.id, message: 'Group created successfully' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

// Get My Chats
exports.getMyChats = async (req, res) => {
    const currentUserId = req.user.uid;
    try {
        // Note: Simple query. For real scalability, better to have a 'users/{uid}/chats' subcollection
        // or rely on 'participants' array-contains filter.
        const snapshot = await db.collection('chats')
            .where('participants', 'array-contains', currentUserId)
            .orderBy('lastMessageTime', 'desc')
            .get();

        const chats = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
        res.status(200).json(chats);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};
