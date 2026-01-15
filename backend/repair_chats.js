const mongoose = require('mongoose');
const dotenv = require('dotenv');
const Chat = require('./src/models/Chat');

dotenv.config();

const cleanChats = async () => {
    try {
        await mongoose.connect(process.env.MONGO_URI, {
            useNewUrlParser: true,
            useUnifiedTopology: true
        });
        console.log('✅ Connected to MongoDB');

        // Find chats where participants array contains null
        const brokenChats = await Chat.find({ participants: null });
        console.log(`Found ${brokenChats.length} broken chats.`);

        if (brokenChats.length > 0) {
            const result = await Chat.deleteMany({ participants: null });
            console.log(`🗑️ Deleted ${result.deletedCount} broken chats.`);
        } else {
            console.log('✨ No broken chats found.');
        }

        process.exit(0);
    } catch (e) {
        console.error('❌ Error:', e);
        process.exit(1);
    }
};

cleanChats();
