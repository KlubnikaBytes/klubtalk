// Quick check of user block status
const mongoose = require('mongoose');
require('dotenv').config();

async function checkUsers() {
    await mongoose.connect(process.env.MONGO_URI || 'mongodb://127.0.0.1:27017/antigravity_chat');

    const User = mongoose.model('User', new mongoose.Schema({}, { strict: false }));

    const users = await User.find(
        { phone: { $in: ['+918910864649', '+916205857707'] } },
        { phone: 1, blockedUsers: 1, blockedByUsers: 1 }
    );

    console.log('Current user status:\n');
    users.forEach(u => {
        console.log(`Phone: ${u.phone}`);
        console.log(`  _id: ${u._id}`);
        console.log(`  blockedUsers: [${u.blockedUsers?.join(', ') || 'none'}]`);
        console.log(`  blockedByUsers: [${u.blockedByUsers?.join(', ') || 'none'}]\n`);
    });

    await mongoose.disconnect();
}

checkUsers().catch(console.error);
