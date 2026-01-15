const Contact = require('../models/Contact');
const User = require('../models/User');

// Add a new contact
const addContact = async (req, res) => {
    const { name, phone } = req.body;
    const currentUserId = req.user.uid;

    if (!name || !phone) {
        return res.status(400).json({ error: 'Name and phone are required' });
    }

    console.log(`[ADD CONTACT] Request from ${currentUserId}: Name=${name}, Phone=${phone}`);

    try {
        // 1. Normalize Phone Logic
        const digitsOnly = phone.replace(/\D/g, '');
        const variants = [
            phone,
            digitsOnly,
            '+' + digitsOnly,
            `+${digitsOnly}`
        ];

        console.log(`[ADD CONTACT] Checking user variants: ${JSON.stringify(variants)}`);

        // 2. Check if this user exists in our app
        const registeredUser = await User.findOne({
            phone: { $in: variants }
        });

        const isRegistered = !!registeredUser;
        const linkedUserId = registeredUser ? registeredUser.firebaseUid : null;

        console.log(`[ADD CONTACT] Match found: ${isRegistered} (${linkedUserId})`);

        // 3. Upsert Contact
        const storedPhone = '+' + digitsOnly; // Standardize to +123456

        const contact = await Contact.findOneAndUpdate(
            { ownerUserId: currentUserId, phone: storedPhone },
            {
                name: name,
                phone: storedPhone,
                isRegistered: isRegistered,
                linkedUserId: linkedUserId,
                createdAt: new Date()
            },
            { new: true, upsert: true, setDefaultsOnInsert: true }
        );

        // 4. Auto-Create Chat (WhatsApp Logic)
        if (isRegistered && linkedUserId) {
            const Chat = require('../models/Chat');

            // Re-use the EXACT logic from chatController to ensure we find the same chat
            // Ensure we sort partipants to find the canonical chat
            const participants = [currentUserId, linkedUserId].sort();

            let chat = await Chat.findOne({
                isGroup: false,
                participants: { $all: participants, $size: 2 }
            });

            if (!chat) {
                console.log(`[ADD CONTACT] Auto-creating chat for ${currentUserId} and ${linkedUserId}`);
                chat = new Chat({
                    participants: participants, // Uses Sorted Participants
                    isGroup: false,
                    createdAt: new Date(),
                    lastMessageTime: new Date(),
                    unreadCount: {
                        [currentUserId]: 0,
                        [linkedUserId]: 0
                    },
                    lastMessage: {
                        text: 'You added this contact',
                        type: 'system',
                        timestamp: new Date(),
                        senderId: 'system'
                    }
                });
                await chat.save();
            }
        }

        res.status(200).json({ message: 'Contact saved', contact });

    } catch (error) {
        console.error('Add Contact Error:', error);
        res.status(500).json({ error: 'Failed to add contact' });
    }
};

// Get My Contacts
const getMyContacts = async (req, res) => {
    const currentUserId = req.user.uid;
    try {
        // Sort by name
        const contacts = await Contact.find({ ownerUserId: currentUserId }).sort({ name: 1 });
        res.status(200).json(contacts);
    } catch (error) {
        res.status(500).json({ error: 'Failed to fetch contacts' });
    }
};

// Helper: Normalize phone to +91XXXXXXXXXX
const normalizePhone = (phone) => {
    let p = phone.replace(/\D/g, ''); // Remove non-digits
    if (p.length === 10) return '+91' + p;
    if (p.length === 12 && p.startsWith('91')) return '+' + p;
    if (p.length > 10 && p.startsWith('0')) return '+91' + p.substring(1);
    return '+' + p; // Fallback
};

// Sync Contacts
const syncContacts = async (req, res) => {
    try {
        const { contacts } = req.body; // Array of strings
        if (!contacts || !Array.isArray(contacts)) {
            return res.status(400).json({ message: 'Contacts list required' });
        }

        const normalizedInput = contacts.map(c => normalizePhone(c));

        // Find registered users with these numbers
        const registeredUsers = await User.find({
            phone: { $in: normalizedInput }
        }).select('name phone avatar about isOnline lastSeen');

        const registeredPhones = new Set(registeredUsers.map(u => u.phone));

        // Identify unregistered contacts (phones from input that aren't in registeredUsers)
        // We return the ORIGINAL input or Normalized? Normalized is better for future invites.
        const unregisteredContacts = normalizedInput.filter(p => !registeredPhones.has(p));

        res.json({
            registered: registeredUsers,
            unregistered: unregisteredContacts
        });

    } catch (error) {
        console.error('Sync Contacts Error:', error);
        res.status(500).json({ message: 'Failed to sync contacts' });
    }
};

module.exports = {
    addContact,
    getMyContacts,
    syncContacts
};
