// Database Cleanup Script - Fix Corrupted blockedUsers Data
// Run this once to clean up empty strings and invalid IDs

const mongoose = require('mongoose');
require('dotenv').config();

const MONGO_URI = process.env.MONGO_URI || 'mongodb://127.0.0.1:27017/antigravity_chat';

async function cleanupDatabase() {
    try {
        console.log('🔧 Connecting to MongoDB...');
        await mongoose.connect(MONGO_URI);
        console.log('✅ Connected to MongoDB\n');

        const User = mongoose.model('User', new mongoose.Schema({}, { strict: false }));

        // Step 1: Remove empty strings from blockedUsers
        console.log('📋 Step 1: Removing empty strings from blockedUsers...');
        const result1 = await User.updateMany(
            {},
            { $pull: { blockedUsers: "" } }
        );
        console.log(`   ✅ Modified ${result1.modifiedCount} documents\n`);

        // Step 2: Remove empty strings from blockedByUsers
        console.log('📋 Step 2: Removing empty strings from blockedByUsers...');
        const result2 = await User.updateMany(
            {},
            { $pull: { blockedByUsers: "" } }
        );
        console.log(`   ✅ Modified ${result2.modifiedCount} documents\n`);

        // Step 3: Remove null values
        console.log('📋 Step 3: Removing null values...');
        const result3 = await User.updateMany(
            {},
            {
                $pull: {
                    blockedUsers: null,
                    blockedByUsers: null
                }
            }
        );
        console.log(`   ✅ Modified ${result3.modifiedCount} documents\n`);

        // Step 4: Show current state of test users
        console.log('📊 Current state of your test users:\n');

        const user1 = await User.findOne({ phone: '+918910864649' });
        if (user1) {
            console.log('User 1: +918910864649');
            console.log(`   _id: ${user1._id}`);
            console.log(`   blockedUsers: [${user1.blockedUsers?.join(', ') || 'none'}]`);
            console.log(`   blockedByUsers: [${user1.blockedByUsers?.join(', ') || 'none'}]\n`);
        }

        const user2 = await User.findOne({ phone: '+916205857707' });
        if (user2) {
            console.log('User 2: +916205857707');
            console.log(`   _id: ${user2._id}`);
            console.log(`   blockedUsers: [${user2.blockedUsers?.join(', ') || 'none'}]`);
            console.log(`   blockedByUsers: [${user2.blockedByUsers?.join(', ') || 'none'}]\n`);
        }

        // Step 5: Optionally unblock them from each other
        console.log('❓ Do you want to unblock these two users from each other?');
        console.log('   If yes, uncomment the code below and run again.\n');

        /*
        if (user1 && user2) {
            console.log('🔓 Unblocking users from each other...');
            
            await User.updateOne(
                { _id: user1._id },
                { $pull: { blockedUsers: user2._id.toString() } }
            );
            
            await User.updateOne(
                { _id: user2._id },
                { $pull: { blockedByUsers: user1._id.toString() } }
            );
            
            console.log('   ✅ Users unblocked!\n');
        }
        */

        console.log('✅ Cleanup complete!');
        console.log('\n📝 Next steps:');
        console.log('   1. Restart your backend server');
        console.log('   2. Restart your Flutter app');
        console.log('   3. Pull to refresh in New Chat screen');
        console.log('   4. Users should now appear in contact list\n');

    } catch (error) {
        console.error('❌ Error:', error);
    } finally {
        await mongoose.disconnect();
        console.log('👋 Disconnected from MongoDB');
    }
}

cleanupDatabase();
