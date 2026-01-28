// Unblock Test Users Script - Simple Version
const mongoose = require('mongoose');
require('dotenv').config();

const MONGO_URI = process.env.MONGO_URI || 'mongodb://127.0.0.1:27017/antigravity_chat';

async function unblockTestUsers() {
    try {
        console.log('🔧 Connecting to MongoDB...');
        await mongoose.connect(MONGO_URI);
        console.log('✅ Connected to MongoDB\n');

        const User = mongoose.model('User', new mongoose.Schema({}, { strict: false }));

        // Your test user IDs (as strings, mongoose will convert)
        const user1Id = '695cc558092075648c7755d0';
        const user2Id = '69687c4ea438fbaf269a4b01';

        console.log('🔓 Unblocking users from each other...\n');

        // Remove user2 from user1's blockedUsers
        const result1 = await User.updateOne(
            { _id: user1Id },
            { $pull: { blockedUsers: user2Id } }
        );
        console.log(`   User 1 (649): Removed ${user2Id} from blockedUsers`);
        console.log(`   Modified: ${result1.modifiedCount} document(s)\n`);

        // Remove user1 from user2's blockedByUsers
        const result2 = await User.updateOne(
            { _id: user2Id },
            { $pull: { blockedByUsers: user1Id } }
        );
        console.log(`   User 2 (707): Removed ${user1Id} from blockedByUsers`);
        console.log(`   Modified: ${result2.modifiedCount} document(s)\n`);

        // Also clean any reverse blocks just in case
        await User.updateOne(
            { _id: user2Id },
            { $pull: { blockedUsers: user1Id } }
        );

        await User.updateOne(
            { _id: user1Id },
            { $pull: { blockedByUsers: user2Id } }
        );

        console.log('✅ Unblocking complete!\n');

        // Show final state
        console.log('📊 Final state:\n');

        const user1 = await User.findById(user1Id);
        if (user1) {
            console.log('User 1: +918910864649');
            console.log(`   _id: ${user1._id}`);
            console.log(`   blockedUsers: [${user1.blockedUsers?.join(', ') || 'none'}]`);
            console.log(`   blockedByUsers: [${user1.blockedByUsers?.join(', ') || 'none'}]\n`);
        }

        const user2 = await User.findById(user2Id);
        if (user2) {
            console.log('User 2: +916205857707');
            console.log(`   _id: ${user2._id}`);
            console.log(`   blockedUsers: [${user2.blockedUsers?.join(', ') || 'none'}]`);
            console.log(`   blockedByUsers: [${user2.blockedByUsers?.join(', ') || 'none'}]\n`);
        }

        console.log('✅ Done!');
        console.log('\n📝 Next steps:');
        console.log('   1. Restart your backend server (Ctrl+C then npm start)');
        console.log('   2. Restart your Flutter app');
        console.log('   3. Pull to refresh in New Chat screen');
        console.log('   4. Both users should now appear in each other\'s contact list!\n');

    } catch (error) {
        console.error('❌ Error:', error.message);
        console.error('Stack:', error.stack);
    } finally {
        await mongoose.disconnect();
        console.log('👋 Disconnected from MongoDB');
    }
}

unblockTestUsers();
