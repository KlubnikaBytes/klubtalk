const mongoose = require('mongoose');
const User = require('./src/models/User');
const dotenv = require('dotenv');

dotenv.config();

const debug = async () => {
    try {
        await mongoose.connect(process.env.MONGO_URI || 'mongodb://127.0.0.1:27017/antigravity_chat');
        console.log('Connected to Mongo');

        const users = await User.find({});
        console.log(`Found ${users.length} users.`);

        users.forEach(u => {
            console.log(`User: ${u.name} (${u.firebaseUid})`);
            console.log(`Blocked Users (${u.blockedUsers.length}):`, u.blockedUsers);
            console.log('Type of blocked list:', Array.isArray(u.blockedUsers) ? 'Array' : typeof u.blockedUsers);
            if (u.blockedUsers.length > 0) {
                console.log('First Item Type:', typeof u.blockedUsers[0]);
            }
            console.log('---');
        });

        process.exit(0);
    } catch (e) {
        console.error(e);
        process.exit(1);
    }
};

debug();
